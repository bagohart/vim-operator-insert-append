" The structure is copy & paste from OperatorInsert, but some crucial details are different.
" It should be possible to extract the similarities to an abstract operator, but it's Vimscript and this probably wouldn't be fun.
" It's also unnecessary since this won't ever be used for anything else.

" Operator Append first invocation {{{
" In principal, this should be a script-local variable. But then, it is not passed to the functions called by the Autocommands.
" I don't know why this happens; according to :h autocmd.txt, this should in principle be possible.
" Maybe this is a problem with mixing public functions (the operator) with script local functions?
let g:OperatorAppend_invoked_from_operator = 0

function! operator_append#SetupOperatorFirstInvocation() abort
    let s:count = v:count1
    set operatorfunc=operator_append#OperatorFirstInvocation
endfunction

function! operator_append#OperatorFirstInvocation(type) abort
    " echom "Called operator_append#OperatorFirstInvocation() with type=" . a:type . " and count=" . s:count
    let s:inserted_char_in_insert_mode = 0
    if a:type ==# 'char' || ( a:type ==# 'line' && !g:OperatorInsertAppend_linewise_motions_select_whole_lines )
        " We check if the mark is the end of the line. You would expect that there is a simple function for this check
        " but apparently there is not. Comparing col("$") == col("']") fails with multi byte characters >_>
        let mark_pos = getpos("']")
        normal! `]$
        let end_of_line_pos = getpos(".")
        if mark_pos[2] ==# end_of_line_pos[2]
            startinsert!
        else
            normal! `]l
            startinsert
        endif
        if exists('*repeat#set')
            call s:CreateAutocommands()
            call repeat#set("\<Plug>(OperatorAppend-first-repeat)")
        endif
    elseif a:type ==# 'line' && g:OperatorInsertAppend_linewise_motions_select_whole_lines
        normal `]$m]
        startinsert!
        if exists('*repeat#set')
            call s:CreateAutocommands()
            call repeat#set("\<Plug>(OperatorAppend-first-repeat)")
        endif
    else
        throw "Called OperatorAppend from mode " . a:type . ". This should never happen!"
    endif

    " :startinsert is activated only after this function exits!
    let g:OperatorAppend_invoked_from_operator = 1
    " echom "Exit OperatorFirstInvocation. g:OperatorAppend_invoked_from_operator is now " . g:OperatorAppend_invoked_from_operator
endfunction
" }}}

function! s:SaveCountBeforeRepeat() abort " {{{
    if g:OperatorAppend_reuse_count_on_repeat
        let s:count = v:count > 0 ? v:count : s:count
    else
        let s:count = v:count1
    endif
endfunction " }}}

" Operator Append first repeat {{{
function! operator_append#SetupOperatorFirstRepeat() abort
    call s:SaveCountBeforeRepeat()
    set operatorfunc=operator_append#OperatorFirstRepeat
endfunction

function! operator_append#OperatorFirstRepeat(type) abort
    " echom "Called operator_append#OperatorFirstRepeat() with type=" . a:type . " and count=" . s:count
    if !s:inserted_char_in_insert_mode
        " echom "Nothing inserted the first time => nothing can be repeated. Abort."
        normal! `]
        return
    endif
    if a:type ==# 'char' || ( a:type ==# 'line' && !g:OperatorInsertAppend_linewise_motions_select_whole_lines )
        call s:AppendRepeatAtPos(getpos("']"))
        call repeat#set("\<Plug>(OperatorAppend-subsequent-repeat)")
    elseif a:type ==# 'line' && g:OperatorInsertAppend_linewise_motions_select_whole_lines
        normal! `]$m]
        call s:AppendRepeatAtPos(getpos("']"))
        call repeat#set("\<Plug>(OperatorAppend-subsequent-repeat)")
    else
        throw "Called OperatorAppend (first repeat) from mode " . a:type . ". This should never happen!"
    endif
endfunction

" Note that this function uses the s:count, which is set even if the first invocation of OperatorAppend was interrupted with ^C
" This could be circumvented by introducing more unintelligible autocommand hacks, but I'm not even convinced that this would be the desired behaviour.
function! s:AppendRepeatAtPos(pos)
    " echom "Called s:AppendRepeatAtPos() with @.=" 
    " echom @.
    let selection_end_pos = getpos("']")
    normal! `]
    execute "normal! a\<C-a>\<Esc>"
    for i in range(s:count - 1)
        execute "normal! gi\<C-a>\<Esc>"
    endfor
    call setpos(".", selection_end_pos)
    " Not sure if this might end up at the wrong position in some obscure edge cases such as no text or inserts with backspaces.
    " It's probably better for my sanity if I don't care.
    normal! lm[
endfunction
" }}}

" Operator Append second and subsequent repeats {{{
function! operator_append#OperatorSubsequentRepeat() abort
    call s:SaveCountBeforeRepeat()
    normal! .
endfunction
" }}}

" Autocommand hack {{{

" All of this section is a ridiculous hack that deserves some explanation.
" We cannot prepend a count to :startinsert, so we need to simulate it afterwards.
" Since startinsert is only started after the invocating function exits, this can only happen via an autocommand on InsertLeave.
" Unfortunately, InsertLeave can be circumvented by the user pressing ^C. In this case, the repetition would jumble the user's next insertion.
" To avoid this, we add another Autocommand on InsertEnter to make sure that the respective insert mode was activated from an invocation of Operator Append.

function! s:CreateAutocommands()
    " echom "Called s:CreateAutocommands()!"
    augroup OperatorAppend_enter_insert_mode
        autocmd!
        autocmd! InsertEnter * :call AutocmdInsertEnter()
    augroup END
    augroup OperatorAppend_leave_insert_mode
        autocmd!
        autocmd InsertLeave * :call s:AutocmdInsertLeave()
    augroup END
    augroup OperatorInsert_insert_char_pre
        autocmd!
        autocmd InsertCharPre * :call s:AutocmdInsertCharPre()
    augroup END
endfunction

function! AutocmdInsertEnter() abort
    " echom "Called AutocmdInsertEnter()!"
    " echom "ifo=" . g:OperatorAppend_invoked_from_operator
    if g:OperatorAppend_invoked_from_operator
        " echom "Was invoked from operator. Continue..."
        let g:OperatorAppend_invoked_from_operator = 0
        let g:activate_autocmd_insert_leave = 1
        " We must not remove either autocommand here. This clause guards against repeated invocation after ^C
    else
        " echom "Was not invoked from operator. Probably re-entered insert mode after pressing ^C in previous insert mode. " .
                    \ "Remove Autocommands and abort..."
        let g:activate_autocmd_insert_leave = 0
        " The Autocommands would be removed anyway in s:AutocmdInsertLeave()
        " but we can just do this now
        call s:RemoveAutocommands()
    endif
endfunction

function! s:AutocmdInsertLeave() abort
    " echom "Called s:AutocmdInsertLeave! aail=" . g:activate_autocmd_insert_leave . " and s:inserted_char_in_insert_mode=" . s:inserted_char_in_insert_mode
    call s:RemoveAutocommands()
    if !g:activate_autocmd_insert_leave
        " echom "Autocommand activated from ^C. Abort..."
        return
    elseif s:inserted_char_in_insert_mode ==# 0
        " echom "InsertCharPre was not fired during current insert mode! Abort to circumvent weird bug (or is it a feature? ...)!"
        return
    else
        " echom "Insert the things on InsertLeave!"
        " distinguish normal mode from insert normal mode!
        let mode = mode(1)
        if mode ==# 'n'
            " echom "Repeat the things in mode " . mode . " with count " . s:count
            let change_start_pos = getpos("'[")
            " this is the repeat on the first invocation, so we can use gi
            for i in range(s:count - 1)
                execute "normal! gi\<C-a>\<Esc>"
            endfor
            call setpos("'[", change_start_pos)
        else
            " echom "Cancel repeat in mode " . mode
            " insert normal mode cancels the count, this is normal Vim behaviour. So we imitate that behaviour here.
            let s:count = 1
        endif
    endif
endfunction

function! s:AutocmdInsertCharPre()
    let s:inserted_char_in_insert_mode = 1
    " We only need the information that anything was inserted during the current insert mode.
    " Therefore, this function is idempotent and the autocommand can (and should) be removed now.
    " It will be added back on the next invocation of OperatorInsert
    call s:RemoveAutocmdInsertCharPre()
endfunction

function! s:RemoveAutocmdInsertCharPre()
    augroup OperatorAppend_insert_char_pre
        autocmd!
    augroup END
endfunction

function! s:RemoveAutocommands()
    " echom "Called s:RemoveAutocommands()!"
    augroup OperatorAppend_leave_insert_mode
        autocmd!
    augroup END
    augroup OperatorAppend_enter_insert_mode
        autocmd!
    augroup END
    augroup OperatorAppend_insert_char_pre
        autocmd!
    augroup END
endfunction
" }}}

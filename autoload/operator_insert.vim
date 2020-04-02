
" Operator Insert first invocation {{{
" In principal, this should be a script-local variable. But then, it is not passed to the functions called by the Autocommands.
" I don't know why this happens; according to :h autocmd.txt, this should in principle be possible.
let g:OperatorInsert_invoked_from_operator = 0

function! operator_insert#SetupOperatorFirstInvocation() abort
    let s:count = v:count1
    set operatorfunc=operator_insert#OperatorFirstInvocation
endfunction

function! operator_insert#OperatorFirstInvocation(type) abort
    " echom "Called operator_insert#OperatorFirstInvocation() with type=" . a:type . " and count=" . s:count
    if a:type ==# 'char' || ( a:type ==# 'line' && !g:OperatorInsertAppend_linewise_motions_select_whole_lines )
        call setpos(".", getpos("'["))
        startinsert " This is only started after this function!
        call s:CreateAutocommands()
        call repeat#set("\<Plug>(OperatorInsert-first-repeat)")
    elseif a:type ==# 'line' && g:OperatorInsertAppend_linewise_motions_select_whole_lines
        call setpos(".", getpos("'["))
        normal! 0
        startinsert " This is only started after this function!
        call s:CreateAutocommands()
        call repeat#set("\<Plug>(OperatorInsert-first-repeat)")
    else
        throw "Called OperatorInsert from mode " . a:type . ". This should never happen!"
    endif

    " :startinsert is activated only after this function exits!
    let g:OperatorInsert_invoked_from_operator = 1
    let s:inserted_char_in_insert_mode = 0
    " echom "Exit OperatorFirstInvocation. g:OperatorInsert_invoked_from_operator is now " . g:OperatorInsert_invoked_from_operator
endfunction
" }}}

function! s:SaveCountBeforeRepeat() abort " {{{
    if g:OperatorInsert_reuse_count_on_repeat
        let s:count = v:count > 0 ? v:count : s:count
    else
        let s:count = v:count1
    endif
endfunction " }}}

" Operator Insert first repeat {{{
function! operator_insert#SetupOperatorFirstRepeat() abort
    call s:SaveCountBeforeRepeat()
    set operatorfunc=operator_insert#OperatorFirstRepeat
endfunction

function! operator_insert#OperatorFirstRepeat(type) abort
    " echom "Called operator_insert#OperatorFirstRepeat() with type=" . a:type . " and count=" . s:count
    if !s:inserted_char_in_insert_mode
        " echom "Nothing inserted the first time => nothing can be repeated. Abort."
        return
    endif
    if a:type ==# 'char' || ( a:type ==# 'line' && !g:OperatorInsertAppend_linewise_motions_select_whole_lines )
        call s:InsertRepeatAtPos(getpos("'["))
        call repeat#set("\<Plug>(OperatorInsert-subsequent-repeat)")
    elseif a:type ==# 'line' && g:OperatorInsertAppend_linewise_motions_select_whole_lines
        normal! `[0m[
        call s:InsertRepeatAtPos(getpos("'["))
        call repeat#set("\<Plug>(OperatorInsert-subsequent-repeat)")
    else
        throw "Called OperatorInsert (first repeat) from mode " . a:type . ". This should never happen!"
    endif
endfunction

" Note that this function uses the s:count, which is set even if the first invocation of OperatorInsert was interrupted with ^C
" This could be circumvented by introducing more unintelligible autocommand hacks, but I'm not even convinced that this would be the desired behaviour.
function! s:InsertRepeatAtPos(pos)
    let change_start_pos = getpos("'[")
    " use i to determine the correct position for the first invocation.
    " After that, gi can savely be used
    " We cannot merge this into a single insert mode command, since this would change the count!
    normal! `[
    execute "normal! i\<C-a>\<Esc>"
    for i in range(s:count - 1)
        execute "normal! gi\<C-a>\<Esc>"
    endfor
    call setpos("'[", change_start_pos)
endfunction
" }}}

" Operator insert second and subsequent repeats {{{
function! operator_insert#OperatorSubsequentRepeat() abort
    call s:SaveCountBeforeRepeat()
    normal! .
endfunction
" }}}

" Autocommand hack {{{
" All of this section is a ridiculous hack that deserves some explanation.
" We cannot prepend a count to :startinsert, so we need to simulate it afterwards.
" Since startinsert is only started after the invocating function exits, this can only happen via an autocommand on InsertLeave.
" Unfortunately, InsertLeave can be circumvented by the user pressing ^C. In this case, the repetition would jumble the user's next insertion.
" To avoid this, we add another Autocommand on InsertEnter to make sure that the respective insert mode was activated from an invocation of Operator Insert.

function! s:CreateAutocommands()
    " echom "Called s:CreateAutocommands()!"
    augroup OperatorInsert_enter_insert_mode
        autocmd!
        autocmd! InsertEnter * :call s:AutocmdInsertEnter()
    augroup END
    augroup OperatorInsert_leave_insert_mode
        autocmd!
        autocmd InsertLeave * :call s:AutocmdInsertLeave()
    augroup END
    augroup OperatorInsert_insert_char_pre
        autocmd!
        autocmd InsertCharPre * :call s:AutocmdInsertCharPre()
    augroup END
endfunction

function! s:AutocmdInsertEnter() abort
    " echom "Called s:AutocmdInsertEnter()!"
    " echom "ifo=" . g:OperatorInsert_invoked_from_operator
    if g:OperatorInsert_invoked_from_operator
        " echom "Was invoked from operator. Continue..."
        let g:OperatorInsert_invoked_from_operator = 0
        let s:activate_autocmd_insert_leave = 1
        " We must not remove either autocommand here. This clause guards against repeated invocation after ^C
    else
        " echom "Was not invoked from operator. Probably re-entered insert mode after pressing ^C in previous insert mode. " .
                    \ "Remove Autocommands and abort..."
        let s:activate_autocmd_insert_leave = 0
        " The Autocommands would be removed anyway in s:AutocmdInsertLeave()
        " but we can just do this now
        call s:RemoveAllAutocommands()
    endif
endfunction

function! s:AutocmdInsertLeave() abort
    " echom "Called s:AutocmdInsertLeave! aail=" . s:activate_autocmd_insert_leave
    call s:RemoveAllAutocommands()
    if !s:activate_autocmd_insert_leave
        " echom "Autocommand activated from ^C. Abort..."
        return
    elseif s:inserted_char_in_insert_mode ==# 0
        " echom "InsertCharPre was not fired during current insert mode! Abort to circumvent weird bug (or is it a feature? ...)!"
        return
    else
        " distinguish normal mode from insert normal mode!
        let mode = mode(1)
        if mode ==# 'n'
            " todo: here is an absurd edge case bug: escape insert mode, not entering anything and it repeats the insertion before that!
            " (If the insertion was backspaces, then it even removes text!)
            " I truly don't know if this is a feature or a bug, since after InsertLeave, this is gone!
            " This would be the place to detect it, but there seems no way to get the 'real current last insertion'. wtf Vim. wtf.
            " The following printf debugging command shows that the register contains the same content as <C-a> inserts, so we can't use that!
            " echom "last inserted text=" . @.
            " In the case where nothing is entered, this can be mitigated by checking InsertCharPre, as is done above.
            " But I'm not sure if this covers all weird edge cases...
            " ^ No, it doesn't. InsertCharPre is *not* fired on Backspace, so repeating backspaces is not possible.
            " In contrast, pressing just 5i<BS><Esc> ∗is* repeated.
            " echom "Repeat the things in mode " . mode . " with count " . s:count
            let change_start_pos = getpos("'[")
            " We can rely on gi, since we're continuing where the last insert mode finished.
            " Note that we cannot merge all gi command in a single one; this would change the count!
            for i in range(s:count - 1)
                execute "normal! gi\<C-a>\<Esc>"
            endfor
            call setpos("'[", change_start_pos)
            " I had tried a different solution first with manually [p]utting things at the right position repeatedly,
            " but that had some unwanted side effects in some cases; restoring the `[`] marks and the cursor position
            " becomes difficult for newlines and tabs
        else
            " echom "Cancel repeat in mode " . mode
            " insert normal mode cancels the count, this is normal Vim behaviour. So we imitate that behaviour here.
            let s:count = 1
        endif
    endif
endfunction

function! s:AutocmdInsertCharPre()
    " echom "Called s:AutocmdInsertCharPre(). s:inserted_char_in_insert_mode=" . s:inserted_char_in_insert_mode
    let s:inserted_char_in_insert_mode = 1
    " We only need the information that anything was inserted during the current insert mode.
    " Therefore, this function is idempotent and the autocommand can (and should) be removed now.
    " It will be added back on the next invocation of OperatorInsert
    call s:RemoveAutocmdInsertCharPre()
endfunction

function! s:RemoveAutocmdInsertCharPre()
    augroup OperatorInsert_insert_char_pre
        autocmd!
    augroup END
endfunction

function! s:RemoveAllAutocommands()
    " echom "Called s:RemoveAllAutocommands()!"
    augroup OperatorInsert_leave_insert_mode
        autocmd!
    augroup END
    augroup OperatorInsert_enter_insert_mode
        autocmd!
    augroup END
    augroup OperatorInsert_insert_char_pre
        autocmd!
    augroup END
endfunction
" }}}

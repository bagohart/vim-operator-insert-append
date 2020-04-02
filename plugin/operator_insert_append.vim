" Reload guard {{{
if &compatible || exists("g:loaded_operator_insert_append")
    finish
endif
let g:loaded_operator_insert_append = 1
" }}}

" autoloading hack {{{
" call operator_insert#Baaad()
" call operator_append#Baaad()
" }}}

" Settings {{{
let g:OperatorInsert_reuse_count_on_repeat = get(g:, 'OperatorInsert_reuse_count_on_repeat', 0)
let g:OperatorAppend_reuse_count_on_repeat = get(g:, 'OperatorAppend_reuse_count_on_repeat', 0)
let g:OperatorInsertAppend_linewise_motions_select_whole_lines = get(g:, 'OperatorInsertAppend_linewise_motions_select_whole_lines', 1)
" }}}

" Plug mappings for Operator Insert {{{
nnoremap <silent> <Plug>(OperatorInsert-first-invocation) :<C-u>call operator_insert#SetupOperatorFirstInvocation()<CR>g@
nnoremap <silent> <Plug>(OperatorInsert-first-repeat) :<C-u>call operator_insert#SetupOperatorFirstRepeat()<CR>g@
nnoremap <silent> <Plug>(OperatorInsert-subsequent-repeat) :<C-u>call operator_insert#OperatorSubsequentRepeat()<CR>
" }}}

" Plug mappings for Operator Append {{{
nnoremap <silent> <Plug>(OperatorAppend-first-invocation) :<C-u>call operator_append#SetupOperatorFirstInvocation()<CR>g@
nnoremap <silent> <Plug>(OperatorAppend-first-repeat) :<C-u>call operator_append#SetupOperatorFirstRepeat()<CR>g@
nnoremap <silent> <Plug>(OperatorAppend-subsequent-repeat) :<C-u>call operator_append#OperatorSubsequentRepeat()<CR>
" }}}

" user mappings {{{
" nmap <M-i> <Plug>(OperatorInsert-first-invocation)
" nmap <M-a> <Plug>(OperatorAppend-first-invocation)
" }}}

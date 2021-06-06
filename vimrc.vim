" Highlighting literate directives in C++ sources.
function! HighlightTangledFile()
  " Tangled comments only make sense in the sources and are stripped out of
  " the generated .cc file. They're highlighted same as regular comments.
  syntax match tangledComment /\/\/:.*/ | highlight link tangledComment Comment
  syntax match tangledSalientComment /\/\/::.*/ | highlight link tangledSalientComment SalientComment
  set comments-=://
  set comments-=n://
  set comments+=n://:,n://

  " Inside tangle scenarios.
  syntax region tangleDirective start=+:(+ skip=+".*"+ end=+)+
  highlight link tangleDirective Delimiter
  syntax match traceContains /^+.*/
  highlight traceContains ctermfg=22
  syntax match traceAbsent /^-.*/
  highlight traceAbsent ctermfg=darkred
  syntax match tangleScenarioSetup /^\s*% .*/ | highlight link tangleScenarioSetup SpecialChar
  highlight Special ctermfg=160

  syntax match subxString %"[^"]*"% | highlight link subxString Constant
  " match globals but not registers like 'EAX'
  syntax match subxGlobal %\<[A-Z][a-z0-9_-]*\>% | highlight link subxGlobal SpecialChar
endfunction
augroup LocalVimrc
  autocmd BufRead,BufNewFile *.cc call HighlightTangledFile()
  autocmd BufRead,BufNewFile *.subx set ft=subx
augroup END

" we often want to crib lines of machine code from other files
function! GrepSubX(regex)
  " https://github.com/mtth/scratch.vim
  Scratch!
  silent exec "r !grep -h '".a:regex."' *.subx */*.subx"
endfunction
command! -nargs=1 G call GrepSubX(<q-args>)

if exists("&splitvertical")
  command! -nargs=0 P hor split subx_opcodes
else
  command! -nargs=0 P split subx_opcodes
endif

" useful for inspecting just the control flow in a trace
" see https://github.com/akkartik/mu/blob/main/linux/subx_debugging.md
command! -nargs=0 L exec "%!grep label |grep -v clear-stream:loop"

" show the call stack for the current line in the trace (by temporarily blowing away all earlier lines)
"? command! -nargs=0 C 1,.!awk '$4 == "label"{x[$1] = $0; for(i in x){if(i >= $1){delete x[i]}}} END{for (i in x) {if (i < $1) {print x[i]}}}'
"? command! -nargs=0 C 1,.!awk '$4 == "label"{x[$1] = $0} END{for (i in x) {if (i < $1) {print x[i]}}}'
command! -nargs=0 C 1,.!awk '{x[$1] = $0} END{for (i in x) {if (int(i) < int($1)) {print x[i]}}}'

" run test around cursor
if empty($TMUX) || (system("tmux display-message -p '#{client_control_mode}'") =~ "^1")
  " hack: need to move cursor outside function at start (`{`), but inside function at end (`<C-o>`)
  " this solution is unfortunate, but seems forced:
  "   can't put initial cursor movement inside function because we rely on <C-r><C-w> to grab word at cursor
  "   can't put final cursor movement out of function because that disables the wait for <CR> prompt; function must be final operation of map
  "   can't avoid the function because that disables the wait for <CR> prompt
  noremap <Leader>t {:keeppatterns /^[^ #]<CR>:call RunTestMoveCursor("<C-r><C-w>")<CR>
  function! RunTestMoveCursor(arg)
    exec "!./run_one_test ".expand("%")." '".a:arg."'"
    exec "normal \<C-o>"
  endfunction
else
  " we have tmux and are not in control mode; we don't need to show any output in the Vim pane so life is simpler
  " assume the left-most window is for the shell
  noremap <Leader>t {:keeppatterns /^[^ #]<CR>:silent! call RunTestInFirstPane("<C-r><C-w>")<CR><C-o>
  function! RunTestInFirstPane(arg)
    call RunInFirstPane("./run_one_test ".expand("%")." ".a:arg)
  endfunction
  function! RunInFirstPane(arg)
    exec "!tmux select-pane -t :0.0"
    exec "!tmux send-keys '".a:arg."' C-m"
    exec "!tmux last-pane"
    " for some reason my screen gets messed up, so force a redraw
    exec "!tmux send-keys 'C-l'"
  endfunction
endif

if exists("&splitvertical")
  command! -nargs=0 T badd last_run | sbuffer last_run
else
  command! -nargs=0 T badd last_run | vert sbuffer last_run
endif

inoremap <Leader>a <Esc>F<Space>a(addr <Esc>A)
inoremap <Leader>h <Esc>F<Space>a(handle <Esc>A)
inoremap <Leader>ah <Esc>F<Space>a(addr handle <Esc>A)
inoremap <Leader>aa <Esc>F<Space>a(addr array <Esc>A)
inoremap <Leader>ha <Esc>F<Space>a(handle array <Esc>A)
inoremap <Leader>aha <Esc>F<Space>a(addr handle array <Esc>A)
inoremap <Leader>as <Esc>F<Space>a(addr stream <Esc>A)
inoremap <Leader>hs <Esc>F<Space>a(handle stream <Esc>A)
inoremap <Leader>ahs <Esc>F<Space>a(addr handle stream <Esc>A)
inoremap <Leader>o <Esc>F<Space>a(offset <Esc>A)
inoremap ,- <-
inoremap -. ->

autocmd BufReadPost,BufNewFile *.limg set filetype=mulisp |call matchadd('String', '\[\([^\]]*\_$\_s\)*[^\]]*\]')

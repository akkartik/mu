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

" Scenarios considered:
"   opening or starting vim with a new or existing file without an extension (should interpret as C++)
"   opening or starting vim with a new or existing file with a .mu extension
"   starting vim or opening a buffer without a file name (ok to do nothing)
"   opening a second file in a new or existing window (shouldn't mess up existing highlighting)
"   reloading an existing file (shouldn't mess up existing highlighting)

command! -nargs=1 E call EditSubx("edit", <f-args>)
if exists("&splitvertical")
  command! -nargs=1 S call EditSubx("vert split", <f-args>)
  command! -nargs=1 H call EditSubx("hor split", <f-args>)
else
  command! -nargs=1 S call EditSubx("vert split", <f-args>)
  command! -nargs=1 H call EditSubx("split", <f-args>)
endif

function! EditSubx(cmd, arg)
  exec "silent! " . a:cmd . " " . SubxPath(a:arg)
endfunction

function! SubxPath(arg)
  if a:arg =~ "^ex"
    return "examples/" . a:arg . ".subx"
  else
    return "apps/" . a:arg . ".subx"
  endif
endfunction

" we often want to crib lines of machine code from other files
function! GrepSubX(regex)
  " https://github.com/mtth/scratch.vim
  Scratch!
  silent exec "r !grep -h '".a:regex."' *.subx */*.subx"
endfunction
command! -nargs=1 G call GrepSubX(<q-args>)

if exists("&splitvertical")
  command! -nargs=0 P hor split opcodes
else
  command! -nargs=0 P split opcodes
endif

" useful for inspecting just the control flow in a trace
" see https://github.com/akkartik/mu/blob/master/Readme.md#a-few-hints-for-debugging
command! -nargs=0 L exec "%!grep label |grep -v clear-stream:loop"

" run test around cursor
if empty($TMUX)
  " hack: need to move cursor outside function at start (`{`), but inside function at end (`<C-o>`)
  " this solution is unfortunate, but seems forced:
  "   can't put initial cursor movement inside function because we rely on <C-r><C-w> to grab word at cursor
  "   can't put final cursor movement out of function because that disables the wait for <CR> prompt; function must be final operation of map
  "   can't avoid the function because that disables the wait for <CR> prompt
  noremap <Leader>t {:keeppatterns /^[^ #]<CR>:call RunTestMoveCursor("<C-r><C-w>")<CR>
  function RunTestMoveCursor(arg)
    exec "!./run_one_test ".expand("%")." '".a:arg."'"
    exec "normal \<C-o>"
  endfunction
else
  " we have tmux; we don't need to show any output in the Vim pane so life is simpler
  " assume the left-most window is for the shell
  noremap <Leader>t {:keeppatterns /^[^ #]<CR>:silent! call RunTestInFirstPane("<C-r><C-w>")<CR><C-o>
  function RunTestInFirstPane(arg)
    call RunInFirstPane("./run_one_test ".expand("%")." ".a:arg)
  endfunction
  function RunInFirstPane(arg)
    exec "!tmux select-pane -t :0.0"
    exec "!tmux send-keys '".a:arg."' C-m"
    exec "!tmux last-pane"
    " for some reason my screen gets messed up, so force a redraw
    exec "!tmux send-keys 'C-l'"
  endfunction
endif

set switchbuf=useopen
if exists("&splitvertical")
  command! -nargs=0 T badd last_run | sbuffer last_run
else
  command! -nargs=0 T badd last_run | vert sbuffer last_run
endif

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
  autocmd BufRead,BufNewFile *.mu set ft=mu
augroup END

" Scenarios considered:
"   opening or starting vim with a new or existing file without an extension (should interpret as C++)
"   opening or starting vim with a new or existing file with a .mu extension
"   starting vim or opening a buffer without a file name (ok to do nothing)
"   opening a second file in a new or existing window (shouldn't mess up existing highlighting)
"   reloading an existing file (shouldn't mess up existing highlighting)

" assumes CWD is subx/
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
" see https://github.com/akkartik/mu/blob/master/subx/Readme.md#a-few-hints-for-debugging
" the '-a' is because traces can sometimes contain unprintable characters that bother grep
command! -nargs=0 L exec "%!grep -a label |grep -v clear-stream:loop"

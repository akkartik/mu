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
  highlight traceContains ctermfg=darkgreen
  syntax match traceAbsent /^-.*/
  highlight traceAbsent ctermfg=darkred
  syntax match tangleScenarioSetup /^\s*% .*/ | highlight link tangleScenarioSetup SpecialChar

  " Our C++ files can have Mu code in scenarios, so highlight Mu comments like
  " regular comments.
  syntax match muComment /#.*$/
  highlight link muComment Comment
  syntax match muSalientComment /##.*$/ | highlight link muSalientComment SalientComment
  syntax match muCommentedCode /#? .*$/ | highlight link muCommentedCode CommentedCode
  set comments+=n:#
  " Some other bare-bones Mu highlighting.
  syntax match muLiteral %[^ ]\+:literal/[^ ,]*\|[^ ]\+:literal\>%
  syntax match muLiteral %[^ ]\+:label/[^ ,]*\|[^ ]\+:label\>%
  syntax match muLiteral %[^ ]\+:type/[^ ,]*\|[^ ]\+:type\>%
  syntax match muLiteral %[^ ]\+:offset/[^ ,]*\|[^ ]\+:offset\>%
  syntax match muLiteral %[^ ]\+:variant/[^ ,]*\|[^ ]\+:variant\>%
  syntax match muLiteral % true\(\/[^ ]*\)\?\| false\(\/[^ ]*\)\?%  " literals will never be the first word in an instruction
  syntax match muLiteral % null\(\/[^ ]*\)\?%
  highlight link muLiteral Constant
  syntax match muAssign " <- \|\<raw\>" | highlight link muAssign SpecialChar
  " common keywords
  syntax match muRecipe "^recipe\>\|^recipe!\>\|^def\>\|^def!\>\|^before\>\|^after\>\| -> " | highlight muRecipe ctermfg=208
  syntax match muScenario "^scenario\>" | highlight muScenario ctermfg=34
  syntax match muPendingScenario "^pending-scenario\>" | highlight link muPendingScenario SpecialChar
  syntax match muData "^type\>\|^container\>\|^exclusive-container\>" | highlight muData ctermfg=226

  syntax match subxString %"[^"]*"% | highlight link subxString Constant
  " match globals but not registers like 'EAX'
  syntax match subxGlobal %\<[A-Z][a-z0-9_-]*\>% | highlight link subxGlobal SpecialChar
endfunction
augroup LocalVimrc
  autocmd BufRead,BufNewFile *.mu set ft=mu
  autocmd BufRead,BufNewFile *.cc call HighlightTangledFile()
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

" temporary helpers while we port https://github.com/akkartik/crenshaw to apps/crenshaw*.subx
command! -nargs=1 C exec "E crenshaw".<f-args>
command! -nargs=1 CS exec "S crenshaw".<f-args>
command! -nargs=1 CH exec "H crenshaw".<f-args>
function! Orig()
  let l:p = expand("%:t:r")
  if l:p =~ "^crenshaw\\d*-\\d*$"
    exec "vert split crenshaw/tutor" . substitute(expand("%:t:r"), "^crenshaw\\(\\d*\\)-\\(\\d*\\)$", "\\1.\\2", "") . ".pas"
  endif
endfunction
command! O call Orig()

if exists("&splitvertical")
  command! -nargs=0 P hor split opcodes
else
  command! -nargs=0 P split opcodes
endif

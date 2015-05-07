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

  " Our C++ files can have mu code in scenarios, so highlight mu comments like
  " regular comments.
  syntax match muComment /# .*$/ | highlight link muComment Comment
  syntax match muSalientComment /##.*$/ | highlight link muSalientComment SalientComment
  syntax match muCommentedCode /#? .*$/ | highlight link muCommentedCode CommentedCode
  set comments+=n:#
  " Some other bare-bones mu highlighting.
  syntax match muAssign " <- " | highlight link muAssign SpecialChar
  syntax match muAssign "\<raw\>"
endfunction
call HighlightTangledFile()
autocmd BufRead,BufNewFile *.mu set ft=mu
autocmd BufRead,BufNewFile [0-9]* call HighlightTangledFile()

" Scenarios considered:
"   opening or starting vim with a new or existing file without an extension (should interpret as C++)
"   opening or starting vim with a new or existing file with a .mu extension
"   starting vim or opening a buffer without a file name (ok to do nothing)
"   opening a second file in a new or existing window (shouldn't mess up existing highlighting)
"   reloading an existing file (shouldn't mess up existing highlighting)

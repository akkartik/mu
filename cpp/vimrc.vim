" Highlighting literate directives in C++ sources.
function! HighlightTangledFile()
  if &ft == ""
    set ft=cpp
  endif
  set comments-=://
  set comments-=n://
  set comments+=n://:,n://

  set isk+=-

  syntax region tangleDirective start=+:(+ skip=+".*"+ end=+)+
  highlight link tangleDirective Delimiter
  syntax region traceContains start="^+" end="$"
  highlight traceContains ctermfg=darkgreen
  syntax region traceAbsent start="^-" end="$"
  highlight traceAbsent ctermfg=darkred
  " Our C++ files can have mu code in scenarios, so highlight mu comments like
  " regular comments.
  syntax match muComment /#.*$/ | highlight link muComment Comment
  syntax match muSalientComment /##.*$/ | highlight link muSalientComment SalientComment
  " Tangled comments only make sense in the sources and are stripped out of
  " the generated .cc file. They're highlighted same as regular comments.
  syntax match tangledComment /\/\/:.*/ | highlight link tangledComment Comment
  syntax match tangledSalientComment /\/\/::.*/ | highlight link tangledSalientComment SalientComment
endfunction
call HighlightTangledFile()
autocmd BufRead,BufNewFile *.mu set ft=mu
autocmd BufRead,BufNewFile 0* call HighlightTangledFile()

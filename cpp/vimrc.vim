" Highlighting literate directives in C++ sources.
function! HighlightTangledFile()
  set ft=cpp
  set comments-=://
  set comments-=n://
  set comments+=n://:,n://
  syntax region tangleDirective start=+:(+ skip=+".*"+ end=+)+
  highlight link tangleDirective Delimiter
  syntax region traceContains start="^+" end="$"
  highlight traceContains ctermfg=darkgreen
  syntax region traceAbsent start="^-" end="$"
  highlight traceAbsent ctermfg=darkred
endfunction
call HighlightTangledFile()
autocmd BufRead,BufNewFile 0* call HighlightTangledFile()

set isk+=-

" scenarios inside c++ files
syntax match muComment /#.*$/ | highlight link muComment Comment
syntax keyword muControl reply jump jump-if jump-unless loop loop-if loop-unless break-if break-unless | highlight link muControl Identifier
syntax match muAssign "<-" | highlight link muAssign SpecialChar
syntax match muAssign "\<raw\>"

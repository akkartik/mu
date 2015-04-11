" Highlighting literate directives in C++ sources.
function! HighlightTangledFile()
  if &ft == ""
    set ft=cpp
  endif
  syntax region tangleDirective start=+:(+ skip=+".*"+ end=+)+
  highlight link tangleDirective Delimiter
  syntax region traceContains start="^+" end="$"
  highlight traceContains ctermfg=darkgreen
  syntax region traceAbsent start="^-" end="$"
  highlight traceAbsent ctermfg=darkred
endfunction
call HighlightTangledFile()
autocmd BufReadPost,BufNewFile 0* call HighlightTangledFile()

set isk+=-

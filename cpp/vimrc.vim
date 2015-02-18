" Highlighting wart's literate directives in C++ sources.
function! HighlightTangledFile()
  if &ft == ""
    set ft=cpp
  endif
  syntax region wartTangle start=+:(+ skip=+".*"+ end=+)+
  highlight link wartTangle Delimiter
  syntax region wartTrace start="^+" end="$"
  highlight wartTrace ctermfg=darkgreen
  syntax region wartTraceAbsent start="^-" end="$"
  highlight wartTraceAbsent ctermfg=darkred
  syntax region wartTraceResult start="^=>" end="$"
  highlight wartTraceResult ctermfg=darkgreen cterm=bold
  syntax region wartComment start="# " end="$"
  highlight link wartComment Comment
endfunction
call HighlightTangledFile()
autocmd BufReadPost,BufNewFile 0* call HighlightTangledFile()

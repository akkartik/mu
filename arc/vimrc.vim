syntax sync minlines=999

function! HighlightMuInArc()
  set ft=mu
  syntax keyword muHack begin | highlight link muHack CommentedCode
  syntax match muHack "[()]" | highlight link muHack CommentedCode
endfunction
autocmd BufRead,BufNewFile *.mu call HighlightMuInArc()

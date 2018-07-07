" assumes CWD is subx/
command! -nargs=1 EE call EditSubx(<f-args>)

function! EditSubx(arg)
  " run commands silently because we may get an error loading EditSubx from a
  " different directory.
  if a:arg =~ "test.*"
    exec "silent! vert split teensy/" . a:arg . "*.[cs]"
  else
    exec "silent! vert split " . a:arg . "*.subx"
  endif
endfunction

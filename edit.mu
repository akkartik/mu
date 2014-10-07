(main
  (cls)
  (cursor (10 literal) (5 literal))
  (print ("Hello, " literal))
  (bold-mode)
  (print ("you" literal))
  (non-bold-mode)
  (print ("." literal))
  (cursor (1 literal) (1 literal))
  (print ("Press a key..." literal))
  ((key string) <- getc)
  (console-off)
  (print ("You pressed: " literal))
  (print (key string))
  (print ("\n" literal))
)

; a screen is an array of pointers to lines, in turn arrays of characters

(new-screen
  ((nrows integer) <- arg)
  ((ncols integer) <- arg)
  ((result screen-address) <- new (screen type) (nrows integer))
  ((result integer-address deref) <- copy (nrows integer))
  ((rowidx integer) <- literal 0)
  ((foo integer) <- literal 1000)
  ((curr-dest line-address-address) <- index (foo screen-address deref) (rowidx integer))
;?   ((curr-dest line-address-address) <- index-address (result screen-address) (rowidx integer))
;?   ((curr-dest line-address deref)
)

;? (redraw
;?   (
;? ) 

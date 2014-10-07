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
  ((rowidx integer) <- copy (0 literal))
  { begin
    ((curr-line-address-address line-address-address) <- index-address (result screen-address deref) (rowidx integer))
    ((curr-line-address-address line-address-address deref) <- new (line type) (ncols integer))
    ((curr-line-address line-address) <- copy (curr-line-address-address line-address-address deref))
    ((curr-line-address integer-address deref) <- copy (ncols integer))
    ((rowidx integer) <- add (rowidx integer) (1 literal))
    ((x boolean) <- neq (rowidx integer) (nrows integer))
    (continueif (x boolean))
  }
  (reply (result screen-address))
)

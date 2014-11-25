; a screen is an array of pointers to lines, in turn arrays of characters

(def new-screen [
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((nrows integer) <- arg)
  ((ncols integer) <- arg)
  ((result screen-address) <- new (screen literal) (nrows integer))
  ((rowidx integer) <- copy (0 literal))
  { begin
    ((curr-line-address-address line-address-address) <- index-address (result screen-address deref) (rowidx integer))
    ((curr-line-address-address line-address-address deref) <- new (line literal) (ncols integer))
    ((curr-line-address line-address) <- copy (curr-line-address-address line-address-address deref))
    ((rowidx integer) <- add (rowidx integer) (1 literal))
    ((x boolean) <- neq (rowidx integer) (nrows integer))
    (continue-if (x boolean))
  }
  (reply (result screen-address))
])

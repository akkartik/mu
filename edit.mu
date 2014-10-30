; a screen is an array of pointers to lines, in turn arrays of characters

(new-screen
  ((601 integer) <- arg)
  ((602 integer) <- arg)
  ((603 screen-address) <- new (screen type) (601 integer))
  ((604 integer) <- copy (0 literal))
  { begin
    ((606 line-address-address) <- index-address (603 screen-address deref) (604 integer))
    ((606 line-address-address deref) <- new (line type) (602 integer))
    ((605 line-address) <- copy (606 line-address-address deref))
    ((604 integer) <- add (604 integer) (1 literal))
    ((607 boolean) <- neq (604 integer) (601 integer))
    (continue-if (607 boolean))
  }
  (reply (603 screen-address))
)

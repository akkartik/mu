fn abs n: int -> _/eax: int {
  compare n, 0
  {
    break-if->=
    negate n
  }
  return n
}

fn sgn n: int -> _/eax: int {
  compare n, 0
  {
    break-if-<=
    return 1
  }
  {
    break-if->=
    return -1
  }
  return 0
}

fn shift-left-by n: int, bits: int -> _/eax: int {
  var i/eax: int <- copy bits
  {
    compare i, 0
    break-if-<=
    shift-left n, 1
    i <- decrement
    loop
  }
  return n
}

fn shift-right-by n: int, bits: int -> _/eax: int {
  var i/eax: int <- copy bits
  {
    compare i, 0
    break-if-<=
    shift-right n, 1
    i <- decrement
    loop
  }
  return n
}

fn clear-lowest-bits _n: (addr int), bits: int {
  var dest/edi: (addr int) <- copy _n
  var n/eax: int <- copy *dest
  n <- shift-right-by n, bits
  n <- shift-left-by n, bits
  copy-to *dest, n
}

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

fn f -> _/eax: int {
  return 2
}

fn g -> _/eax: int {
  return 3
}

fn add-f-and-g -> _/eax: int {
  var x/eax: int <- f
  var y/eax: int <- g
  x <- add y
  return x
}

fn test-add-f-and-g {
  var result/eax: int <- add-f-and-g
  check-ints-equal result, 5, "F - test-add-f-and-g\n"
}

fn main {
}

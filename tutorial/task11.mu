fn difference a: int, b: int -> _/eax: int {
}

fn test-difference {
  var result/eax: int <- difference 5, 3
  check-ints-equal result, 2, "F - difference works"
  result <- difference 3, 5
  check-ints-equal result, 2, "F - difference is always positive"
  result <- difference 6, 6
  check-ints-equal result, 0, "F - difference can be 0"
}

fn main screen: (addr screen) {
}

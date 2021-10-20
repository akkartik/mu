fn foo -> _/eax: int {
  var x: int
  # statement 1: store 3 in x
  # statement 2: define a new variable 'y' in register eax and store 4 in it
  # statement 3: add y to x, storing the result in x
  return x
}

fn test-foo {
  var result/eax: int <- foo
  check-ints-equal result, 7, "F - foo should return 7, but didn't"
}

fn main {
}

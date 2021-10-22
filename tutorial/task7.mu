fn foo -> _/eax: int {
  var x/edx: int <- copy 0
  # statement 1: store 3 in x
  copy-to x, 3
  # statement 2: define a new variable 'y' in register eax and store 4 in it
  var y/eax: int <- copy 4
  # statement 3: add y to x, storing the result in x
  add-to x, y
  return x
}

fn test-foo {
  var result/eax: int <- foo
  check-ints-equal result, 7, "F - foo should return 7, but didn't"
}

fn main {
}

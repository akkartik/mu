# Some helpers for Mu tests.

fn check-true val: boolean, msg: (addr array byte) {
  var tmp/eax: int <- copy val
  check-ints-equal tmp, 1, msg
}

fn check-false val: boolean, msg: (addr array byte) {
  var tmp/eax: int <- copy val
  check-ints-equal tmp, 0, msg
}

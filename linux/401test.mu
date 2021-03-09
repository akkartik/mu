# Some helpers for Mu tests.

fn check val: boolean, msg: (addr array byte) {
  var tmp/eax: int <- copy val
  check-ints-equal tmp, 1, msg
}

fn check-not val: boolean, msg: (addr array byte) {
  var tmp/eax: int <- copy val
  check-ints-equal tmp, 0, msg
}

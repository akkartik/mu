# print msg to screen if a != b, otherwise print "."
fn check-ints-equal _a: int, b: int, msg: (addr array byte) {
  var a/eax: int <- copy _a
  compare a, b
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, msg, 3  # 3=cyan
    count-test-failure
  }
  {
    break-if-!=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ".", 3  # 3=cyan
  }
}

fn test-check-ints-equal {
  check-ints-equal 0, 0, "abc"
}

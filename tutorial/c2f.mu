fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var result/eax: int <- do-add 3, 4
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, result, 3/fg=cyan 0/bg
}

fn do-add a: int, b: int -> _/eax: int {
  var result/eax: int <- copy a
  result <- add b
  return result
}

fn test-do-add {
  var observed/eax: int <- do-add 0, 0
  check-ints-equal observed, 0, "F - 0+0"
  observed <- do-add 3, 0
  check-ints-equal observed, 3, "F - 3+0"
  observed <- do-add 3, 2
  check-ints-equal observed, 5, "F - 3+2"
}

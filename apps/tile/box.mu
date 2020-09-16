fn draw-box screen: (addr screen), row1: int, col1: int, row2: int, col2: int {
  draw-horizontal-line screen, row1, col1, col2
  draw-vertical-line screen, row1, row2, col1
  draw-horizontal-line screen, row2, col1, col2
  draw-vertical-line screen, row1, row2, col2
}

fn draw-hatching screen: (addr screen), row1: int, col1: int, row2: int, col2: int {
  var c/eax: int <- copy col1
  var r1/ecx: int <- copy row1
  r1 <- increment
  c <- add 2
  {
    compare c, col2
    break-if->=
    draw-vertical-line screen, r1, row2, c
    c <- add 2
    loop
  }
}

fn draw-horizontal-line screen: (addr screen), row: int, col1: int, col2: int {
  var col/eax: int <- copy col1
  move-cursor 0, row, col
  {
    compare col, col2
    break-if->=
    print-code-point screen, 0x2500
    col <- increment
    loop
  }
}

fn draw-vertical-line screen: (addr screen), row1: int, row2: int, col: int {
  var row/eax: int <- copy row1
  {
    compare row, row2
    break-if->=
    move-cursor 0, row, col
    print-code-point screen, 0x2502
    row <- increment
    loop
  }
}

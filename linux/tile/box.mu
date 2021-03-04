fn draw-box screen: (addr screen), row1: int, col1: int, row2: int, col2: int {
  draw-horizontal-line screen, row1, col1, col2
  draw-vertical-line screen, row1, row2, col1
  draw-horizontal-line screen, row2, col1, col2
  draw-vertical-line screen, row1, row2, col2
  draw-top-left-corner screen, row1, col1
  draw-top-right-corner screen, row1, col2
  draw-bottom-left-corner screen, row2, col1
  draw-bottom-right-corner screen, row2, col2
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
  move-cursor screen, row, col
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
    move-cursor screen, row, col
    print-code-point screen, 0x2502
    row <- increment
    loop
  }
}

fn draw-top-left-corner screen: (addr screen), row: int, col: int {
  move-cursor screen, row, col
  print-code-point screen, 0x250c
}

fn draw-top-right-corner screen: (addr screen), row: int, col: int {
  move-cursor screen, row, col
  print-code-point screen, 0x2510
}

fn draw-bottom-left-corner screen: (addr screen), row: int, col: int {
  move-cursor screen, row, col
  print-code-point screen, 0x2514
}

fn draw-bottom-right-corner screen: (addr screen), row: int, col: int {
  move-cursor screen, row, col
  print-code-point screen, 0x2518
}

# erase parts of screen the slow way
fn clear-rect screen: (addr screen), row1: int, col1: int, row2: int, col2: int {
  var i/eax: int <- copy row1
  {
    compare i, row2
    break-if->
    var j/ecx: int <- copy col1
    move-cursor screen, i, j
    {
      compare j, col2
      break-if->
      print-grapheme screen 0x20/space
      j <- increment
      loop
    }
    i <- increment
    loop
  }
}

fn clear-rect2 screen: (addr screen), row1: int, col1: int, w: int, h: int {
  var i/eax: int <- copy 0
  var curr-row/esi: int <- copy row1
  {
    compare i, w
    break-if->=
    move-cursor screen, curr-row, col1
    var j/ecx: int <- copy 0
    {
      compare j, h
      break-if->=
      print-grapheme screen 0x20/space
      j <- increment
      loop
    }
    i <- increment
    curr-row <- increment
    loop
  }
}

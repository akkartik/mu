fn draw-box-on-real-screen x1: int, y1: int, x2: int, y2: int, color: int {
  draw-horizontal-line-on-real-screen x1, x2, y1, color
  draw-vertical-line-on-real-screen x1, y1, y2, color
  draw-horizontal-line-on-real-screen x1, x2, y2, color
  draw-vertical-line-on-real-screen x2, y1, y2, color
}

fn draw-horizontal-line-on-real-screen x1: int, x2: int, y: int, color: int {
  var x/eax: int <- copy x1
  {
    compare x, x2
    break-if->=
    pixel-on-real-screen x, y, color
    x <- increment
    loop
  }
}

fn draw-vertical-line-on-real-screen x: int, y1: int, y2: int, color: int {
  var y/eax: int <- copy y1
  {
    compare y, y2
    break-if->=
    pixel-on-real-screen x, y, color
    y <- increment
    loop
  }
}

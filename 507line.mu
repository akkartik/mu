fn draw-line screen: (addr screen), x0: int, y0: int, x1: int, y1: int, color: int {
  var dx: int
  var dy: int
  var sx: int
  var sy: int
  var err: int
  # dx = abs(x1-x0)
  var tmp2/ecx: int <- copy x1
  tmp2 <- subtract x0
  var tmp/eax: int <- abs tmp2
  copy-to dx, tmp
  # sx = sgn(x1-x0)
  tmp <- sgn tmp2
  copy-to sx, tmp
  # dy = -abs(y1-y0)
  tmp2 <- copy y1
  tmp2 <- subtract y0
  tmp <- abs tmp2
  tmp <- negate
  copy-to dy, tmp
  # sy = sgn(y1-y0)
  tmp <- sgn tmp2
  copy-to sy, tmp
  # err = dx + dy
  tmp <- copy dy
  tmp <- add dx
  copy-to err, tmp
  #
  var x/ecx: int <- copy x0
  var y/edx: int <- copy y0
  $draw-line:loop: {
    pixel screen, x, y, color
    # if (x == x1 && y == y1) break
    {
      compare x, x1
      break-if-!=
      compare y, y1
      break-if-!=
      break $draw-line:loop
    }
    # e2 = err*2
    var e2/ebx: int <- copy err
    e2 <- shift-left 1
    # if (e2 >= dy) { err += dy; x += sx; }
    {
      compare e2, dy
      break-if-<
      tmp <- copy dy
      add-to err, tmp
      x <- add sx
    }
    # if (e2 <= dx) { err += dx; y += sy; }
    {
      compare e2, dx
      break-if->
      tmp <- copy dx
      add-to err, tmp
      y <- add sy
    }
    loop
  }
}

fn draw-horizontal-line screen: (addr screen), y: int, x0: int, x1: int, color: int {
  var x/eax: int <- copy x0
  {
    compare x, x1
    break-if->=
    pixel screen, x, y, color
    x <- increment
    loop
  }
}

fn draw-vertical-line screen: (addr screen), x: int, y0: int, y1: int, color: int {
  var y/eax: int <- copy y0
  {
    compare y, y1
    break-if->=
    pixel screen, x, y, color
    y <- increment
    loop
  }
}

fn draw-rect screen: (addr screen), xmin: int, ymin: int, xmax: int, ymax: int, color: int {
  var y/eax: int <- copy ymin
  {
    compare y, ymax
    break-if->=
    draw-horizontal-line screen, y, xmin, xmax, color
    y <- increment
    loop
  }
}

fn draw-rect2 screen: (addr screen), xmin: int, ymin: int, w: int, h: int, color: int {
  var xmax/eax: int <- copy xmin
  xmax <- add w
  var ymax/ecx: int <- copy ymin
  ymax <- add h
  draw-rect screen, xmin ymin, xmax ymax, color
}

# 0 <= u <= 1
fn line-point u: float, x0: int, x1: int -> _/eax: int {
  var one/eax: int <- copy 1
  var u-prime/xmm0: float <- convert one
  u-prime <- subtract u
  var result/xmm1: float <- convert x0
  result <- multiply u-prime
  var term2/xmm2: float <- convert x1
  term2 <- multiply u
  result <- add term2
  var result/eax: int <- convert result
  return result
}

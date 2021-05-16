fn draw-circle screen: (addr screen), cx: int, cy: int, radius: int, color: int {
  var x: int
  var y: int
  var err: int
  # x = -r
  var tmp/eax: int <- copy radius
  tmp <- negate
  copy-to x, tmp
  # err = 2 - 2*r
  tmp <- copy radius
  tmp <- shift-left 1
  tmp <- negate
  tmp <- add 2
  copy-to err, tmp
  #
  var tmpx/ecx: int <- copy 0
  var tmpy/edx: int <- copy 0
  {
    # pixel(cx-x, cy+y)
    tmpx <- copy cx
    tmpx <- subtract x
    tmpy <- copy cy
    tmpy <- add y
    pixel screen, tmpx, tmpy, color
    # pixel(cx-y, cy-x)
    tmpx <- copy cx
    tmpx <- subtract y
    tmpy <- copy cy
    tmpy <- subtract x
    pixel screen, tmpx, tmpy, color
    # pixel(cx+x, cy-y)
    tmpx <- copy cx
    tmpx <- add x
    tmpy <- copy cy
    tmpy <- subtract y
    pixel screen, tmpx, tmpy, color
    # pixel(cx+y, cy+x)
    tmpx <- copy cx
    tmpx <- add y
    tmpy <- copy cy
    tmpy <- add x
    pixel screen, tmpx, tmpy, color
    # r = err
    tmp <- copy err
    copy-to radius, tmp
    # if (r <= y) { ++y; err += (y*2 + 1); }
    {
      tmpy <- copy y
      compare radius, tmpy
      break-if->
      increment y
      tmpy <- copy y
      tmpy <- shift-left 1
      tmpy <- increment
      add-to err, tmpy
    }
    # if (r > x || err > y) { ++x; err += (x*2 + 1); }
    $draw-circle:second-check: {
      {
        tmpx <- copy x
        compare radius, tmpx
        break-if->
        tmpy <- copy y
        compare err, tmpy
        break-if->
        break $draw-circle:second-check
      }
      increment x
      tmpx <- copy x
      tmpx <- shift-left 1
      tmpx <- increment
      add-to err, tmpx
    }
    # loop termination condition
    compare x, 0
    loop-if-<
  }
}

fn draw-disc screen: (addr screen), cx: int, cy: int, radius: int, color: int, border-color: int {
  var r/eax: int <- copy 0
  {
    compare r, radius
    break-if->=
    draw-circle screen, cx cy, r, color
    r <- increment
    loop
  }
  draw-circle screen, cx cy, r, border-color
}

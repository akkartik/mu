# Draw a second-degree bezier curve using 3 control points.
#
# http://members.chello.at/easyfilter/bresenham.html says that this algorithm
# works only if "the gradient does not change sign". Either:
#   x0 >= x1 >= x2
# or:
#   x0 <= x1 <= x2
# Similarly for y0, y1 and y2.
#
# This seems superficially similar to the notions of convex and concave, but I
# think it isn't. I think it's purely a property of the frame of reference.
# Rotating the axes can make the gradient change sign or stop changing sign
# even as 3 points preserve fixed relative bearings to each other.
fn draw-monotonic-bezier screen: (addr screen), x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: int {
  var xx: int
  var yy: int
  var xy: int
  var sx: int
  var sy: int
  # sx = x2-x1
  var tmp/eax: int <- copy x2
  tmp <- subtract x1
  copy-to sx, tmp
  # sy = y2-y1
  tmp <- copy y2
  tmp <- subtract y1
  copy-to sy, tmp
  # xx = x0-x1
  tmp <- copy x0
  tmp <- subtract x1
  copy-to xx, tmp
  # yy = y0-y1
  tmp <- copy y0
  tmp <- subtract y1
  copy-to yy, tmp
  # cur = xx*sy - yy*sx
  var cur-f/xmm4: float <- convert xx
  {
    var sy-f/xmm1: float <- convert sy
    cur-f <- multiply sy-f
    var tmp2-f/xmm1: float <- convert yy
    var sx-f/xmm2: float <- convert sx
    tmp2-f <- multiply sx-f
    cur-f <- subtract tmp2-f
  }
  set-cursor-position 0/screen, 0/x, 0x1d/y
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, sx, 4/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, sy, 4/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, xx, 4/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, yy, 4/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, xy, 4/fg 0/bg
  # if (xx*sx > 0) abort
  {
    tmp <- copy xx
    tmp <- multiply sx
    compare tmp, 0
    break-if-<=
    abort "bezier: gradient of x changes sign"
  }
  # if (yy*sy > 0) abort
  {
    tmp <- copy yy
    tmp <- multiply sy
    compare tmp, 0
    break-if-<=
    abort "bezier: gradient of y changes sign"
  }
  # swap P0 and P2 if necessary
  {
    # dist1 = sx*sx + sy*sy
    var dist1/ecx: int <- copy sx
    {
      dist1 <- multiply sx
      {
        break-if-not-overflow
        abort "bezier: overflow 1"
      }
      tmp <- copy sy
      tmp <- multiply sy
      {
        break-if-not-overflow
        abort "bezier: overflow 2"
      }
      dist1 <- add tmp
    }
    # dist2 = xx*xx + yy*yy
    var dist2/edx: int <- copy xx
    {
      dist2 <- multiply xx
      {
        break-if-not-overflow
        abort "bezier: overflow 3"
      }
      tmp <- copy yy
      tmp <- multiply yy
      {
        break-if-not-overflow
        abort "bezier: overflow 4"
      }
      dist2 <- add tmp
    }
    # if (dist1 <= dist2) break
    compare dist1, dist2
    break-if-<=
    set-cursor-position 0/screen, 0/x 0x1e/y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "swapping P0 and P2", 4/fg 0/bg
    # swap x0 and x2
    tmp <- copy x0
    copy-to x2, tmp
    tmp <- copy sx
    tmp <- add x1
    copy-to x0, tmp
    # swap y0 and y2
    tmp <- copy y0
    copy-to y2, tmp
    tmp <- copy sy
    tmp <- add y1
    copy-to y0, tmp
    # cur = -cur
    var negative-1/eax: int <- copy -1
    var negative-1-f/xmm1: float <- convert negative-1
    cur-f <- multiply negative-1-f
  }
  var x/ecx: int <- copy x0
  var y/edx: int <- copy y0
  set-cursor-position 0/screen, 0/x 0x1f/y
#?   printf("sx %d sy %d xx %ld yy %ld xy %ld cur %g\n", sx, sy, xx, yy, xy, cur);
  var zero-f: float
  # plot a curved part if necessary
  $draw-monotonic-bezier:curve: {
    compare cur-f, zero-f
    break-if-=
    # xx += sx
    tmp <- copy sx
    add-to xx, tmp
    # sx = sgn(x2-x)
    tmp <- copy x2
    tmp <- subtract x
    tmp <- sgn tmp
    copy-to sx, tmp
    # yy += sy
    tmp <- copy sy
    add-to yy, tmp
    # sy = sgn(y2-y)
    tmp <- copy y2
    tmp <- subtract y
    tmp <- sgn tmp
    copy-to sy, tmp
    # xy = 2*xx*xy
    tmp <- copy xx
    tmp <- multiply yy
    {
      break-if-not-overflow
      abort "bezier: overflow 5"
    }
    tmp <- shift-left 1
    {
      break-if-not-overflow
      abort "bezier: overflow 6"
    }
    copy-to xy, tmp
    # xx *= xx
    tmp <- copy xx
    tmp <- multiply tmp
    {
      break-if-not-overflow
      abort "bezier: overflow 7"
    }
    copy-to xx, tmp
    # yy *= yy
    tmp <- copy yy
    tmp <- multiply tmp
    {
      break-if-not-overflow
      abort "bezier: overflow 7"
    }
    copy-to yy, tmp
    # if (cur*sx*sy < 0) negative curvature
    {
      var tmp-f/xmm0: float <- copy cur-f
      var sx-f/xmm1: float <- convert sx
      tmp-f <- multiply sx-f
      var sy-f/xmm1: float <- convert sy
      tmp-f <- multiply sy-f
      compare tmp-f, zero-f
      break-if-float>=
      #
      negate xx
      negate yy
      negate xy
      # cur = -cur
      var negative-1/eax: int <- copy -1
      var negative-1-f/xmm1: float <- convert negative-1
      cur-f <- multiply negative-1-f
    }
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, sx, 4/fg 0/bg
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, sy, 4/fg 0/bg
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, xx, 4/fg 0/bg
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, yy, 4/fg 0/bg
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 4/fg 0/bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, xy, 4/fg 0/bg
    var four/ebx: int <- copy 4
    var dx-f/xmm5: float <- convert four
    var dy-f/xmm6: float <- convert four
    # dx = 4*sy*cur*(x1-x0) + xx - xy
    {
      var tmp/xmm0: float <- convert sy
      dx-f <- multiply tmp
      dx-f <- multiply cur-f
      tmp <- convert x1
      var tmp2/xmm3: float <- convert x
      tmp <- subtract tmp2
      dx-f <- multiply tmp
      tmp <- convert xx
      dx-f <- add tmp
      tmp <- convert xy
      dx-f <- subtract tmp
    }
    # dy-f = 4*sx*cur*(y0-y1) + yy - xy
    {
      var tmp/xmm0: float <- convert sx
      dy-f <- multiply tmp
      dy-f <- multiply cur-f
      tmp <- convert y
      var tmp2/xmm3: float <- convert y1
      tmp <- subtract tmp2
      dy-f <- multiply tmp
      tmp <- convert yy
      dy-f <- add tmp
      tmp <- convert xy
      dy-f <- subtract tmp
    }
    # xx += xx
    tmp <- copy xx
    add-to xx, tmp
    # yy += yy
    tmp <- copy yy
    add-to yy, tmp
    # err = dx+dy+xy
    var err-f/xmm7: float <- copy dx-f
    err-f <- add dy-f
    var xy-f/xmm0: float <- convert xy
    err-f <- add xy-f
    #
#?     set-cursor-position 0, 0/x 0/y
#?     var screen-y/esi: int <- copy 0
    $draw-monotonic-bezier:loop: {
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg 0/bg
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 3/fg 0/bg
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg 0/bg
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " vs ", 3/fg 0/bg
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x2, 3/fg 0/bg
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 3/fg 0/bg
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y2, 3/fg 0/bg
#?       var dummy/eax: int <- render-float-decimal 0/screen,  dx-f, 3/precision,    0/x screen-y, 3/fg 0/bg
#?       var dummy/eax: int <- render-float-decimal 0/screen,  dy-f, 3/precision, 0x10/x screen-y, 3/fg 0/bg
#?       var dummy/eax: int <- render-float-decimal 0/screen, err-f, 3/precision, 0x20/x screen-y, 3/fg 0/bg
#?       move-cursor-to-left-margin-of-next-line 0/screen
#?       screen-y <- increment
      pixel screen, x, y, color
#?       {
#?         var foo/eax: byte <- read-key 0/keyboard
#?         compare foo, 0
#?         loop-if-=
#?       }
      # if (x == x2 && y == y2) return
      {
        compare x, x2
        break-if-!=
        compare y, y2
        break-if-!=
        return
      }
      # perform-y-step? = (2*err < dx)
      var perform-y-step?/eax: boolean <- copy 0/false
      var two-err-f/xmm0: float <- copy err-f
      {
        var two/ebx: int <- copy 2
        var two-f/xmm1: float <- convert two
        two-err-f <- multiply two-f
        compare two-err-f, dx-f
        break-if-float>=
        perform-y-step? <- copy 1/true
      }
      # if (2*err > dy)
      {
        compare two-err-f, dy-f
        break-if-float<=
#?         draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "x step", 3/fg 0/bg
#?         move-cursor-to-left-margin-of-next-line 0/screen
        # x += sx
        x <- add sx
        # dx -= xy
        var xy-f/xmm0: float <- convert xy
        dx-f <- subtract xy-f
        # dy += yy
        var yy-f/xmm0: float <- convert yy
        dy-f <- add yy-f
        # err += dy
        err-f <- add dy-f
      }
      # if perform-y-step?
      {
        compare perform-y-step?, 0/false
        break-if-=
#?         draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "y step", 3/fg 0/bg
#?         move-cursor-to-left-margin-of-next-line 0/screen
        # y += sy
        y <- add sy
        # dy -= xy
        var xy-f/xmm0: float <- convert xy
        dy-f <- subtract xy-f
        # dx += xx
        var xx-f/xmm0: float <- convert xx
        dx-f <- add xx-f
        # err += dx
        err-f <- add dx-f
      }
      # if (dy < dx) loop
      compare dy-f, dx-f
      loop-if-float<
    }
  }
  # plot the remaining straight line
  draw-line screen, x y, x2 y2, color
}

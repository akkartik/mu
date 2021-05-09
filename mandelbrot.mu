# Mandelbrot set
#
# To build:
#   $ ./translate mandelbrot.mu
# To run:
#   $ qemu-system-i386 code.img

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  mandelbrot screen
}

fn mandelbrot screen: (addr screen) {
  var a/eax: int <- copy 0
  var b/ecx: int <- copy 0
  a, b <- screen-size screen
  var width/esi: int <- copy a
  width <- shift-left 3/log2-font-width
  var height/edi: int <- copy b
  height <- shift-left 4/log2-font-height
  var y/ecx: int <- copy 0
  {
    compare y, height
    break-if->=
    var imaginary/xmm1: float <- viewport-to-imaginary y, width, height
    var x/edx: int <- copy 0
    {
      compare x, width
      break-if->=
      var real/xmm0: float <- viewport-to-real x, width
      var iterations/eax: int <- mandelbrot-iterations-for-point real, imaginary, 0x400/max
      compare iterations, 0x400/max
      {
        break-if->=
        pixel screen, x, y, 0xf/white
      }
      compare iterations, 0x400/max
      {
        break-if-<
        pixel screen, x, y, 0/black
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn mandelbrot-iterations-for-point real: float, imaginary: float, max: int -> _/eax: int {
  var zero: float
  var x/xmm0: float <- copy zero
  var y/xmm1: float <- copy zero
  var iterations/ecx: int <- copy 0
  {
    var done?/eax: boolean <- mandelbrot-done? x, y
    compare done?, 0/false
    break-if-!=
    compare iterations, max
    break-if->=
    var newx/xmm2: float <- mandelbrot-x x, y, real
    var newy/xmm3: float <- mandelbrot-y x, y, imaginary
    x <- copy newx
    y <- copy newy
    iterations <- increment
    loop
  }
  return iterations
}

fn mandelbrot-done? x: float, y: float -> _/eax: boolean {
  # x*x + y*y > 4
  var x2/xmm0: float <- copy x
  x2 <- multiply x
  var y2/xmm1: float <- copy y
  y2 <- multiply y
  var sum/xmm0: float <- copy x2
  sum <- add y2
  var four/eax: int <- copy 4
  var four-f/xmm1: float <- convert four
  compare sum, four-f
  {
    break-if-float>
    return 0/false
  }
  return 1/true
}

fn mandelbrot-x x: float, y: float, real: float -> _/xmm2: float {
  # x*x - y*y + real
  var x2/xmm0: float <- copy x
  x2 <- multiply x
  var y2/xmm1: float <- copy y
  y2 <- multiply y
  var result/xmm0: float <- copy x2
  result <- subtract y2
  result <- add real
  return result
}

fn mandelbrot-y x: float, y: float, imaginary: float -> _/xmm3: float {
  # 2*x*y + imaginary
  var two/eax: int <- copy 2
  var result/xmm0: float <- convert two
  result <- multiply x
  result <- multiply y
  result <- add imaginary
  return result
}

fn viewport-to-real x: int, width: int -> _/xmm0: float {
  # (x - width/2)*4/width
  var result/xmm0: float <- convert x
  var width-f/xmm1: float <- convert width
  var two/eax: int <- copy 2
  var two-f/xmm2: float <- convert two
  var half-width-f/xmm2: float <- reciprocal two-f
  half-width-f <- multiply width-f
  result <- subtract half-width-f
  var four/eax: int <- copy 4
  var four-f/xmm2: float <- convert four
  result <- multiply four-f
  result <- divide width-f
  return result
}

fn viewport-to-imaginary y: int, width: int, height: int -> _/xmm1: float {
  # (y - height/2)*4/width
  var result/xmm0: float <- convert y
  var height-f/xmm1: float <- convert height
  var half-height-f/xmm1: float <- copy height-f
  var two/eax: int <- copy 2
  var two-f/xmm2: float <- convert two
  half-height-f <- divide two-f
  result <- subtract half-height-f
  var four/eax: int <- copy 4
  var four-f/xmm1: float <- convert four
  result <- multiply four-f
  var width-f/xmm1: float <- convert width
  result <- divide width-f
  return result
}

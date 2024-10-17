# Mandelbrot set
#
# Install:
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
# Build on Linux:
#   $ ./translate apps/mandelbrot.mu
# Build on other platforms (slow):
#   $ ./translate_emulated apps/mandelbrot.mu
# Run:
#   $ qemu-system-i386 code.img

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # Initially the viewport is centered at 0, 0 in the scene.
  var zero: float
  var scene-cx/xmm1: float <- copy zero
  var scene-cy/xmm2: float <- copy zero
  # Initially the viewport shows a section of the scene 4 units wide.
  # scene-width-scale = 0.5
  var scene-width-scale: float
  var dest/eax: (addr float) <- address scene-width-scale
  fill-in-rational dest, 1, 2
  # scene-width = 4
  var four: float
  var dest/eax: (addr float) <- address four
  fill-in-rational dest, 4, 1
  var scene-width/xmm3: float <- copy four
  {
    mandelbrot screen scene-cx, scene-cy, scene-width
    # move the center some % of the current screen-width
    var adj/xmm0: float <- rational 2, 0x1c/28
    adj <- multiply scene-width
    scene-cx <- subtract adj
    scene-cy <- add adj
    # slowly shrink the scene width to zoom in
    scene-width <- multiply scene-width-scale
    loop
  }
}

fn mandelbrot screen: (addr screen), scene-cx: float, scene-cy: float, scene-width: float {
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
    var imaginary/xmm1: float <- viewport-to-imaginary y, width, height, scene-cy, scene-width
    var x/ebx: int <- copy 0
    {
      compare x, width
      break-if->=
      var real/xmm0: float <- viewport-to-real x, width, scene-cx, scene-width
      var iterations/eax: int <- mandelbrot-iterations-for-point real, imaginary, 0x400/max
      iterations <- shift-right 3
      var color/edx: int <- copy 0
      iterations, color <- integer-divide iterations, 0x18/24/size-of-cycle-0
      color <- add 0x20/cycle-0
      pixel screen, x, y, color
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

# Scale (x, y) pixel coordinates to a complex plane where the viewport width
# ranges from (scene-cx - scene-width/2) to (scene-cx + scene-width/2).
# Viewport height just follows the viewport's aspect ratio.

fn viewport-to-real x: int, width: int, scene-cx: float, scene-width: float -> _/xmm0: float {
  # 0 in the viewport       goes to scene-cx - scene-width/2 
  # width in the viewport   goes to scene-cx + scene-width/2
  # Therefore:
  # x in the viewport       goes to (scene-cx - scene-width/2) + x*scene-width/width
  # At most two numbers being multiplied before a divide, so no risk of overflow.
  var result/xmm0: float <- convert x
  result <- multiply scene-width
  var width-f/xmm1: float <- convert width
  result <- divide width-f
  result <- add scene-cx
  var two/eax: int <- copy 2
  var two-f/xmm2: float <- convert two
  var half-scene-width/xmm1: float <- copy scene-width
  half-scene-width <- divide two-f
  result <- subtract half-scene-width
  return result
}

fn viewport-to-imaginary y: int, width: int, height: int, scene-cy: float, scene-width: float -> _/xmm1: float {
  # 0 in the viewport       goes to scene-cy - scene-width/2*height/width
  # height in the viewport  goes to scene-cy + scene-width/2*height/width
  # Therefore:
  # y in the viewport       goes to (scene-cy - scene-width/2*height/width) + y*scene-width/width
  #  scene-cy - scene-width/width * (height/2 + y)
  # At most two numbers being multiplied before a divide, so no risk of overflow.
  var result/xmm0: float <- convert y
  result <- multiply scene-width
  var width-f/xmm1: float <- convert width
  result <- divide width-f
  result <- add scene-cy
  var two/eax: int <- copy 2
  var two-f/xmm2: float <- convert two
  var second-term/xmm1: float <- copy scene-width
  second-term <- divide two-f
  var height-f/xmm2: float <- convert height
  second-term <- multiply height-f
  var width-f/xmm2: float <- convert width
  second-term <- divide width-f
  result <- subtract second-term
  return result
}

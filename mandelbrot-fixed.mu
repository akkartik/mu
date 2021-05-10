# Mandelbrot set using fixed-point numbers.
#
# Install:
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
# Build on Linux:
#   $ ./translate mandelbrot-fixed.mu
# Build on other platforms (slow):
#   $ ./translate_emulated mandelbrot-fixed.mu
# Run:
#   $ qemu-system-i386 code.img

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # Initially the viewport is centered at 0, 0 in the scene.
  var scene-cx-f: int
  var scene-cy-f: int
  # Initially the viewport shows a section of the scene 4 units wide.
  var scene-width-f: int
  copy-to scene-width-f, 0x400/4
  {
    mandelbrot screen scene-cx-f, scene-cy-f, scene-width-f
    # move at an angle slowly towards the edge
    var adj-f/eax: int <- multiply-fixed scene-width-f, 0x12/0.07
    subtract-from scene-cx-f, adj-f
    add-to scene-cy-f, adj-f
    # slowly shrink the scene width to zoom in
    var tmp-f/eax: int <- multiply-fixed scene-width-f, 0x80/0.5
    copy-to scene-width-f, tmp-f
    loop
  }
}

# Since they still look like int types, we'll append a '-f' suffix to variable
# names to designate fixed-point numbers.

fn int-to-fixed in: int -> _/eax: int {
  var result-f/eax: int <- copy in
  result-f <- shift-left 8/fixed-precision
  {
    break-if-not-overflow
    abort "int-to-fixed: overflow"
  }
  return result-f
}

fn fixed-to-int in-f: int -> _/eax: int {
  var result/eax: int <- copy in-f
  result <- shift-right-signed 8/fixed-precision
  return result
}

# The process of throwing bits away always adjusts a number towards -infinity.
fn test-fixed-conversion {
  # 0
  var f/eax: int <- int-to-fixed 0
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, 0, "F - test-fixed-conversion - 0"
  # 1
  var f/eax: int <- int-to-fixed 1
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, 1, "F - test-fixed-conversion - 1"
  # -1
  var f/eax: int <- int-to-fixed -1
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, -1, "F - test-fixed-conversion - -1"
  # 0.5 = 1/2
  var f/eax: int <- int-to-fixed 1
  f <- shift-right-signed 1
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, 0, "F - test-fixed-conversion - 0.5"
  # -0.5 = -1/2
  var f/eax: int <- int-to-fixed -1
  f <- shift-right-signed 1
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, -1, "F - test-fixed-conversion - -0.5"
  # 1.5 = 3/2
  var f/eax: int <- int-to-fixed 3
  f <- shift-right-signed 1
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, 1, "F - test-fixed-conversion - 1.5"
  # -1.5 = -3/2
  var f/eax: int <- int-to-fixed -3
  f <- shift-right-signed 1
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, -2, "F - test-fixed-conversion - -1.5"
  # 1.25 = 5/4
  var f/eax: int <- int-to-fixed 5
  f <- shift-right-signed 2
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, 1, "F - test-fixed-conversion - 1.25"
  # -1.25 = -5/4
  var f/eax: int <- int-to-fixed -5
  f <- shift-right-signed 2
  var result/eax: int <- fixed-to-int f
  check-ints-equal result, -2, "F - test-fixed-conversion - -1.25"
}

# special routines for multiplying and dividing fixed-point numbers

fn multiply-fixed a-f: int, b-f: int -> _/eax: int {
  var result/eax: int <- copy a-f
  result <- multiply b-f
  {
    break-if-not-overflow
    abort "multiply-fixed: overflow"
  }
  result <- shift-right-signed 8/fixed-precision
  return result
}

fn divide-fixed a-f: int, b-f: int -> _/eax: int {
  var result-f/eax: int <- copy a-f
  result-f <- shift-left 8/fixed-precision
  {
    break-if-not-overflow
    abort "divide-fixed: overflow"
  }
  var dummy-remainder/edx: int <- copy 0
  result-f, dummy-remainder <- integer-divide result-f, b-f
  return result-f
}

# multiplying or dividing by an integer can use existing instructions.

# adding and subtracting two fixed-point numbers can use existing instructions.

fn mandelbrot screen: (addr screen), scene-cx-f: int, scene-cy-f: int, scene-width-f: int {
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
    var imaginary-f/ebx: int <- viewport-to-imaginary-f y, width, height, scene-cy-f, scene-width-f
    var x/eax: int <- copy 0
    {
      compare x, width
      break-if->=
      var real-f/edx: int <- viewport-to-real-f x, width, scene-cx-f, scene-width-f
      var iterations/esi: int <- mandelbrot-iterations-for-point real-f, imaginary-f, 0x400/max
      iterations <- shift-right 3
      var color/edx: int <- copy 0
      {
        var dummy/eax: int <- copy 0
        dummy, color <- integer-divide iterations, 0x18/24/size-of-cycle-0
        color <- add 0x20/cycle-0
      }
      pixel screen, x, y, color
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn mandelbrot-iterations-for-point real-f: int, imaginary-f: int, max: int -> _/esi: int {
  var x-f/esi: int <- copy 0
  var y-f/edi: int <- copy 0
  var iterations/ecx: int <- copy 0
  {
    var done?/eax: boolean <- mandelbrot-done? x-f, y-f
    compare done?, 0/false
    break-if-!=
    compare iterations, max
    break-if->=
    var x2-f/edx: int <- mandelbrot-x x-f, y-f, real-f
    var y2-f/ebx: int <- mandelbrot-y x-f, y-f, imaginary-f
    x-f <- copy x2-f
    y-f <- copy y2-f
    iterations <- increment
    loop
  }
  return iterations
}

fn mandelbrot-done? x-f: int, y-f: int -> _/eax: boolean {
  # x*x + y*y > 4
  var tmp-f/eax: int <- multiply-fixed x-f, x-f
  var result-f/ecx: int <- copy tmp-f
  tmp-f <- multiply-fixed y-f, y-f
  result-f <- add tmp-f
  compare result-f, 0x400/4
  {
    break-if->
    return 0/false
  }
  return 1/true
}

fn mandelbrot-x x-f: int, y-f: int, real-f: int -> _/edx: int {
  # x*x - y*y + real
  var tmp-f/eax: int <- multiply-fixed x-f, x-f
  var result-f/ecx: int <- copy tmp-f
  tmp-f <- multiply-fixed y-f, y-f
  result-f <- subtract tmp-f
  result-f <- add real-f
  return result-f
}

fn mandelbrot-y x-f: int, y-f: int, imaginary-f: int -> _/ebx: int {
  # 2*x*y + imaginary
  var result-f/eax: int <- copy x-f
  result-f <- shift-left 1/log2
  result-f <- multiply-fixed result-f, y-f
  result-f <- add imaginary-f
  return result-f
}

# Scale (x, y) pixel coordinates to a complex plane where the viewport width
# ranges from -2 to +2. Viewport height just follows the viewport's aspect
# ratio.

fn viewport-to-real-f x: int, width: int, scene-cx-f: int, scene-width-f: int -> _/edx: int {
  # 0 in the viewport       goes to scene-cx - scene-width/2 
  # width in the viewport   goes to scene-cx + scene-width/2
  # Therefore:
  # x in the viewport       goes to (scene-cx - scene-width/2) + x*scene-width/width
  # At most two numbers being multiplied before a divide, so no risk of overflow.
  var result-f/eax: int <- int-to-fixed x
  result-f <- multiply-fixed result-f, scene-width-f
  var width-f/ecx: int <- copy width
  width-f <- shift-left 8/fixed-precision
  result-f <- divide-fixed result-f, width-f
  result-f <- add scene-cx-f
  var half-scene-width-f/ecx: int <- copy scene-width-f
  half-scene-width-f <- shift-right 1
  result-f <- subtract half-scene-width-f
  return result-f
}

fn viewport-to-imaginary-f y: int, width: int, height: int, scene-cy-f: int, scene-width-f: int -> _/ebx: int {
  # 0 in the viewport       goes to scene-cy - scene-width/2*height/width
  # height in the viewport  goes to scene-cy + scene-width/2*height/width
  # Therefore:
  # y in the viewport       goes to (scene-cy - scene-width/2*height/width) + y*scene-width/width
  #  scene-cy - scene-width/width * (height/2 + y)
  # At most two numbers being multiplied before a divide, so no risk of overflow.
  var result-f/eax: int <- int-to-fixed y
  result-f <- multiply-fixed result-f, scene-width-f
  var width-f/ecx: int <- copy width
  width-f <- shift-left 8/fixed-precision
  result-f <- divide-fixed result-f, width-f
  result-f <- add scene-cy-f
  var second-term-f/edx: int <- copy 0
  {
    var _second-term-f/eax: int <- copy scene-width-f
    _second-term-f <- shift-right 1
    var height-f/ebx: int <- copy height
    height-f <- shift-left 8/fixed-precision
    _second-term-f <- multiply-fixed _second-term-f, height-f
    _second-term-f <- divide-fixed _second-term-f, width-f
    second-term-f <- copy _second-term-f
  }
  result-f <- subtract second-term-f
  return result-f
}

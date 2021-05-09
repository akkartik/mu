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
  mandelbrot screen
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

fn mandelbrot screen: (addr screen) {
  var a/eax: int <- copy 0
  var b/ecx: int <- copy 0
  a, b <- screen-size screen
  var width-f/esi: int <- copy a
  width-f <- shift-left 0xb/log2-font-width-and-fixed-precision  # 3 + 8 = 11
  var height-f/edi: int <- copy b
  height-f <- shift-left 0xc/log2-font-height-and-fixed-precision  # 4 + 8 = 12
  var y/ecx: int <- copy 0
  {
    compare y, height-f
    break-if->=
    var imaginary-f/ebx: int <- viewport-to-imaginary-f y, width-f, height-f
    var x/eax: int <- copy 0
    {
      compare x, width-f
      break-if->=
      var real-f/edx: int <- viewport-to-real-f x, width-f
      var iterations/esi: int <- mandelbrot-iterations-for-point real-f, imaginary-f, 0x400/max
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

fn viewport-to-real-f x: int, width-f: int -> _/edx: int {
  # (x - width/2)*4/width
  var result-f/eax: int <- int-to-fixed x
  var half-width-f/ecx: int <- copy width-f
  half-width-f <- shift-right-signed 1/log2
  result-f <- subtract half-width-f
  result-f <- shift-left 2/log4
  result-f <- divide-fixed result-f, width-f
  return result-f
}

fn viewport-to-imaginary-f y: int, width-f: int, height-f: int -> _/ebx: int {
  # (y - height/2)*4/width
  var result-f/eax: int <- int-to-fixed y
  shift-right-signed height-f, 1/log2
  result-f <- subtract height-f
  result-f <- shift-left 2/log4
  result-f <- divide-fixed result-f, width-f
  return result-f
}

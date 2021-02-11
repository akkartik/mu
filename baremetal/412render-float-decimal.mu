# print out floats in decimal
# https://research.swtch.com/ftoa
#
# Basic idea:
#   Ignoring sign, floating point numbers are represented as 1.mantissa * 2^exponent
#   Therefore, to print a float in decimal, we need to:
#     - compute its value without decimal point
#     - convert to an array of decimal digits
#     - print out the array while inserting the decimal point appropriately
#
# Basic complication: the computation generates numbers larger than an int can
# hold. We need a way to represent big ints.
#
# Key insight: use a representation for big ints that's close to what we need
# anyway, an array of decimal digits.
#
# Style note: we aren't creating a big int library here. The only operations
# we need are halving and doubling. Following the link above, it seems more
# comprehensible to keep these operations inlined so that we can track the
# position of the decimal point with dispatch.
#
# This approach turns out to be fast enough for most purposes.
# Optimizations, however, get wildly more complex.

fn test-render-float-decimal-normal {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  # 0.5
  var half/xmm0: float <- rational 1, 2
  var dummy/eax: int <- render-float-decimal screen, half, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "0.5 ", "F - test-render-float-decimal-normal 0.5"
  # 0.25
  clear-screen screen
  var quarter/xmm0: float <- rational 1, 4
  var dummy/eax: int <- render-float-decimal screen, quarter, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "0.25 ", "F - test-render-float-decimal-normal 0.25"
  # 0.75
  clear-screen screen
  var three-quarters/xmm0: float <- rational 3, 4
  var dummy/eax: int <- render-float-decimal screen, three-quarters, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "0.75 ", "F - test-render-float-decimal-normal 0.75"
  # 0.125
  clear-screen screen
  var eighth/xmm0: float <- rational 1, 8
  var dummy/eax: int <- render-float-decimal screen, eighth, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "0.125 ", "F - test-render-float-decimal-normal 0.125"
  # 0.0625; start using scientific notation
  clear-screen screen
  var sixteenth/xmm0: float <- rational 1, 0x10
  var dummy/eax: int <- render-float-decimal screen, sixteenth, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "6.25e-2 ", "F - test-render-float-decimal-normal 0.0625"
  # sqrt(2); truncate floats with lots of digits after the decimal but not too many before
  clear-screen screen
  var two-f/xmm0: float <- rational 2, 1
  var sqrt-2/xmm0: float <- square-root two-f
  var dummy/eax: int <- render-float-decimal screen, sqrt-2, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "1.414 ", "F - test-render-float-decimal-normal √2"
}

# print whole integers without decimals
fn test-render-float-decimal-integer {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  # 1
  var one-f/xmm0: float <- rational 1, 1
  var dummy/eax: int <- render-float-decimal screen, one-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "1 ", "F - test-render-float-decimal-integer 1"
  # 2
  clear-screen screen
  var two-f/xmm0: float <- rational 2, 1
  var dummy/eax: int <- render-float-decimal screen, two-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "2 ", "F - test-render-float-decimal-integer 2"
  # 10
  clear-screen screen
  var ten-f/xmm0: float <- rational 0xa, 1
  var dummy/eax: int <- render-float-decimal screen, ten-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "10 ", "F - test-render-float-decimal-integer 10"
  # -10
  clear-screen screen
  var minus-ten-f/xmm0: float <- rational -0xa, 1
  var dummy/eax: int <- render-float-decimal screen, minus-ten-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "-10 ", "F - test-render-float-decimal-integer -10"
  # 999
  clear-screen screen
  var minus-ten-f/xmm0: float <- rational 0x3e7, 1
  var dummy/eax: int <- render-float-decimal screen, minus-ten-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "999 ", "F - test-render-float-decimal-integer 1000"
  # 1000 - start using scientific notation
  clear-screen screen
  var minus-ten-f/xmm0: float <- rational 0x3e8, 1
  var dummy/eax: int <- render-float-decimal screen, minus-ten-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "1.00e3 ", "F - test-render-float-decimal-integer 1000"
  # 100,000
  clear-screen screen
  var hundred-thousand/eax: int <- copy 0x186a0
  var hundred-thousand-f/xmm0: float <- convert hundred-thousand
  var dummy/eax: int <- render-float-decimal screen, hundred-thousand-f, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "1.00e5 ", "F - test-render-float-decimal-integer 100,000"
}

fn test-render-float-decimal-zero {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  var zero: float
  var dummy/eax: int <- render-float-decimal screen, zero, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "0 ", "F - test-render-float-decimal-zero"
}

fn test-render-float-decimal-negative-zero {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  var n: int
  copy-to n, 0x80000000
  var negative-zero/xmm0: float <- reinterpret n
  var dummy/eax: int <- render-float-decimal screen, negative-zero, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "-0 ", "F - test-render-float-decimal-negative-zero"
}

fn test-render-float-decimal-infinity {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  var n: int
  #          0|11111111|00000000000000000000000
  #          0111|1111|1000|0000|0000|0000|0000|0000
  copy-to n, 0x7f800000
  var infinity/xmm0: float <- reinterpret n
  var dummy/eax: int <- render-float-decimal screen, infinity, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "Inf ", "F - test-render-float-decimal-infinity"
}

fn test-render-float-decimal-negative-infinity {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  var n: int
  copy-to n, 0xff800000
  var negative-infinity/xmm0: float <- reinterpret n
  var dummy/eax: int <- render-float-decimal screen, negative-infinity, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "-Inf ", "F - test-render-float-decimal-negative-infinity"
}

fn test-render-float-decimal-not-a-number {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 5  # 32 columns should be more than enough
  var n: int
  copy-to n, 0xffffffff  # exponent must be all 1's, and mantissa must be non-zero
  var nan/xmm0: float <- reinterpret n
  var dummy/eax: int <- render-float-decimal screen, nan, 3/precision, 0, 0, 3/fg, 0/bg
  check-screen-row screen, 0/y, "NaN ", "F - test-render-float-decimal-not-a-number"
}

# 'precision' controls the maximum width past which we resort to scientific notation
fn render-float-decimal screen: (addr screen), in: float, precision: int, x: int, y: int, color: int, background-color: int -> _/eax: int {
  # - special names
  var bits/eax: int <- reinterpret in
  compare bits, 0
  {
    break-if-!=
    var new-x/eax: int <- draw-text-rightward-over-full-screen screen, "0", x, y, color, background-color
    return new-x
  }
  compare bits, 0x80000000
  {
    break-if-!=
    var new-x/eax: int <- draw-text-rightward-over-full-screen screen, "-0", x, y, color, background-color
    return new-x
  }
  compare bits, 0x7f800000
  {
    break-if-!=
    var new-x/eax: int <- draw-text-rightward-over-full-screen screen, "Inf", x, y, color, background-color
    return new-x
  }
  compare bits, 0xff800000
  {
    break-if-!=
    var new-x/eax: int <- draw-text-rightward-over-full-screen screen, "-Inf", x, y, color, background-color
    return new-x
  }
  var exponent/ecx: int <- copy bits
  exponent <- shift-right 0x17  # 23 bits of mantissa
  exponent <- and 0xff
  exponent <- subtract 0x7f
  compare exponent, 0x80
  {
    break-if-!=
    var new-x/eax: int <- draw-text-rightward-over-full-screen screen, "NaN", x, y, color, background-color
    return new-x
  }
  # - regular numbers
  var sign/edx: int <- copy bits
  sign <- shift-right 0x1f
  {
    compare sign, 1
    break-if-!=
    draw-code-point screen, 0x2d/minus, x, y, color, background-color
    increment x
  }

  # v = 1.mantissa (in base 2) << 0x17
  var v/ebx: int <- copy bits
  v <- and 0x7fffff
  v <- or 0x00800000  # insert implicit 1
  # e = exponent - 0x17
  var e/ecx: int <- copy exponent
  e <- subtract 0x17  # move decimal place from before mantissa to after

  # initialize buffer with decimal representation of v
  # unlike https://research.swtch.com/ftoa, no ascii here
  var buf-storage: (array byte 0x7f)
  var buf/edi: (addr array byte) <- address buf-storage
  var n/eax: int <- decimal-digits v, buf
  # I suspect we can do without reversing, but we'll follow https://research.swtch.com/ftoa
  # closely for now.
  reverse-digits buf, n

  # loop if e > 0
  {
    compare e, 0
    break-if-<=
    n <- double-array-of-decimal-digits buf, n
    e <- decrement
    loop
  }

  var dp/edx: int <- copy n

  # loop if e < 0
  {
    compare e, 0
    break-if->=
    n, dp <- halve-array-of-decimal-digits buf, n, dp
    e <- increment
    loop
  }

  var new-x/eax: int <- render-float-buffer screen, buf, n, dp, precision, x, y, color, background-color
  return new-x
}

# store the decimal digits of 'n' into 'buf', units first
# n must be positive
fn decimal-digits n: int, _buf: (addr array byte) -> _/eax: int {
  var buf/edi: (addr array byte) <- copy _buf
  var i/ecx: int <- copy 0
  var curr/eax: int <- copy n
  var curr-byte/edx: int <- copy 0
  {
    compare curr, 0
    break-if-=
    curr, curr-byte <- integer-divide curr, 0xa
    var dest/ebx: (addr byte) <- index buf, i
    copy-byte-to *dest, curr-byte
    i <- increment
    loop
  }
  return i
}

fn reverse-digits _buf: (addr array byte), n: int {
  var buf/esi: (addr array byte) <- copy _buf
  var left/ecx: int <- copy 0
  var right/edx: int <- copy n
  right <- decrement
  {
    compare left, right
    break-if->=
    {
      var l-a/ecx: (addr byte) <- index buf, left
      var r-a/edx: (addr byte) <- index buf, right
      var l/ebx: byte <- copy-byte *l-a
      var r/eax: byte <- copy-byte *r-a
      copy-byte-to *l-a, r
      copy-byte-to *r-a, l
    }
    left <- increment
    right <- decrement
    loop
  }
}

fn double-array-of-decimal-digits _buf: (addr array byte), _n: int -> _/eax: int {
  var buf/edi: (addr array byte) <- copy _buf
  # initialize delta
  var delta/edx: int <- copy 0
  {
    var curr/ebx: (addr byte) <- index buf, 0
    var tmp/eax: byte <- copy-byte *curr
    compare tmp, 5
    break-if-<
    delta <- copy 1
  }
  # loop
  var x/eax: int <- copy 0
  var i/ecx: int <- copy _n
  i <- decrement
  {
    compare i, 0
    break-if-<=
    # x += 2*buf[i]
    {
      var tmp/ecx: (addr byte) <- index buf, i
      var tmp2/ecx: byte <- copy-byte *tmp
      x <- add tmp2
      x <- add tmp2
    }
    # x, buf[i+delta] = x/10, x%10
    {
      var dest-index/ecx: int <- copy i
      dest-index <- add delta
      var dest/edi: (addr byte) <- index buf, dest-index
      var next-digit/edx: int <- copy 0
      x, next-digit <- integer-divide x, 0xa
      copy-byte-to *dest, next-digit
    }
    #
    i <- decrement
    loop
  }
  # final patch-up
  var n/eax: int <- copy _n
  compare delta, 1
  {
    break-if-!=
    var curr/ebx: (addr byte) <- index buf, 0
    var one/edx: int <- copy 1
    copy-byte-to *curr, one
    n <- increment
  }
  return n
}

fn halve-array-of-decimal-digits _buf: (addr array byte), _n: int, _dp: int -> _/eax: int, _/edx: int {
  var buf/edi: (addr array byte) <- copy _buf
  var n/eax: int <- copy _n
  var dp/edx: int <- copy _dp
  # initialize one side
  {
    # if buf[n-1]%2 == 0, break
    var right-index/ecx: int <- copy n
    right-index <- decrement
    var right-a/ecx: (addr byte) <- index buf, right-index
    var right/ecx: byte <- copy-byte *right-a
    var right-int/ecx: int <- copy right
    var remainder/edx: int <- copy 0
    {
      var dummy/eax: int <- copy 0
      dummy, remainder <- integer-divide right-int, 2
    }
    compare remainder, 0
    break-if-=
    # buf[n] = 0
    var next-a/ecx: (addr byte) <- index buf, n
    var zero/edx: byte <- copy 0
    copy-byte-to *next-a, zero
    # n++
    n <- increment
  }
  # initialize the other
  var delta/ebx: int <- copy 0
  var x/esi: int <- copy 0
  {
    # if buf[0] >= 2, break
    var left/ecx: (addr byte) <- index buf, 0
    var src/ecx: byte <- copy-byte *left
    compare src, 2
    break-if->=
    # delta, x = 1, buf[0]
    delta <- copy 1
    x <- copy src
    # n--
    n <- decrement
    # dp--
    dp <- decrement
  }
  # loop
  var i/ecx: int <- copy 0
  {
    compare i, n
    break-if->=
    # x = x*10 + buf[i+delta]
    {
      var ten/edx: int <- copy 0xa
      x <- multiply ten
      var src-index/edx: int <- copy i
      src-index <- add delta
      var src-a/edx: (addr byte) <- index buf, src-index
      var src/edx: byte <- copy-byte *src-a
      x <- add src
    }
    # buf[i], x = x/2, x%2
    {
      var quotient/eax: int <- copy 0
      var remainder/edx: int <- copy 0
      quotient, remainder <- integer-divide x, 2
      x <- copy remainder
      var dest/edx: (addr byte) <- index buf, i
      copy-byte-to *dest, quotient
    }
    #
    i <- increment
    loop
  }
  return n, dp
}

fn render-float-buffer screen: (addr screen), _buf: (addr array byte), n: int, dp: int, precision: int, x: int, y: int, color: int, background-color: int -> _/eax: int {
  var buf/edi: (addr array byte) <- copy _buf
  {
    compare dp, 0
    break-if->=
    var new-x/eax: int <- render-float-buffer-in-scientific-notation screen, buf, n, dp, precision, x, y, color, background-color
    return new-x
  }
  {
    var dp2/eax: int <- copy dp
    compare dp2, precision
    break-if-<=
    var new-x/eax: int <- render-float-buffer-in-scientific-notation screen, buf, n, dp, precision, x, y, color, background-color
    return new-x
  }
  {
    compare dp, 0
    break-if-!=
    draw-code-point screen, 0x30/0, x, y, color, background-color
    increment x
  }
  var i/eax: int <- copy 0
  # bounds = min(n, dp+3)
  var limit/edx: int <- copy dp
  limit <- add 3
  {
    compare limit, n
    break-if-<=
    limit <- copy n
  }
  {
    compare i, limit
    break-if->=
    # print '.' if necessary
    compare i, dp
    {
      break-if-!=
      draw-code-point screen, 0x2e/decimal-point, x, y, color, background-color
      increment x
    }
    var curr-a/ecx: (addr byte) <- index buf, i
    var curr/ecx: byte <- copy-byte *curr-a
    curr <- add 0x30/0
    var curr-grapheme/ecx: grapheme <- copy curr
    draw-grapheme screen, curr-grapheme, x, y, color, background-color
    increment x
    i <- increment
    loop
  }
  return x
}

fn render-float-buffer-in-scientific-notation screen: (addr screen), _buf: (addr array byte), n: int, dp: int, precision: int, x: int, y: int, color: int, background-color: int -> _/eax: int {
  var buf/edi: (addr array byte) <- copy _buf
  var i/eax: int <- copy 0
  {
    compare i, n
    break-if->=
    compare i, precision
    break-if->=
    compare i, 1
    {
      break-if-!=
      draw-code-point screen, 0x2e/decimal-point, x, y, color, background-color
      increment x
    }
    var curr-a/ecx: (addr byte) <- index buf, i
    var curr/ecx: byte <- copy-byte *curr-a
    curr <- add 0x30/0
    var curr-grapheme/ecx: grapheme <- copy curr
    draw-grapheme screen, curr-grapheme, x, y, color, background-color
    increment x
    #
    i <- increment
    loop
  }
  draw-code-point screen, 0x65/e, x, y, color, background-color
  increment x
  decrement dp
  var new-x/eax: int <- copy 0
  var new-y/ecx: int <- copy 0
  new-x, new-y <- draw-int32-decimal-wrapping-right-then-down-over-full-screen screen, dp, x, y, color, background-color
  return new-x
}

# follows the structure of render-float-decimal
# 'precision' controls the maximum width past which we resort to scientific notation
fn float-size in: float, precision: int -> _/eax: int {
  # - special names
  var bits/eax: int <- reinterpret in
  compare bits, 0
  {
    break-if-!=
    return 1  # for "0"
  }
  compare bits, 0x80000000
  {
    break-if-!=
    return 2  # for "-0"
  }
  compare bits, 0x7f800000
  {
    break-if-!=
    return 3  # for "Inf"
  }
  compare bits, 0xff800000
  {
    break-if-!=
    return 4  # for "-Inf"
  }
  var exponent/ecx: int <- copy bits
  exponent <- shift-right 0x17  # 23 bits of mantissa
  exponent <- and 0xff
  exponent <- subtract 0x7f
  compare exponent, 0x80
  {
    break-if-!=
    return 3  # for "NaN"
  }
  # - regular numbers
  # v = 1.mantissa (in base 2) << 0x17
  var v/ebx: int <- copy bits
  v <- and 0x7fffff
  v <- or 0x00800000  # insert implicit 1
  # e = exponent - 0x17
  var e/ecx: int <- copy exponent
  e <- subtract 0x17  # move decimal place from before mantissa to after

  # initialize buffer with decimal representation of v
  var buf-storage: (array byte 0x7f)
  var buf/edi: (addr array byte) <- address buf-storage
  var n/eax: int <- decimal-digits v, buf
  reverse-digits buf, n

  # loop if e > 0
  {
    compare e, 0
    break-if-<=
    n <- double-array-of-decimal-digits buf, n
    e <- decrement
    loop
  }

  var dp/edx: int <- copy n

  # loop if e < 0
  {
    compare e, 0
    break-if->=
    n, dp <- halve-array-of-decimal-digits buf, n, dp
    e <- increment
    loop
  }

  compare dp, 0
  {
    break-if->=
    return 8  # hacky for scientific notation
  }
  {
    var dp2/eax: int <- copy dp
    compare dp2, precision
    break-if-<=
    return 8  # hacky for scientific notation
  }

  # result = min(n, dp+3)
  var result/ecx: int <- copy dp
  result <- add 3
  {
    compare result, n
    break-if-<=
    result <- copy n
  }

  # account for decimal point
  compare dp, n
  {
    break-if->=
    result <- increment
  }

  # account for sign
  var sign/edx: int <- reinterpret in
  sign <- shift-right 0x1f
  {
    compare sign, 1
    break-if-!=
    result <- increment
  }
  return result
}

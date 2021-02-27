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

fn test-write-float-decimal-approximate-normal {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  # 0.5
  var half/xmm0: float <- rational 1, 2
  write-float-decimal-approximate s, half, 3
  check-stream-equal s, "0.5", "F - test-write-float-decimal-approximate-normal 0.5"
  # 0.25
  clear-stream s
  var quarter/xmm0: float <- rational 1, 4
  write-float-decimal-approximate s, quarter, 3
  check-stream-equal s, "0.25", "F - test-write-float-decimal-approximate-normal 0.25"
  # 0.75
  clear-stream s
  var three-quarters/xmm0: float <- rational 3, 4
  write-float-decimal-approximate s, three-quarters, 3
  check-stream-equal s, "0.75", "F - test-write-float-decimal-approximate-normal 0.75"
  # 0.125
  clear-stream s
  var eighth/xmm0: float <- rational 1, 8
  write-float-decimal-approximate s, eighth, 3
  check-stream-equal s, "0.125", "F - test-write-float-decimal-approximate-normal 0.125"
  # 0.0625; start using scientific notation
  clear-stream s
  var sixteenth/xmm0: float <- rational 1, 0x10
  write-float-decimal-approximate s, sixteenth, 3
  check-stream-equal s, "6.25e-2", "F - test-write-float-decimal-approximate-normal 0.0625"
  # sqrt(2); truncate floats with lots of digits after the decimal but not too many before
  clear-stream s
  var two-f/xmm0: float <- rational 2, 1
  var sqrt-2/xmm0: float <- square-root two-f
  write-float-decimal-approximate s, sqrt-2, 3
  check-stream-equal s, "1.414", "F - test-write-float-decimal-approximate-normal √2"
}

# print whole integers without decimals
fn test-write-float-decimal-approximate-integer {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  # 1
  var one-f/xmm0: float <- rational 1, 1
  write-float-decimal-approximate s, one-f, 3
  check-stream-equal s, "1", "F - test-write-float-decimal-approximate-integer 1"
  # 2
  clear-stream s
  var two-f/xmm0: float <- rational 2, 1
  write-float-decimal-approximate s, two-f, 3
  check-stream-equal s, "2", "F - test-write-float-decimal-approximate-integer 2"
  # 10
  clear-stream s
  var ten-f/xmm0: float <- rational 0xa, 1
  write-float-decimal-approximate s, ten-f, 3
  check-stream-equal s, "10", "F - test-write-float-decimal-approximate-integer 10"
  # -10
  clear-stream s
  var minus-ten-f/xmm0: float <- rational -0xa, 1
  write-float-decimal-approximate s, minus-ten-f, 3
  check-stream-equal s, "-10", "F - test-write-float-decimal-approximate-integer -10"
  # 999
  clear-stream s
  var minus-ten-f/xmm0: float <- rational 0x3e7, 1
  write-float-decimal-approximate s, minus-ten-f, 3
  check-stream-equal s, "999", "F - test-write-float-decimal-approximate-integer 1000"
  # 1000 - start using scientific notation
  clear-stream s
  var minus-ten-f/xmm0: float <- rational 0x3e8, 1
  write-float-decimal-approximate s, minus-ten-f, 3
  check-stream-equal s, "1.00e3", "F - test-write-float-decimal-approximate-integer 1000"
  # 100,000
  clear-stream s
  var hundred-thousand/eax: int <- copy 0x186a0
  var hundred-thousand-f/xmm0: float <- convert hundred-thousand
  write-float-decimal-approximate s, hundred-thousand-f, 3
  check-stream-equal s, "1.00e5", "F - test-write-float-decimal-approximate-integer 100,000"
}

fn test-write-float-decimal-approximate-zero {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  var zero: float
  write-float-decimal-approximate s, zero, 3
  check-stream-equal s, "0", "F - test-write-float-decimal-approximate-zero"
}

fn test-write-float-decimal-approximate-negative-zero {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  var n: int
  copy-to n, 0x80000000
  var negative-zero/xmm0: float <- reinterpret n
  write-float-decimal-approximate s, negative-zero, 3
  check-stream-equal s, "-0", "F - test-write-float-decimal-approximate-negative-zero"
}

fn test-write-float-decimal-approximate-infinity {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  var n: int
  #          0|11111111|00000000000000000000000
  #          0111|1111|1000|0000|0000|0000|0000|0000
  copy-to n, 0x7f800000
  var infinity/xmm0: float <- reinterpret n
  write-float-decimal-approximate s, infinity, 3
  check-stream-equal s, "Inf", "F - test-write-float-decimal-approximate-infinity"
}

fn test-write-float-decimal-approximate-negative-infinity {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  var n: int
  copy-to n, 0xff800000
  var negative-infinity/xmm0: float <- reinterpret n
  write-float-decimal-approximate s, negative-infinity, 3
  check-stream-equal s, "-Inf", "F - test-write-float-decimal-approximate-negative-infinity"
}

fn test-write-float-decimal-approximate-not-a-number {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  var n: int
  copy-to n, 0xffffffff  # exponent must be all 1's, and mantissa must be non-zero
  var nan/xmm0: float <- reinterpret n
  write-float-decimal-approximate s, nan, 3
  check-stream-equal s, "NaN", "F - test-write-float-decimal-approximate-not-a-number"
}

fn print-float-decimal-approximate screen: (addr screen), in: float, precision: int {
  var s-storage: (stream byte 0x10)
  var s/esi: (addr stream byte) <- address s-storage
  write-float-decimal-approximate s, in, precision
  print-stream screen, s
}

# 'precision' controls the maximum width past which we resort to scientific notation
fn write-float-decimal-approximate out: (addr stream byte), in: float, precision: int {
  # - special names
  var bits/eax: int <- reinterpret in
  compare bits, 0
  {
    break-if-!=
    write out, "0"
    return
  }
  compare bits, 0x80000000
  {
    break-if-!=
    write out, "-0"
    return
  }
  compare bits, 0x7f800000
  {
    break-if-!=
    write out, "Inf"
    return
  }
  compare bits, 0xff800000
  {
    break-if-!=
    write out, "-Inf"
    return
  }
  var exponent/ecx: int <- copy bits
  exponent <- shift-right 0x17  # 23 bits of mantissa
  exponent <- and 0xff
  exponent <- subtract 0x7f
  compare exponent, 0x80
  {
    break-if-!=
    write out, "NaN"
    return
  }
  # - regular numbers
  var sign/edx: int <- copy bits
  sign <- shift-right 0x1f
  {
    compare sign, 1
    break-if-!=
    append-byte out, 0x2d/minus
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

  _write-float-array-of-decimal-digits out, buf, n, dp, precision
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

# debug helper
fn dump-digits _buf: (addr array byte), count: int, msg: (addr array byte) {
  var buf/edi: (addr array byte) <- copy _buf
  var i/ecx: int <- copy 0
  print-string 0, msg
  print-string 0, ": "
  {
    compare i, count
    break-if->=
    var curr/edx: (addr byte) <- index buf, i
    var curr-byte/eax: byte <- copy-byte *curr
    var curr-int/eax: int <- copy curr-byte
    print-int32-decimal 0, curr-int
    print-string 0, " "
    break-if-=
    i <- increment
    loop
  }
  print-string 0, "\n"
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

fn _write-float-array-of-decimal-digits out: (addr stream byte), _buf: (addr array byte), n: int, dp: int, precision: int {
  var buf/edi: (addr array byte) <- copy _buf
  {
    compare dp, 0
    break-if->=
    _write-float-array-of-decimal-digits-in-scientific-notation out, buf, n, dp, precision
    return
  }
  {
    var dp2/eax: int <- copy dp
    compare dp2, precision
    break-if-<=
    _write-float-array-of-decimal-digits-in-scientific-notation out, buf, n, dp, precision
    return
  }
  {
    compare dp, 0
    break-if-!=
    append-byte out, 0x30/0
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
      append-byte out, 0x2e/decimal-point
    }
    var curr-a/ecx: (addr byte) <- index buf, i
    var curr/ecx: byte <- copy-byte *curr-a
    var curr-int/ecx: int <- copy curr
    curr-int <- add 0x30/0
    append-byte out, curr-int
    #
    i <- increment
    loop
  }
}

fn _write-float-array-of-decimal-digits-in-scientific-notation out: (addr stream byte), _buf: (addr array byte), n: int, dp: int, precision: int {
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
      append-byte out, 0x2e/decimal-point
    }
    var curr-a/ecx: (addr byte) <- index buf, i
    var curr/ecx: byte <- copy-byte *curr-a
    var curr-int/ecx: int <- copy curr
    curr-int <- add 0x30/0
    append-byte out, curr-int
    #
    i <- increment
    loop
  }
  append-byte out, 0x65/e
  decrement dp
  write-int32-decimal out, dp
}

# follows the structure of write-float-decimal-approximate
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

## helper

# like check-strings-equal, except array sizes don't have to match
fn check-buffer-contains _buf: (addr array byte), _contents: (addr array byte), msg: (addr array byte) {
  var buf/esi: (addr array byte) <- copy _buf
  var contents/edi: (addr array byte) <- copy _contents
  var a/eax: boolean <- string-starts-with? buf, contents
  check-true a, msg
  var len/ecx: int <- length contents
  var len2/eax: int <- length buf
  compare len, len2
  break-if-=
  var c/eax: (addr byte) <- index buf, len
  var d/eax: byte <- copy-byte *c
  var e/eax: int <- copy d
  check-ints-equal e, 0, msg
}

fn test-check-buffer-contains {
  var arr: (array byte 4)
  var a/esi: (addr array byte) <- address arr
  var b/eax: (addr byte) <- index a, 0
  var c/ecx: byte <- copy 0x61/a
  copy-byte-to *b, c
  check-buffer-contains a, "a", "F - test-check-buffer-contains"
  check-buffer-contains "a", "a", "F - test-check-buffer-contains/null"  # no null check when arrays have same length
}

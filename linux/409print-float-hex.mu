# quick-n-dirty way to print out floats in hex
# https://www.exploringbinary.com/hexadecimal-floating-point-constants

# example:
#   0.5 = 0x3f000000 = 0011| 1111 | 0000 | 0000 | 0000 | 0000 | 0000 | 0000
#                    = 0 | 01111110 | 00000000000000000000000
#                      +   exponent   mantissa
#                    = 0 | 00000000000000000000000 | 01111110
#                          mantissa                  exponent
#                    = 0 | 000000000000000000000000 | 01111110
#                          zero-pad mantissa          exponent
#                   =   +1.000000                   P -01
fn test-print-float-hex-normal {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # 0.5
  var half/xmm0: float <- rational 1, 2
  print-float-hex screen, half
  check-screen-row screen, 1, "1.000000P-01 ", "F - test-print-float-hex-normal 0.5"
  # 0.25
  clear-screen screen
  var quarter/xmm0: float <- rational 1, 4
  print-float-hex screen, quarter
  check-screen-row screen, 1, "1.000000P-02 ", "F - test-print-float-hex-normal 0.25"
  # 0.75
  clear-screen screen
  var three-quarters/xmm0: float <- rational 3, 4
  print-float-hex screen, three-quarters
  check-screen-row screen, 1, "1.800000P-01 ", "F - test-print-float-hex-normal 0.75"
  # 0.1
  clear-screen screen
  var tenth/xmm0: float <- rational 1, 0xa
  print-float-hex screen, tenth
  check-screen-row screen, 1, "1.99999aP-04 ", "F - test-print-float-hex-normal 0.1"
}

fn test-print-float-hex-integer {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # 1
  var one-f/xmm0: float <- rational 1, 1
  print-float-hex screen, one-f
  check-screen-row screen, 1, "1.000000P00 ", "F - test-print-float-hex-integer 1"
  # 2
  clear-screen screen
  var two-f/xmm0: float <- rational 2, 1
  print-float-hex screen, two-f
  check-screen-row screen, 1, "1.000000P01 ", "F - test-print-float-hex-integer 2"
  # 10
  clear-screen screen
  var ten-f/xmm0: float <- rational 0xa, 1
  print-float-hex screen, ten-f
  check-screen-row screen, 1, "1.400000P03 ", "F - test-print-float-hex-integer 10"
  # -10
  clear-screen screen
  var minus-ten-f/xmm0: float <- rational -0xa, 1
  print-float-hex screen, minus-ten-f
  check-screen-row screen, 1, "-1.400000P03 ", "F - test-print-float-hex-integer -10"
}

fn test-print-float-hex-zero {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  var zero: float
  print-float-hex screen, zero
  check-screen-row screen, 1, "0 ", "F - test-print-float-hex-zero"
}

fn test-print-float-hex-negative-zero {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  var n: int
  copy-to n, 0x80000000
  var negative-zero/xmm0: float <- reinterpret n
  print-float-hex screen, negative-zero
  check-screen-row screen, 1, "-0 ", "F - test-print-float-hex-negative-zero"
}

fn test-print-float-hex-infinity {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  var n: int
  #          0|11111111|00000000000000000000000
  #          0111|1111|1000|0000|0000|0000|0000|0000
  copy-to n, 0x7f800000
  var infinity/xmm0: float <- reinterpret n
  print-float-hex screen, infinity
  check-screen-row screen, 1, "Inf ", "F - test-print-float-hex-infinity"
}

fn test-print-float-hex-negative-infinity {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  var n: int
  copy-to n, 0xff800000
  var negative-infinity/xmm0: float <- reinterpret n
  print-float-hex screen, negative-infinity
  check-screen-row screen, 1, "-Inf ", "F - test-print-float-hex-negative-infinity"
}

fn test-print-float-hex-not-a-number {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  var n: int
  copy-to n, 0xffffffff  # exponent must be all 1's, and mantissa must be non-zero
  var negative-infinity/xmm0: float <- reinterpret n
  print-float-hex screen, negative-infinity
  check-screen-row screen, 1, "NaN ", "F - test-print-float-hex-not-a-number"
}

fn print-float-hex screen: (addr screen), n: float {
  # - special names
  var bits/eax: int <- reinterpret n
  compare bits, 0
  {
    break-if-!=
    print-string screen, "0"
    return
  }
  compare bits, 0x80000000
  {
    break-if-!=
    print-string screen, "-0"
    return
  }
  compare bits, 0x7f800000
  {
    break-if-!=
    print-string screen, "Inf"
    return
  }
  compare bits, 0xff800000
  {
    break-if-!=
    print-string screen, "-Inf"
    return
  }
  var exponent/ecx: int <- copy bits
  exponent <- shift-right 0x17  # 23 bits of mantissa
  exponent <- and 0xff
  exponent <- subtract 0x7f
  compare exponent, 0x80
  {
    break-if-!=
    print-string screen, "NaN"
    return
  }
  # - regular numbers
  var sign/edx: int <- copy bits
  sign <- shift-right 0x1f
  {
    compare sign, 1
    break-if-!=
    print-string screen, "-"
  }
  $print-float-hex:leading-digit: {
    # check for subnormal numbers
    compare exponent, -0x7f
    {
      break-if-!=
      print-string screen, "0."
      exponent <- increment
      break $print-float-hex:leading-digit
    }
    # normal numbers
    print-string screen, "1."
  }
  var mantissa/ebx: int <- copy bits
  mantissa <- and 0x7fffff
  mantissa <- shift-left 1  # pad to whole nibbles
  print-int32-hex-bits screen, mantissa, 0x18
  # print exponent
  print-string screen, "P"
  compare exponent, 0
  {
    break-if->=
    print-string screen, "-"
  }
  var exp-magnitude/eax: int <- abs exponent
  print-int32-hex-bits screen, exp-magnitude, 8
}

#? fn main -> _/ebx: int {
#?   run-tests
#? #?   test-print-float-hex-negative-zero
#? #?   print-int32-hex 0, 0
#? #?   test-print-float-hex-normal
#?   return 0
#? }

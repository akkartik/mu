# quick-n-dirty way to print out floats in hex

# examples:
#   0.5 = 0x3f000000 = 0011| 1111 | 0000 | 0000 | 0000 | 0000 | 0000 | 0000
#                    = 0 | 01111110 | 00000000000000000000000
#                      +   exponent   mantissa
#                    = 0 | 00000000000000000000000 | 01111110
#                          mantissa                  exponent
#                    = 0 | 000000000000000000000000 | 01111110
#                          zero-pad mantissa          exponent
#                   =   +1.000000                   P -01
fn test-print-float-normal {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # print 0.5
  var one/eax: int <- copy 1
  var half/xmm0: float <- convert one
  var two/eax: int <- copy 2
  var two-f/xmm1: float <- convert two
  half <- divide two-f
  print-float screen, half
  #
  check-screen-row screen, 1, "1.000000P-01 ", "F - test-print-float-normal"
}

fn test-print-float-zero {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # print 0
  var zero: float
  print-float screen, zero
  #
  check-screen-row screen, 1, "0 ", "F - test-print-float-zero"
}

fn test-print-float-negative-zero {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # print 0
  var n: int
  copy-to n, 0x80000000
  var negative-zero/xmm0: float <- reinterpret n
  print-float screen, negative-zero
  #
  check-screen-row screen, 1, "-0 ", "F - test-print-float-negative-zero"
}

fn test-print-float-infinity {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # print
  var n: int
  #          0|11111111|00000000000000000000000
  #          0111|1111|1000|0000|0000|0000|0000|0000
  copy-to n, 0x7f800000
  var infinity/xmm0: float <- reinterpret n
  print-float screen, infinity
  #
  check-screen-row screen, 1, "Inf ", "F - test-print-float-infinity"
}

fn test-print-float-negative-infinity {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # print
  var n: int
  copy-to n, 0xff800000
  var negative-infinity/xmm0: float <- reinterpret n
  print-float screen, negative-infinity
  #
  check-screen-row screen, 1, "-Inf ", "F - test-print-float-negative-infinity"
}

fn test-print-float-not-a-number {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 0x20  # 32 columns should be more than enough
  # print
  var n: int
  copy-to n, 0xffffffff  # exponent must be all 1's, and mantissa must be non-zero
  var negative-infinity/xmm0: float <- reinterpret n
  print-float screen, negative-infinity
  #
  check-screen-row screen, 1, "Nan ", "F - test-print-float-not-a-number"
}

fn print-float screen: (addr screen), n: float {
$print-float:body: {
  # - special names
  var bits/eax: int <- reinterpret n
  compare bits, 0
  {
    break-if-!=
    print-string screen, "0"
    break $print-float:body
  }
  compare bits, 0x80000000
  {
    break-if-!=
    print-string screen, "-0"
    break $print-float:body
  }
  compare bits, 0x7f800000
  {
    break-if-!=
    print-string screen, "Inf"
    break $print-float:body
  }
  compare bits, 0xff800000
  {
    break-if-!=
    print-string screen, "-Inf"
    break $print-float:body
  }
  var exponent/ecx: int <- copy bits
  exponent <- shift-right 0x17  # 23 bits of mantissa
  exponent <- and 0xff
  compare exponent, 0xff
  {
    break-if-!=
    print-string screen, "Nan"
    break $print-float:body
  }
  # - regular numbers
  var sign/edx: int <- copy bits
  sign <- shift-right 0x1f
  {
    compare sign, 1
    break-if-!=
    print-string screen, "-"
  }
  $print-float:leading-digit: {
    # check for subnormal numbers
    compare exponent, 0
    {
      break-if-!=
      print-string screen, "0."
      exponent <- increment
      break $print-float:leading-digit
    }
    # normal numbers
    print-string screen, "1."
  }
  var mantissa/ebx: int <- copy bits
  mantissa <- and 0x7fffff
  print-int32-hex-bits screen, mantissa, 0x18
  # print exponent
  print-string screen, "P"
  exponent <- subtract 0x7f
  compare exponent, 0
  {
    break-if->=
    print-string screen, "-"
  }
  var exp-magnitude/eax: int <- abs exponent
  print-int32-hex-bits screen, exp-magnitude, 8
}
}

#? fn main -> r/ebx: int {
#?   run-tests
#? #?   test-print-float-negative-zero
#? #?   print-int32-hex 0, 0
#? #?   test-print-float-normal
#?   r <- copy 0
#? }

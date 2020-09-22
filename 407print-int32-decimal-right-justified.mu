# print 'n' with enough leading spaces to be right-justified with 'threshold'
# 'threshold' should be the minimum positive number for some width
fn print-int32-decimal-right-justified screen: (addr screen), n: int, _threshold: int {
  # tweak things for negative numbers
  var n2/ecx: int <- right-justify-threshold-decimal n
  var threshold/eax: int <- copy _threshold
  {
    compare n2, threshold
    break-if->=
    print-grapheme screen, 0x20  # space
    threshold <- try-divide threshold, 0xa
    loop
  }
  print-int32-decimal screen, n
}

# return the minimum positive number with the same width in decimal as 'n'
fn right-justify-threshold-decimal n: int -> result/ecx: int {
  var ten/edx: int <- copy 0xa  # constant
  # replace '-' at the start with '0' at the end
  var curr/eax: int <- copy n
  compare curr, 0
  {
    break-if->=
    curr <- negate
    curr <- multiply ten
  }
  # now we're dealing with a positive number
  result <- copy 1
  {
    compare curr, 0xa
    break-if-<
    curr <- try-divide curr, 0xa
    result <- multiply ten
    loop
  }
}

fn test-right-justify-threshold {
  var x/ecx: int <- right-justify-threshold-decimal 0
  check-ints-equal x, 1, "F - test-right-justify-threshold-decimal: 0"
  x <- right-justify-threshold-decimal 1
  check-ints-equal x, 1, "F - test-right-justify-threshold-decimal: 1"
  x <- right-justify-threshold-decimal 4
  check-ints-equal x, 1, "F - test-right-justify-threshold-decimal: 4"
  x <- right-justify-threshold-decimal 9
  check-ints-equal x, 1, "F - test-right-justify-threshold-decimal: 9"
  x <- right-justify-threshold-decimal 0xa
  check-ints-equal x, 0xa, "F - test-right-justify-threshold-decimal: 10"
  x <- right-justify-threshold-decimal 0xb
  check-ints-equal x, 0xa, "F - test-right-justify-threshold-decimal: 11"
  x <- right-justify-threshold-decimal 0x4f  # 79
  check-ints-equal x, 0xa, "F - test-right-justify-threshold-decimal: 79"
  x <- right-justify-threshold-decimal 0x64  # 100
  check-ints-equal x, 0x64, "F - test-right-justify-threshold-decimal: 100"
  x <- right-justify-threshold-decimal 0x65  # 101
  check-ints-equal x, 0x64, "F - test-right-justify-threshold-decimal: 101"
  x <- right-justify-threshold-decimal 0x3e7  # 999
  check-ints-equal x, 0x64, "F - test-right-justify-threshold-decimal: 999"
  x <- right-justify-threshold-decimal 0x3e8  # 1000
  check-ints-equal x, 0x3e8, "F - test-right-justify-threshold-decimal: 1000"
  x <- right-justify-threshold-decimal -1
  check-ints-equal x, 0xa, "F - test-right-justify-threshold-decimal: -1"
  x <- right-justify-threshold-decimal -0xb  # -11
  check-ints-equal x, 0x64, "F - test-right-justify-threshold-decimal: -11"
}

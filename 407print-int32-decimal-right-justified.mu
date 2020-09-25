# print 'n' with enough leading spaces to be right-justified in 'width'
fn print-int32-decimal-right-justified screen: (addr screen), n: int, _width: int {
  # tweak things for negative numbers
  var n-width/ecx: int <- int-width-decimal n
  var width/eax: int <- copy _width
  {
    compare n-width, width
    break-if->=
    print-grapheme screen, 0x20  # space
    width <- decrement
    loop
  }
  print-int32-decimal screen, n
}

fn int-width-decimal n: int -> result/ecx: int {
  result <- copy 1
  var curr/eax: int <- copy n
  # account for '-'
  compare curr, 0
  {
    break-if->=
    curr <- negate
    result <- increment
  }
  # now we're dealing with a positive number
  {
    compare curr, 0xa
    break-if-<
    curr <- try-divide curr, 0xa
    result <- increment
    loop
  }
}

fn test-int-width-decimal {
  var x/ecx: int <- int-width-decimal 0
  check-ints-equal x, 1, "F - test-int-width-decimal: 0"
  x <- int-width-decimal 1
  check-ints-equal x, 1, "F - test-int-width-decimal: 1"
  x <- int-width-decimal 4
  check-ints-equal x, 1, "F - test-int-width-decimal: 4"
  x <- int-width-decimal 9
  check-ints-equal x, 1, "F - test-int-width-decimal: 9"
  x <- int-width-decimal 0xa
  check-ints-equal x, 2, "F - test-int-width-decimal: 10"
  x <- int-width-decimal 0xb
  check-ints-equal x, 2, "F - test-int-width-decimal: 11"
  x <- int-width-decimal 0x4f  # 79
  check-ints-equal x, 2, "F - test-int-width-decimal: 79"
  x <- int-width-decimal 0x63  # 99
  check-ints-equal x, 2, "F - test-int-width-decimal: 100"
  x <- int-width-decimal 0x64  # 100
  check-ints-equal x, 3, "F - test-int-width-decimal: 100"
  x <- int-width-decimal 0x65  # 101
  check-ints-equal x, 3, "F - test-int-width-decimal: 101"
  x <- int-width-decimal 0x3e7  # 999
  check-ints-equal x, 3, "F - test-int-width-decimal: 999"
  x <- int-width-decimal 0x3e8  # 1000
  check-ints-equal x, 4, "F - test-int-width-decimal: 1000"
  x <- int-width-decimal -1
  check-ints-equal x, 2, "F - test-int-width-decimal: -1"
  x <- int-width-decimal -0xb  # -11
  check-ints-equal x, 3, "F - test-int-width-decimal: -11"
}

# print n with enough leading spaces to be right-justified with max
# only works for positive ints for now
fn print-int32-decimal-right-justified screen: (addr screen), n: int, max: int {
  var threshold/eax: int <- right-justify-threshold max
  {
#?     print-int32-decimal screen, threshold
    compare n, threshold
    break-if->=
#?     print-string screen, "!"
    print-grapheme screen, 0x20  # space
    threshold <- try-divide threshold, 0xa
    loop
  }
  print-int32-decimal screen, n
}

fn right-justify-threshold n: int -> result/eax: int {
  var curr/eax: int <- copy n
  var out/esi: int <- copy 1
  var ten/ecx: int <- copy 0xa  # constant
  {
    compare curr, 0xa
    break-if-<
    curr <- try-divide curr, 0xa
    out <- multiply ten
    loop
  }
  result <- copy out
}

fn test-right-justify-threshold {
  var x/eax: int <- right-justify-threshold 0
  check-ints-equal x, 1, "F - test-right-justify-threshold: 0"
  x <- right-justify-threshold 1
  check-ints-equal x, 1, "F - test-right-justify-threshold: 1"
  x <- right-justify-threshold 4
  check-ints-equal x, 1, "F - test-right-justify-threshold: 4"
  x <- right-justify-threshold 9
  check-ints-equal x, 1, "F - test-right-justify-threshold: 9"
  x <- right-justify-threshold 0xa
  check-ints-equal x, 0xa, "F - test-right-justify-threshold: 10"
  x <- right-justify-threshold 0xb
  check-ints-equal x, 0xa, "F - test-right-justify-threshold: 11"
  x <- right-justify-threshold 0x4f  # 79
  check-ints-equal x, 0xa, "F - test-right-justify-threshold: 79"
  x <- right-justify-threshold 0x64  # 100
  check-ints-equal x, 0x64, "F - test-right-justify-threshold: 100"
  x <- right-justify-threshold 0x3e7  # 999
  check-ints-equal x, 0x64, "F - test-right-justify-threshold: 999"
  x <- right-justify-threshold 0x3e8  # 1000
  check-ints-equal x, 0x3e8, "F - test-right-justify-threshold: 1000"
}

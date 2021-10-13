# no support for scientific notation yet
fn parse-float-decimal in: (addr stream byte) -> _/xmm1: float {
  var zero: float
  var result/xmm1: float <- copy zero
  var first-iter?/ecx: int <- copy 1/true
  rewind-stream in
  var negative?/edx: int <- copy 0/false
  # first loop: integer part
  var ten/eax: int <- copy 0xa
  var ten-f/xmm2: float <- convert ten
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var key/eax: byte <- read-byte in
    compare key, 0x2e/decimal-point
    break-if-=
    $parse-float-decimal:body: {
      compare key, 0x2d/-
      {
        break-if-!=
        compare first-iter?, 0/false
        {
          break-if-!=
          abort "parse-float-decimal: '-' only allowed in first position"
        }
        negative? <- copy 1/true
        break $parse-float-decimal:body
      }
      compare key, 0x30/0
      {
        break-if->=
        abort "parse-float-decimal: invalid character < '0'"
      }
      compare key, 0x39/9
      {
        break-if-<=
        abort "parse-float-decimal: invalid character > '9'"
      }
      # key is now a digit
      var digit-value/eax: int <- copy key
      digit-value <- subtract 0x30
      var digit-value-f/xmm3: float <- convert digit-value
      result <- multiply ten-f
      result <- add digit-value-f
    }
    first-iter? <- copy 0/false
    loop
  }
  # second loop: fraction
  var current-position/xmm0: float <- rational 1, 0xa
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var key/eax: byte <- read-byte in
    compare key, 0x30/0
    {
      break-if->=
      abort "parse-float-decimal: invalid fraction character < '0'"
    }
    compare key, 0x39/9
    {
      break-if-<=
      abort "parse-float-decimal: invalid fraction character > '9'"
    }
    # key is now a digit
    var digit-value/eax: int <- copy key
    digit-value <- subtract 0x30
    var digit-value-f/xmm3: float <- convert digit-value
    digit-value-f <- multiply current-position
    result <- add digit-value-f
    current-position <- divide ten-f
    #
    first-iter? <- copy 0/false
    loop
  }
  # finally, the sign
  compare negative?, 0/false
  {
    break-if-=
    var minus-one/eax: int <- copy -1
    var minus-one-f/xmm2: float <- convert minus-one
    result <- multiply minus-one-f
  }
  return result
}

fn test-parse-float-decimal-zero {
  var s-storage: (stream byte 0x10)
  var s/esi: (addr stream byte) <- address s-storage
  write s, "00"
  var x/xmm1: float <- parse-float-decimal s
  var expected/eax: int <- copy 0
  var expected-f/xmm0: float <- convert expected
  compare x, expected-f
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - test-parse-float-decimal-zero", 3/fg 0/bg
    move-cursor-to-left-margin-of-next-line 0/screen
    count-test-failure
  }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

fn test-parse-float-decimal-integer {
  var s-storage: (stream byte 0x10)
  var s/esi: (addr stream byte) <- address s-storage
  write s, "34"
  var x/xmm1: float <- parse-float-decimal s
  var expected/eax: int <- copy 0x22/34
  var expected-f/xmm0: float <- convert expected
  compare x, expected-f
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - test-parse-float-decimal-integer", 3/fg 0/bg
    move-cursor-to-left-margin-of-next-line 0/screen
    count-test-failure
  }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

fn test-parse-float-decimal-negative-integer {
  var s-storage: (stream byte 0x10)
  var s/esi: (addr stream byte) <- address s-storage
  write s, "-34"
  var x/xmm1: float <- parse-float-decimal s
  var expected/eax: int <- copy -0x22/-34
  var expected-f/xmm0: float <- convert expected
  compare x, expected-f
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - test-parse-float-decimal-negative-integer", 3/fg 0/bg
    move-cursor-to-left-margin-of-next-line 0/screen
    count-test-failure
  }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

fn test-parse-float-decimal-fraction {
  var s-storage: (stream byte 0x10)
  var s/esi: (addr stream byte) <- address s-storage
  write s, "3.4"
  var x/xmm1: float <- parse-float-decimal s
  var expected-f/xmm0: float <- rational 0x22/34, 0xa/10
  compare x, expected-f
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - test-parse-float-decimal-fraction", 3/fg 0/bg
    move-cursor-to-left-margin-of-next-line 0/screen
    count-test-failure
  }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

fn test-parse-float-decimal-negative-fraction {
  var s-storage: (stream byte 0x10)
  var s/esi: (addr stream byte) <- address s-storage
  write s, "-3.4"
  var x/xmm1: float <- parse-float-decimal s
  var expected-f/xmm0: float <- rational -0x22/-34, 0xa/10
  compare x, expected-f
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - test-parse-float-decimal-negative-fraction", 3/fg 0/bg
    move-cursor-to-left-margin-of-next-line 0/screen
    count-test-failure
  }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

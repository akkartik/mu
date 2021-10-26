fn to-km miles: float -> _/xmm1: float {
  var result/xmm1: float <- copy miles
  var factor/xmm0: float <- rational 0x649, 0x3e8  # 1.609 = 1609/1000 in hex
  # fill in the blanks to compute miles * factor

  return result
}

fn test-to-km {
  # 0 miles = 0 km
  var zero: float  # Mu implicitly initializes variables in memory to 0
  var result/xmm1: float <- to-km zero
  compare result, zero
  {
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - 0 miles = 0 km\n", 3/fg 0/bg
    count-test-failure
  }
  # 1 mile = 1.609 km approximately
  var one/eax: int <- copy 1
  var one-float/xmm0: float <- convert one
  result <- to-km one-float
  var lower-bound/xmm0: float <- rational 0x649, 0x3e8  # 1609/1000 in hex
  {
    compare result, lower-bound
    break-if-float>=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - 1 mile > 1.609 km\n", 3/fg 0/bg
    count-test-failure
  }
  var upper-bound/xmm0: float <- rational 0x64a, 0x3e8  # 1610/1000 in hex
  {
    compare result, upper-bound
    break-if-float<=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - 1 mile < 1.610 km\n", 3/fg 0/bg
    count-test-failure
  }
  # 2 miles = 3.218 km approximately
  var two/eax: int <- copy 2
  var two-float/xmm0: float <- convert two
  result <- to-km two-float
  var lower-bound/xmm0: float <- rational 0xc92, 0x3e8  # 3218/1000 in hex
  {
    compare result, lower-bound
    break-if-float>=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - 2 miles > 3.218 km\n", 3/fg 0/bg
    count-test-failure
  }
  var upper-bound/xmm0: float <- rational 0xc93, 0x3e8  # 3219/1000 in hex
  {
    compare result, upper-bound
    break-if-float<=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - 2 miles < 3.219 km\n", 3/fg 0/bg
    count-test-failure
  }
}

fn main {
}

# Some slow but convenient helpers

# slow, iterative shift-left instruction
# preconditions: _nr >= 0, _dr > 0
fn repeated-shift-left nr: int, dr: int -> _/eax: int {
  var result/eax: int <- copy nr
  {
    compare dr, 0
    break-if-<=
    result <- shift-left 1
    decrement dr
    loop
  }
  return result
}

# slow, iterative shift-right instruction
# preconditions: _nr >= 0, _dr > 0
fn repeated-shift-right nr: int, dr: int -> _/eax: int {
  var result/eax: int <- copy nr
  {
    compare dr, 0
    break-if-<=
    result <- shift-right 1
    decrement dr
    loop
  }
  return result
}

fn abs n: int -> _/eax: int {
  var result/eax: int <- copy n
  {
    compare n, 0
    break-if->=
    result <- negate
  }
  return result
}

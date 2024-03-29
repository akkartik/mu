# Some quick-n-dirty ways to create floats.

fn fill-in-rational _out: (addr float), nr: int, dr: int {
  var out/edi: (addr float) <- copy _out
  var result/xmm0: float <- convert nr
  var divisor/xmm1: float <- convert dr
  result <- divide divisor
  copy-to *out, result
}

fn fill-in-sqrt _out: (addr float), n: int {
  var out/edi: (addr float) <- copy _out
  var result/xmm0: float <- convert n
  result <- square-root result
  copy-to *out, result
}

fn rational nr: int, dr: int -> _/xmm0: float {
  var result/xmm0: float <- convert nr
  var divisor/xmm1: float <- convert dr
  result <- divide divisor
  return result
}

# n/m rounded up
fn scale-down-and-round-up n: int, m: int -> _/ecx: int {
  var result/ecx: int <- copy n
  result <- add m
  result <- decrement
  var result-f/xmm0: float <- convert result
  var m-f/xmm1: float <- convert m
  result-f <- divide m-f
  result <- truncate result-f
  return result
}

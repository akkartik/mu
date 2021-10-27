fn f -> _/eax: int {
  var result/ecx: int <- copy 0
  return result
}

fn main {
  var x/eax: int <- f
}

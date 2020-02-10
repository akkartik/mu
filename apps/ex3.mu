fn main -> result/ebx: int {
  result <- copy 0
  var i/eax: int <- copy 1
  {
    compare i, 0xa
    break-if->
    result <- add i
    i <- increment
    loop
  }
}

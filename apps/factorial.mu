fn main -> result/ebx: int {
  var tmp/eax: int <- factorial 5
  result <- copy tmp
}

fn factorial n: int -> result/eax: int {
  compare n 1
  {
    break-if->
    result <- copy 1
  }
  {
    break-if-<=
    var tmp/ecx: int <- copy n
    tmp <- decrement
    result <- factorial tmp
    result <- multiply n
  }
}

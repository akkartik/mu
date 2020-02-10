fn main -> result/ebx: int {
#?   run-tests
#?   result <- copy 0
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

fn test-factorial {
  var result/eax: int <- factorial 5
  check-ints-equal result 0x78 "F - test-factorial"
}

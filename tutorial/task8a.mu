fn f a: int {
}

fn main {
  f 0
  var r/eax: int <- copy 3
  f r
  var m: int
  f m
}

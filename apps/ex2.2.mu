fn main -> result/ebx: int {
  result <- foo
}

fn foo -> result/ebx: int {
  var n: int
  copy-to n 3
  increment n
  result <- copy n
}

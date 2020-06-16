fn main -> exit-status/ebx: int {
  var val/eax: int <- num
  print-int32-to-screen val
  print-string "\n"
  exit-status <- copy 0
}

fn num -> result/eax: int {
  var out/edi: int <- copy 0
  {
    var c/eax: byte <- read-key
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == ' ') break
    compare c, 0x20  # space
    break-if-=
    # if (c == '\n') break
    compare c, 0xa  # newline
    break-if-=
    # out *= 10
    {
      var ten/eax: int <- copy 0xa
      out <- multiply ten
    }
    # out += digit(c)
    var digit/eax: int <- to-decimal-digit c
    out <- add digit
    loop
  }
  result <- copy out
}

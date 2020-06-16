fn main -> exit-status/ebx: int {
  {
    var c/eax: byte <- read-key
    # if (c == 0) break
    compare c, 0
    break-if-=
    # parse an int from screen and print it out
    var n/eax: int <- num c
    print-int32-to-screen n
    print-string "\n"
    loop
  }
  exit-status <- copy 0
}

fn num firstc: byte -> result/eax: int {
  var out/edi: int <- copy 0
  {
    var first-digit/eax: int <- to-decimal-digit firstc
    out <- copy first-digit
  }
  {
    var c/eax: byte <- read-key
    # if (c == 0) break
    compare c, 0
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

fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var filename/eax: (addr array byte) <- first-arg args
  var file/eax: (addr buffered-file) <- load-file filename
  dump file
  exit-status <- copy 0
}

fn first-arg args-on-stack: (addr array (addr array byte)) -> out/eax: (addr array byte) {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

fn load-file filename: (addr array byte) -> out/eax: (addr buffered-file) {
  var result: (handle buffered-file)
  {
    var tmp1/eax: (addr handle buffered-file) <- address result
    open filename, 0, tmp1
  }
  out <- lookup result
}

fn dump in: (addr buffered-file) {
  {
    var c/eax: byte <- read-byte-buffered in
    compare c, 0xffffffff  # EOF marker
    break-if-=
    print-byte 0, c
    loop
  }
}

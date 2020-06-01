type file-state {
  source: (handle buffered-file)
  at-start-of-line?: boolean
  heading-level?: int
}

fn init-file-state self: (addr file-state), filename: (addr array byte) {
#?   var file/esi: (addr buffered-file) <- load-file filename
  load-buffer-file self, filename
  # self->at-start-of-line? = true
  # self->heading-level? = 0
}

fn done-reading? self: (addr file-state) -> result/eax: boolean {
}

fn load-file filename: (addr array byte) -> out/esi: (addr buffered-file) {
  var result: (handle buffered-file)
  {
    var tmp1/eax: (addr handle buffered-file) <- address result
    open filename, 0, tmp1
  }
  var tmp2/eax: (addr buffered-file) <- lookup result
  out <- copy tmp2
}

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte c
  loop
}

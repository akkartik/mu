type file-state {
  source: (handle buffered-file)
  eof?: boolean
}

fn init-file-state _self: (addr file-state), filename: (addr array byte) {
  var self/eax: (addr file-state) <- copy _self
  load-file self, filename
  var eof/eax: (addr boolean) <- get self, eof?
  copy-to *eof, 0  # false
}

fn load-file _self: (addr file-state), filename: (addr array byte) {
  var self/eax: (addr file-state) <- copy _self
  var out/esi: (addr handle buffered-file) <- get self, source
  open filename, 0, out  # 0 = read mode
}

fn next-char _self: (addr file-state) -> result/eax: byte {
  var self/ecx: (addr file-state) <- copy _self
  var source/eax: (addr handle buffered-file) <- get self, source
  var in/eax: (addr buffered-file) <- lookup *source
  result <- read-byte-buffered in
  # if result == EOF, set eof?
  compare result, 0xffffffff  # EOF marker
  {
    var eof/ecx: (addr boolean) <- get self, eof?
    copy-to *eof, 1  # true
  }
}

fn done-reading? _self: (addr file-state) -> result/eax: boolean {
  var self/eax: (addr file-state) <- copy _self
  var eof/eax: (addr boolean) <- get self, eof?
  result <- copy *eof
}

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte 0, c
  loop
}

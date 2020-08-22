fn main args: (addr array addr array byte) -> exit-status/ebx: int {
  # initialize fs from args[1]
  var filename/eax: (addr array byte) <- first-arg args
  var file-state-storage: file-state
  var fs/esi: (addr file-state) <- address file-state-storage
  init-file-state fs, filename
  render fs
  exit-status <- copy 0
}

fn render fs: (addr file-state) {
  render-normal fs
}

fn render-normal fs: (addr file-state) {
  {
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    #
    var g/eax: grapheme <- copy c
    print-grapheme 0, g
    #
    loop
  }
}

fn first-arg args-on-stack: (addr array addr array byte) -> out/eax: (addr array byte) {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

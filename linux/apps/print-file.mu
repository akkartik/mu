# accept a filename on the commandline, read it and print it out to screen
# only ascii right now, just like the rest of Mu
#
# To run:
#   $ ./translate apps/print-file.mu
#   $ echo abc > x
#   $ ./a.elf x
#   abc

fn main _args: (addr array addr array byte) -> _/ebx: int {
  var args/eax: (addr array addr array byte) <- copy _args
  var n/ecx: int <- length args
  compare n, 1
  {
    break-if->
    print-string 0/screen, "usage: cat <filename>\n"
    return 0
  }
  {
    break-if-<=
    var filename/edx: (addr addr array byte) <- index args 1
    var in: (handle buffered-file)
    {
      var addr-in/eax: (addr handle buffered-file) <- address in
      open *filename, 0/read-only, addr-in
    }
    var _in-addr/eax: (addr buffered-file) <- lookup in
    var in-addr/ecx: (addr buffered-file) <- copy _in-addr
    {
      var c/eax: byte <- read-byte-buffered in-addr
      compare c, 0xffffffff/end-of-file
      break-if-=
      var g/eax: code-point-utf8 <- copy c
      print-code-point-utf8 0/screen, g
      loop
    }
  }
  return 0
}

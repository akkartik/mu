# accept a filename on the commandline, read it and print it out to screen
# only ascii right now, just like the rest of Mu

fn main _args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var args/eax: (addr array (addr array byte)) <- copy _args
$main-body: {
    var n/ecx: int <- length args
    compare n, 1
    {
      break-if->
      print-string "usage: cat <filename>\n"
      break $main-body
    }
    {
      break-if-<=
      var filename/edx: (addr addr array byte) <- index args 1
      var in: (handle buffered-file)
      {
        var addr-in/eax: (addr handle buffered-file) <- address in
        open *filename, 0, addr-in
      }
      var in-addr/eax: (addr buffered-file) <- lookup in
      print-string "filename: "
      print-string *filename
      print-string ": "
      print-int32-to-screen in-addr
      print-string "\n"
    }
  }
  exit-status <- copy 0
}

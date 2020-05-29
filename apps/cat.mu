# accept a filename on the commandline, read it and print it out to screen
# only ascii right now, just like the rest of Mu

fn main _args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var args/eax: (addr array (addr array byte)) <- copy _args
  var n/eax: int <- length args
  exit-status <- copy n
}

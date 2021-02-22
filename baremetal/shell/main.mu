# Experimental Mu shell
# A Lisp with indent-sensitivity and infix, no macros. Commas are ignored.

fn main {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  {
    render-sandbox 0/screen, sandbox, 2/x, 2/y
    {
      var key/eax: byte <- read-key 0/keyboard
      compare key, 0
      loop-if-=
      # no way to quit right now; just reboot
      edit-sandbox sandbox, key
    }
    loop
  }
}

fn run in: (addr stream byte), out: (addr stream byte) {
  # tokenize
  # insert parens
  # transform infix
  # token tree
  # syntax tree
  clear-stream out
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme in
    write-grapheme out, g
    loop
  }
}

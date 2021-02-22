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

fn run in: (addr gap-buffer), out: (addr stream byte) {
  # tokenize
  # insert parens
  # transform infix
  # token tree
  # syntax tree
  rewind-gap-buffer in
  clear-stream out
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-from-gap-buffer in
    write-grapheme out, g
    loop
  }
}

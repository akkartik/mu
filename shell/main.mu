# Experimental Mu shell
# A Lisp with indent-sensitivity and infix, no macros. Commas are ignored.

fn main {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  load-sandbox-from-secondary-disk sandbox
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size 0/screen
  {
    render-sandbox 0/screen, sandbox, 2/x, 2/y, width, height
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

# Read a null-terminated sequence of keys from secondary disk and load them
# into sandbox.
fn load-sandbox-from-secondary-disk _self: (addr sandbox) {
  var self/esi: (addr sandbox) <- copy _self
  var s-storage: (stream byte 0x200)
  var s/ebx: (addr stream byte) <- address s-storage
  load-first-sector-from-primary-bus-secondary-drive s
  {
    var done?/eax: boolean <- stream-empty? s
    compare done?, 0/false
    break-if-!=
    var key/eax: byte <- read-byte s
    compare key, 0/null
    break-if-=
    edit-sandbox self, key
    loop
  }
}

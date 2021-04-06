# Experimental Mu shell
# A Lisp with indent-sensitivity and infix, no macros.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  load-sandbox data-disk, sandbox
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  {
    render-sandbox screen, sandbox, 2/x, 2/y, width, height
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      # no way to quit right now; just reboot
      edit-sandbox sandbox, key, screen, keyboard, data-disk
    }
    loop
  }
}

# Read a null-terminated sequence of keys from disk and load them into
# sandbox.
fn load-sandbox data-disk: (addr disk), _self: (addr sandbox) {
  var self/esi: (addr sandbox) <- copy _self
  var s-storage: (stream byte 0x200)
  var s/ebx: (addr stream byte) <- address s-storage
  load-sector data-disk, 0/lba, s
  {
    var done?/eax: boolean <- stream-empty? s
    compare done?, 0/false
    break-if-!=
    var key/eax: byte <- read-byte s
    compare key, 0/null
    break-if-=
    edit-sandbox self, key, 0/no-screen, 0/no-keyboard, 0/no-disk
    loop
  }
}

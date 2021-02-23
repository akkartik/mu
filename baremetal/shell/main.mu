# Experimental Mu shell
# A Lisp with indent-sensitivity and infix, no macros. Commas are ignored.

fn main {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
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

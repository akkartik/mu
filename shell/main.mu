# Experimental Mu shell
# A Lisp with indent-sensitivity and infix.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  load-state env, data-disk
  $main:loop: {
    render-environment screen, env
    # no way to quit right now; just reboot
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      edit-environment env, key, data-disk
    }
    loop
  }
}

# Experimental Mu shell
# Currently based on Lisp.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 0x20/fake-screen-width, 8/fake-screen-height
  load-state env, data-disk
  {
    render-environment screen, env
    # no way to quit right now; just reboot
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      var key/eax: grapheme <- copy key
      edit-environment env, key, data-disk
    }
    loop
  }
}

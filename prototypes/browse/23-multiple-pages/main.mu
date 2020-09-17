fn main args: (addr array addr array byte) -> exit-status/ebx: int {
  # initialize fs from args[1]
  var filename/eax: (addr array byte) <- first-arg args
  var file-state-storage: file-state
  var fs/esi: (addr file-state) <- address file-state-storage
  init-file-state fs, filename
  #
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  # initialize screen state from screen size
  var screen-position-state-storage: screen-position-state
  var screen-position-state/eax: (addr screen-position-state) <- address screen-position-state-storage
  init-screen-position-state screen-position-state
  {
    render fs, screen-position-state
    var key/eax: grapheme <- read-key-from-real-keyboard
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

fn render fs: (addr file-state), state: (addr screen-position-state) {
  start-drawing state
  render-normal fs, state
}

fn render-normal fs: (addr file-state), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0  # false
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    #
    add-char state, c
    #
    loop
  }
}

fn first-arg args-on-stack: (addr array addr array byte) -> out/eax: (addr array byte) {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

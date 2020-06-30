fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  # initialize fs from args[1]
  var filename/eax: (addr array byte) <- first-arg args
  var file-state-storage: file-state
  var fs/esi: (addr file-state) <- address file-state-storage
  init-file-state fs, filename
  #
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  # initialize screen state from screen size
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  var screen-position-state-storage: screen-position-state
  var screen-position-state: (addr screen-position-state)
  init-screen-position-state screen-position-state, nrows, ncols
  {
    var done?/eax: boolean <- done-reading? fs
    compare done?, 0
    break-if-=
    render fs, screen-position-state
    var key/eax: byte <- read-key
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
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') start-bold-on-screen, render-until-asterisk(fs, state), reset
    # else if (c == '_') start-bold-on-screen, render-until-underscore(fs, state), reset
    # else if (c == '#' and fs is at start of line) compute-color, start color, render-header-line(fs, state), reset
    # else add-char(state, c)
  }
}

fn render-until-asterisk fs: (addr file-state), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    # else add-char(state, c)
  }
}

fn render-until-underscore fs: (addr file-state), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '_') break
    # else add-char(state, c)
  }
}

fn render-header-line fs: (addr file-state), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    # else add-char(state, c)
  }
}

fn first-arg args-on-stack: (addr array (addr array byte)) -> out/eax: (addr array byte) {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

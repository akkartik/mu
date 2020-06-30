# Incomplete second attempt at parsing headings.
#
# This 'OO' approach seems more scalable. We hoist out all the outer framework
# for deciding when to increment 'col', when to increment 'row' and when to
# start a new page in a whole new part of the screen. Now it gets encapsulated
# into a series of small helpers that can be called from multiple places.
# Objects as coroutines.
#
# In spite of these advances, I need to first wrestle with a parsing issue.
# This text has a heading:
#
#   abc *def
#   # ghi*
#
# Ugh, so I can't do this translation in a single pass. At the first asterisk
# there's just not enough information to know whether it starts a bold text or
# not.
#
# Then again, maybe I should just keep going and not try to be compatible with
# GitHub-Flavored Markdown. Require that new headings are also new paragraphs.

fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var filename/eax: (addr array byte) <- first-arg args
  var file/esi: (addr buffered-file) <- load-file filename
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  var screen-position-state-storage: screen-position-state
  var screen-position-state: (addr screen-position-state)
  init-screen-position-state screen-position-state, nrows, ncols
  {
    render file, screen-position-state
    var key/eax: byte <- read-key
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

type screen-position-state {
  nrows: int  # const
  ncols: int  # const
  toprow: int
  botrow: int
  leftcol: int
  rightcol: int
  row: int
  col: int
}

fn render in: (addr buffered-file), state: (addr screen-position-state) {
  start-drawing state
  render-normal in, state
}

fn render-normal in: (addr buffered-file), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') start-bold, render-until-asterisk(in, state), reset
    # else if (c == '_') start-bold, render-until-underscore(in, state), reset
    # else if (c == '#') compute-color, start color, render-header-line(in, state), reset
    # else add-char(state, c)
  }
}

fn render-until-asterisk in: (addr buffered-file), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    # else add-char(state, c)
  }
}

fn render-until-underscore in: (addr buffered-file), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '_') break
    # else add-char(state, c)
  }
}

fn render-header-line in: (addr buffered-file), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    # else add-char(state, c)
  }
}

fn init-screen-position-state self: (addr screen-position-state), nrows: int, ncols: int {
  # hardcoded parameters:
  #   top-margin
  #   page-margin
  #   page-width
  var dest/eax: (addr int) <- copy 0
  # self->nrows = nrows
  # self->ncols = ncols
  # self->toprow = top-margin
  # self->botrow = nrows
  # self->leftcol = page-margin
  # self->rightcol = self->leftcol + page-width
  # start-drawing(self)
}

fn start-drawing self: (addr screen-position-state) {
  # self->row = toprow
  # self->col = leftcol
}

fn add-char self: (addr screen-position-state), c: byte {
  # print c
  # self->col++
  # if (self->col > self->rightcol) next-line(self)
}

fn next-line self: (addr screen-position-state) {
  # self->row++
  # if (self->row > self->botrow) next-page(self)
}

fn next-page self: (addr screen-position-state) {
  # self->leftcol = self->rightcol + 5
  # self->rightcol = self->leftcol + page-width
}

fn done-drawing? self: (addr screen-position-state) -> result/eax: boolean {
  # self->rightcol >= self->ncols
}

fn first-arg args-on-stack: (addr array (addr array byte)) -> out/eax: (addr array byte) {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

fn load-file filename: (addr array byte) -> out/esi: (addr buffered-file) {
  var result: (handle buffered-file)
  {
    var tmp1/eax: (addr handle buffered-file) <- address result
    open filename, 0, tmp1
  }
  var tmp2/eax: (addr buffered-file) <- lookup result
  out <- copy tmp2
}

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte-to-screen c
  loop
}

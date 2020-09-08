# If a screen is too wide, split it up into a fixed size of pages.
# We take control of drawing and moving the cursor, and delegate everything else.
# Never scroll; use the 'done-drawing?' method instead.
#
# Example usage:
#   initialize-paginated-screen
#   on each frame
#     start-drawing
#     while !done-drawing
#       add-grapheme ...

type paginated-screen {
  screen: (handle screen)
  nrows: int  # const
  ncols: int  # const
  page-width: int
  top-margin: int
  left-margin: int
  toprow: int
  botrow: int
  leftcol: int
  rightcol: int
  row: int
  col: int
}

fn initialize-paginated-screen _self: (addr paginated-screen), page-width: int, top-margin: int, left-margin: int {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var _screen-addr/eax: (addr screen) <- lookup *screen-ah
  var screen-addr/edi: (addr screen) <- copy _screen-addr
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size screen-addr
  var dest/edx: (addr int) <- copy 0
  # self->nrows = nrows
  dest <- get self, nrows
  copy-to *dest, nrows
  # self->ncols = ncols
  dest <- get self, ncols
  copy-to *dest, ncols
  # self->page-width = page-width
  {
    var tmp/eax: int <- copy page-width
    dest <- get self, page-width
    copy-to *dest, tmp
  }
  # self->top-margin = top-margin
  {
    var tmp/eax: int <- copy top-margin
    dest <- get self, top-margin
    copy-to *dest, tmp
  }
  # self->left-margin = left-margin
  {
    var tmp/eax: int <- copy left-margin
    dest <- get self, left-margin
    copy-to *dest, tmp
  }
  # self->toprow = top-margin
  {
    var tmp/eax: int <- copy top-margin
    dest <- get self, toprow
    copy-to *dest, tmp
  }
  # self->botrow = nrows
  {
    dest <- get self, botrow
    copy-to *dest, nrows
  }
  #
  start-drawing self
}

fn start-drawing _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  clear-paginated-screen self
  var tmp/eax: (addr int) <- copy 0
  var tmp2/ecx: int <- copy 0
  # self->leftcol = left-margin
  tmp <- get self, left-margin
  tmp2 <- copy *tmp
  tmp <- get self, leftcol
  copy-to *tmp, tmp2
  # self->rightcol = self->leftcol + page-width
  tmp <- get self, page-width
  tmp2 <- copy *tmp
  tmp <- get self, rightcol
  copy-to *tmp, tmp2  # left-margin + page-width
  # self->row = self->toprow
  tmp <- get self, toprow
  tmp2 <- copy *tmp
  tmp <- get self, row
  copy-to *tmp, tmp2
  # self->col = self->leftcol
  tmp <- get self, leftcol
  tmp2 <- copy *tmp
  tmp <- get self, col
  copy-to *tmp, tmp2
  #
  reposition-cursor self
}

fn done-drawing? _self: (addr paginated-screen) -> result/eax: boolean {
$done-drawing?:body: {
  # return self->rightcol >= self->ncols
  var self/esi: (addr paginated-screen) <- copy _self
  var max/ecx: (addr int) <- get self, ncols
  var tmp/eax: (addr int) <- get self, rightcol
  var right/eax: int <- copy *tmp
  compare right, *max
  {
    break-if->=
    result <- copy 0  # false
    break $done-drawing?:body
  }
  {
    break-if-<
    result <- copy 1  # true
  }
}
}

fn add-grapheme _self: (addr paginated-screen), c: grapheme {
$add-grapheme:body: {
  var self/esi: (addr paginated-screen) <- copy _self
  {
    compare c, 0xa  # newline
    break-if-!=
    next-line self
    reposition-cursor self
    break $add-grapheme:body
  }
  # print c
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  print-grapheme screen-addr, c
  # self->col++
  var tmp/eax: (addr int) <- get self, col
  increment *tmp
  # if (self->col > self->rightcol) next-line(self)
  var tmp2/ecx: int <- copy *tmp
  tmp <- get self, rightcol
  compare tmp2, *tmp
  {
    break-if-<=
    next-line self
    reposition-cursor self
  }
}
}

## tests

fn test-print-grapheme-on-paginated-screen {
  var pg-on-stack: paginated-screen
  var pg/eax: (addr paginated-screen) <- address pg-on-stack
  initialize-fake-paginated-screen pg, 3, 0xa, 0xa, 0, 0
  start-drawing pg
  var c/ecx: grapheme <- copy 0x61   # 'a'
  add-grapheme pg, c
  var screen-ah/eax: (addr handle screen) <- get pg, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  check-screen-row screen-addr, 1, "a   ", "F - test-print-grapheme-on-paginated-screen"
}

fn initialize-fake-paginated-screen _self: (addr paginated-screen), nrows: int, ncols: int, page-width: int, top-margin: int, left-margin: int {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  allocate screen-ah
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  initialize-screen screen-addr, nrows, ncols
  initialize-paginated-screen self, page-width, top-margin, left-margin
}

## simple delegates

fn reposition-cursor _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var r/ecx: (addr int) <- get self, row
  var c/edx: (addr int) <- get self, col
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  move-cursor screen-addr, *r *c
}

fn clear-paginated-screen _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  clear-screen screen-addr
}

fn start-color-on-paginated-screen _self: (addr paginated-screen), fg: int, bg: int {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  start-color screen-addr, fg, bg
}

fn start-bold-on-paginated-screen _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  start-bold screen-addr
}

fn start-underline-on-paginated-screen _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  start-underline screen-addr
}

fn start-reverse-video-on-paginated-screen _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  start-reverse-video screen-addr
}

fn start-blinking-on-paginated-screen _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  start-blinking screen-addr
}

fn reset-formatting-on-paginated-screen _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  reset-formatting screen-addr
}

## helpers

fn next-line _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var tmp/eax: (addr int) <- copy 0
  var tmp2/ecx: int <- copy 0
  # self->col = self->leftcol
  tmp <- get self, leftcol
  tmp2 <- copy *tmp
  tmp <- get self, col
  copy-to *tmp, tmp2
  # self->row++
  tmp <- get self, row
  increment *tmp
  # if (self->row > self->botrow) next-page(self)
  tmp2 <- copy *tmp
  tmp <- get self, botrow
  compare tmp2, *tmp
  {
    break-if-<=
    next-page self
  }
}

fn next-page _self: (addr paginated-screen) {
  var self/esi: (addr paginated-screen) <- copy _self
  var tmp/eax: (addr int) <- copy 0
  var tmp2/ecx: int <- copy 0
#?   # temporary: stop
#?   tmp <- get self, ncols
#?   tmp2 <- copy *tmp
#?   tmp <- get self, rightcol
#?   copy-to *tmp, tmp2
  # real: multiple pages
  # self->leftcol = self->rightcol + left-margin
  tmp <- get self, rightcol
  tmp2 <- copy *tmp
  tmp <- get self, left-margin
  tmp2 <- add *tmp
  tmp <- get self, leftcol
  copy-to *tmp, tmp2
  # self->rightcol = self->leftcol + page-width
  tmp2 <- copy *tmp
  tmp <- get self, page-width
  tmp2 <- add *tmp
  tmp <- get self, rightcol
  copy-to *tmp, tmp2
  # self->row = self->toprow
  tmp <- get self, toprow
  tmp2 <- copy *tmp
  tmp <- get self, row
  copy-to *tmp, tmp2
  # self->col = self->leftcol
  tmp <- get self, leftcol
  tmp2 <- copy *tmp
  tmp <- get self, col
  copy-to *tmp, tmp2
}

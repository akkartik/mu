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

fn init-screen-position-state _self: (addr screen-position-state) {
  # hardcoded parameters:
  #   top-margin
  #   page-margin
  #   page-width
  var self/esi: (addr screen-position-state) <- copy _self
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  var dest/edx: (addr int) <- copy 0
  # self->nrows = nrows
  dest <- get self, nrows
  copy-to *dest, nrows
  # self->ncols = ncols
  dest <- get self, ncols
  copy-to *dest, ncols
  # self->toprow = top-margin
  dest <- get self, toprow
  copy-to *dest, 2  # top-margin
  # self->botrow = nrows
  dest <- get self, botrow
  copy-to *dest, nrows
  # self->leftcol = page-margin
  dest <- get self, leftcol
  copy-to *dest, 5  # left-margin
  # self->rightcol = self->leftcol + page-width
  dest <- get self, rightcol
  copy-to *dest, 0x45  # left-margin + page-width
  #
  start-drawing self
}

fn start-drawing _self: (addr screen-position-state) {
  var self/esi: (addr screen-position-state) <- copy _self
  var tmp/eax: (addr int) <- copy 0
  var tmp2/ecx: int <- copy 0
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

fn add-char _self: (addr screen-position-state), c: byte {
$add-char:body: {
  var self/esi: (addr screen-position-state) <- copy _self
  {
    compare c, 0xa  # newline
    break-if-!=
    next-line self
    reposition-cursor self
    break $add-char:body
  }
  # print c
  print-byte-to-screen c
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

fn next-line _self: (addr screen-position-state) {
  var self/esi: (addr screen-position-state) <- copy _self
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

fn next-page _self: (addr screen-position-state) {
  var self/esi: (addr screen-position-state) <- copy _self
  # TMP
  var tmp/eax: (addr int) <- get self, row
  increment *tmp
}

fn done-drawing? _self: (addr screen-position-state) -> result/eax: boolean {
  var self/esi: (addr screen-position-state) <- copy _self
  # TMP
  var r/eax: (addr int) <- get self, row
  var tmp/ecx: (addr int) <- get self, botrow
  var max/ecx: int <- copy *tmp
$done-drawing?:check: {
    compare *r, max
    {
      break-if->=
      result <- copy 0  # false
      break $done-drawing?:check
    }
    {
      break-if-<
      result <- copy 1  # true
    }
  }
}

fn reposition-cursor _self: (addr screen-position-state) {
  var self/esi: (addr screen-position-state) <- copy _self
  var r/eax: (addr int) <- get self, row
  var c/ecx: (addr int) <- get self, col
  move-cursor-on-screen *r *c
}

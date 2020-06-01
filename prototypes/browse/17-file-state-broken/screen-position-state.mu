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

fn init-screen-position-state self: (addr screen-position-state), nrows: int, ncols: int {
  # hardcoded parameters:
  #   top-margin
  #   page-margin
  #   text-width
  var dest/eax: (addr int) <- copy 0
  # self->nrows = nrows
  # self->ncols = ncols
  # self->toprow = top-margin
  # self->botrow = nrows
  # self->leftcol = page-margin
  # self->rightcol = self->leftcol + text-width
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
  # self->rightcol = self->leftcol + text-width
}

fn done-drawing? self: (addr screen-position-state) -> result/eax: boolean {
  # self->rightcol >= self->ncols
}

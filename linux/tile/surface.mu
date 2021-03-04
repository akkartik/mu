# A surface is a large 2-D grid that you can only see a subset of through the
# screen.
# Imagine a pin going through both surface and screen. As we update the
# surface contents, the pinned point stays fixed, providing a sense of
# stability.

type surface {
  screen: (handle screen)
  data: (handle array screen-cell)
  nrows: int
  ncols: int
  screen-nrows: int
  screen-ncols: int
  pin-row: int  # 1-indexed
  pin-col: int  # 1-indexed
  pin-screen-row: int  # 1-indexed
  pin-screen-col: int  # 1-indexed
}

# intended mostly for tests; could be slow
fn initialize-surface-with _self: (addr surface), in: (addr array byte) {
  var self/esi: (addr surface) <- copy _self
  # fill in nrows, ncols
  var nrows/ecx: int <- num-lines in
  var dest/eax: (addr int) <- get self, nrows
  copy-to *dest, nrows
  var ncols/edx: int <- first-line-length in  # assume all lines are the same length
  dest <- get self, ncols
  copy-to *dest, ncols
  # fill in data
  var len/ecx: int <- copy nrows
  len <- multiply ncols
  var out/edi: (addr surface) <- copy _self
  var data/eax: (addr handle array screen-cell) <- get out, data
  populate data, len
  var data-addr/eax: (addr array screen-cell) <- lookup *data
  fill-in data-addr, in
  # fill in screen-nrows, screen-ncols
  {
    var screen-ah/eax: (addr handle screen) <- get self, screen
    var _screen-addr/eax: (addr screen) <- lookup *screen-ah
    var screen-addr/edi: (addr screen) <- copy _screen-addr
    var nrows/eax: int <- copy 0
    var ncols/ecx: int <- copy 0
    nrows, ncols <- screen-size screen-addr
    var dest/edi: (addr int) <- get self, screen-nrows
    copy-to *dest, nrows
    dest <- get self, screen-ncols
    copy-to *dest, ncols
  }
}

fn pin-surface-at _self: (addr surface), r: int, c: int {
  var self/esi: (addr surface) <- copy _self
  var dest/ecx: (addr int) <- get self, pin-row
  var tmp/eax: int <- copy r
  copy-to *dest, tmp
  dest <- get self, pin-col
  tmp <- copy c
  copy-to *dest, tmp
}

fn pin-surface-to _self: (addr surface), sr: int, sc: int {
  var self/esi: (addr surface) <- copy _self
  var dest/ecx: (addr int) <- get self, pin-screen-row
  var tmp/eax: int <- copy sr
  copy-to *dest, tmp
  dest <- get self, pin-screen-col
  tmp <- copy sc
  copy-to *dest, tmp
}

fn render-surface _self: (addr surface) {
#?   print-string-to-real-screen "render-surface\n"
  var self/esi: (addr surface) <- copy _self
  # clear screen
  var screen-ah/eax: (addr handle screen) <- get self, screen
  var screen/eax: (addr screen) <- lookup *screen-ah
  clear-screen screen
  #
  var nrows/edx: (addr int) <- get self, screen-nrows
  var ncols/ebx: (addr int) <- get self, screen-ncols
  var screen-row/ecx: int <- copy 1
  {
    compare screen-row, *nrows
    break-if->
    var screen-col/eax: int <- copy 1
    {
      compare screen-col, *ncols
      break-if->
#?       print-string-to-real-screen "X"
      print-surface-cell-at self, screen-row, screen-col
      screen-col <- increment
      loop
    }
#?     print-string-to-real-screen "\n"
    screen-row <- increment
    loop
  }
}

fn print-surface-cell-at _self: (addr surface), screen-row: int, screen-col: int {
  var self/esi: (addr surface) <- copy _self
  var row/ecx: int <- screen-row-to-surface self, screen-row
  var col/edx: int <- screen-col-to-surface self, screen-col
  var data-ah/edi: (addr handle array screen-cell) <- get self, data
  var _data-addr/eax: (addr array screen-cell) <- lookup *data-ah
  var data-addr/edi: (addr array screen-cell) <- copy _data-addr
  var idx/eax: int <- surface-screen-cell-index self, row, col
  # if out of bounds, print ' '
  compare idx, 0
  {
    break-if->=
    var space/ecx: grapheme <- copy 0x20
    var screen-ah/edi: (addr handle screen) <- get self, screen
    var screen/eax: (addr screen) <- lookup *screen-ah
    print-grapheme screen, space
    return
  }
  # otherwise print the appropriate screen-cell
  var offset/ecx: (offset screen-cell) <- compute-offset data-addr, idx
  var src/ecx: (addr screen-cell) <- index data-addr, offset
  var screen-ah/edi: (addr handle screen) <- get self, screen
  var screen/eax: (addr screen) <- lookup *screen-ah
  print-screen-cell screen, src
}

# print a cell with all its formatting at the cursor location
fn print-screen-cell screen: (addr screen), _cell: (addr screen-cell) {
  var cell/esi: (addr screen-cell) <- copy _cell
  reset-formatting screen
  var fg/eax: (addr int) <- get cell, color
  var bg/ecx: (addr int) <- get cell, background-color
  start-color screen, *fg, *bg
  var tmp/eax: (addr boolean) <- get cell, bold?
  {
    compare *tmp, 0
    break-if-=
    start-bold screen
  }
  {
    tmp <- get cell, underline?
    compare *tmp, 0
    break-if-=
    start-underline screen
  }
  {
    tmp <- get cell, reverse?
    compare *tmp, 0
    break-if-=
    start-reverse-video screen
  }
  {
    tmp <- get cell, blink?
    compare *tmp, 0
    break-if-=
    start-blinking screen
  }
  var g/eax: (addr grapheme) <- get cell, data
  print-grapheme screen, *g
#?   var g2/eax: grapheme <- copy *g
#?   var g3/eax: int <- copy g2
#?   print-int32-hex-to-real-screen g3
#?   print-string-to-real-screen "\n"
}

fn surface-screen-cell-index _self: (addr surface), row: int, col: int -> _/eax: int {
  var self/esi: (addr surface) <- copy _self
#?   print-int32-hex-to-real-screen row
#?   print-string-to-real-screen ", "
#?   print-int32-hex-to-real-screen col
#?   print-string-to-real-screen "\n"
  var result/eax: int <- copy -1
  {
    compare row, 1
    break-if-<
    compare col, 1
    break-if-<
    var nrows-addr/ecx: (addr int) <- get self, nrows
    var nrows/ecx: int <- copy *nrows-addr
    compare row, nrows
    break-if->
    var ncols-addr/ecx: (addr int) <- get self, ncols
    var ncols/ecx: int <- copy *ncols-addr
    compare col, ncols
    break-if->
  #?   print-string-to-real-screen "!\n"
    result <- copy row
    result <- subtract 1
    result <- multiply ncols
    result <- add col
    result <- subtract 1
  }
  return result
}

fn screen-row-to-surface _self: (addr surface), screen-row: int -> _/ecx: int {
  var self/esi: (addr surface) <- copy _self
  var result/ecx: int <- copy screen-row
  var tmp/eax: (addr int) <- get self, pin-row
  result <- add *tmp
  tmp <- get self, pin-screen-row
  result <- subtract *tmp
  return result
}

fn max _a: int, b: int -> _/eax: int {
  var a/eax: int <- copy _a
  compare a, b
  {
    break-if->
    return b
  }
  return a
}

fn min _a: int, b: int -> _/eax: int {
  var a/eax: int <- copy _a
  compare a, b
  {
    break-if->
    return a
  }
  return b
}

fn screen-col-to-surface _self: (addr surface), screen-col: int -> _/edx: int {
  var self/esi: (addr surface) <- copy _self
  var result/edx: int <- copy screen-col
  var tmp/eax: (addr int) <- get self, pin-col
  result <- add *tmp
  tmp <- get self, pin-screen-col
  result <- subtract *tmp
  return result
}

fn surface-row-to-screen _self: (addr surface), row: int -> _/ecx: int {
  var self/esi: (addr surface) <- copy _self
  var result/ecx: int <- copy row
  var tmp/eax: (addr int) <- get self, pin-screen-row
  result <- add *tmp
  tmp <- get self, pin-row
  result <- subtract *tmp
  return result
}

fn surface-col-to-screen _self: (addr surface), col: int -> _/edx: int {
  var self/esi: (addr surface) <- copy _self
  var result/edx: int <- copy col
  var tmp/eax: (addr int) <- get self, pin-screen-col
  result <- add *tmp
  tmp <- get self, pin-col
  result <- subtract *tmp
  return result
}

# assumes last line doesn't end in '\n'
fn num-lines in: (addr array byte) -> _/ecx: int {
  var s: (stream byte 0x100)
  var s-addr/esi: (addr stream byte) <- address s
  write s-addr, in
  var result/ecx: int <- copy 1
  {
    var done?/eax: boolean <- stream-empty? s-addr
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme s-addr
    compare g, 0xa/newline
    loop-if-!=
    result <- increment
    loop
  }
  return result
}

fn first-line-length in: (addr array byte) -> _/edx: int {
  var s: (stream byte 0x100)
  var s-addr/esi: (addr stream byte) <- address s
  write s-addr, in
  var result/edx: int <- copy 0
  {
    var done?/eax: boolean <- stream-empty? s-addr
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme s-addr
    compare g, 0xa/newline
    break-if-=
    result <- increment
    loop
  }
  return result
}

fn fill-in _out: (addr array screen-cell), in: (addr array byte) {
  var s: (stream byte 0x100)
  var out/edi: (addr array screen-cell) <- copy _out
  var s-addr/esi: (addr stream byte) <- address s
  write s-addr, in
  var idx/ecx: int <- copy 0
  {
    var done?/eax: boolean <- stream-empty? s-addr
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme s-addr
    compare g, 0xa/newline
    loop-if-=
    var offset/edx: (offset screen-cell) <- compute-offset out, idx
    var dest/edx: (addr screen-cell) <- index out, offset
    var dest2/edx: (addr grapheme) <- get dest, data
    copy-to *dest2, g
    idx <- increment
    loop
  }
}

# pin (1, 1) to (1, 1) on screen
fn test-surface-pin-at-origin {
  var s: surface
  var s-addr/esi: (addr surface) <- address s
  # surface contents are a fixed grid with 8 rows and 6 columns
  # (strip vowels second time around to break vertical alignment of letters)
  initialize-surface-with-fake-screen s-addr, 3, 4, "abcdef\nghijkl\nmnopqr\nstuvwx\nyzabcd\nfghjkl\nmnpqrs\ntvwxyz"
  pin-surface-at s-addr, 1, 1  # surface row and column
  pin-surface-to s-addr, 1, 1  # screen row and column
  render-surface s-addr
  var screen-ah/eax: (addr handle screen) <- get s-addr, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  check-screen-row screen-addr, 1, "abcd", "F - test-surface-pin-at-origin"
  check-screen-row screen-addr, 2, "ghij", "F - test-surface-pin-at-origin"
  check-screen-row screen-addr, 3, "mnop", "F - test-surface-pin-at-origin"
}

# pin (1, 1) to (2, 1) on screen; screen goes past edge of the universe
fn test-surface-pin-2 {
  var s: surface
  var s-addr/esi: (addr surface) <- address s
  # surface contents are a fixed grid with 8 rows and 6 columns
  # (strip vowels second time around to break vertical alignment of letters)
  initialize-surface-with-fake-screen s-addr, 3, 4, "abcdef\nghijkl\nmnopqr\nstuvwx\nyzabcd\nfghjkl\nmnpqrs\ntvwxyz"
  pin-surface-at s-addr, 1, 1  # surface row and column
  pin-surface-to s-addr, 2, 1  # screen row and column
  render-surface s-addr
  var screen-ah/eax: (addr handle screen) <- get s-addr, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  # surface edge reached (should seldom happen in the app)
  check-screen-row screen-addr, 1, "    ", "F - test-surface-pin-2"
  check-screen-row screen-addr, 2, "abcd", "F - test-surface-pin-2"
  check-screen-row screen-addr, 3, "ghij", "F - test-surface-pin-2"
}

# pin (2, 1) to (1, 1) on screen
fn test-surface-pin-3 {
  var s: surface
  var s-addr/esi: (addr surface) <- address s
  # surface contents are a fixed grid with 8 rows and 6 columns
  # (strip vowels second time around to break vertical alignment of letters)
  initialize-surface-with-fake-screen s-addr, 3, 4, "abcdef\nghijkl\nmnopqr\nstuvwx\nyzabcd\nfghjkl\nmnpqrs\ntvwxyz"
  pin-surface-at s-addr, 2, 1  # surface row and column
  pin-surface-to s-addr, 1, 1  # screen row and column
  render-surface s-addr
  var screen-ah/eax: (addr handle screen) <- get s-addr, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  check-screen-row screen-addr, 1, "ghij", "F - test-surface-pin-3"
  check-screen-row screen-addr, 2, "mnop", "F - test-surface-pin-3"
  check-screen-row screen-addr, 3, "stuv", "F - test-surface-pin-3"
}

# pin (1, 1) to (1, 2) on screen; screen goes past edge of the universe
fn test-surface-pin-4 {
  var s: surface
  var s-addr/esi: (addr surface) <- address s
  # surface contents are a fixed grid with 8 rows and 6 columns
  # (strip vowels second time around to break vertical alignment of letters)
  initialize-surface-with-fake-screen s-addr, 3, 4, "abcdef\nghijkl\nmnopqr\nstuvwx\nyzabcd\nfghjkl\nmnpqrs\ntvwxyz"
  pin-surface-at s-addr, 1, 1  # surface row and column
  pin-surface-to s-addr, 1, 2  # screen row and column
  render-surface s-addr
  var screen-ah/eax: (addr handle screen) <- get s-addr, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  # surface edge reached (should seldom happen in the app)
  check-screen-row screen-addr, 1, " abc", "F - test-surface-pin-4"
  check-screen-row screen-addr, 2, " ghi", "F - test-surface-pin-4"
  check-screen-row screen-addr, 3, " mno", "F - test-surface-pin-4"
}

# pin (1, 2) to (1, 1) on screen
fn test-surface-pin-5 {
  var s: surface
  var s-addr/esi: (addr surface) <- address s
  # surface contents are a fixed grid with 8 rows and 6 columns
  # (strip vowels second time around to break vertical alignment of letters)
  initialize-surface-with-fake-screen s-addr, 3, 4, "abcdef\nghijkl\nmnopqr\nstuvwx\nyzabcd\nfghjkl\nmnpqrs\ntvwxyz"
  pin-surface-at s-addr, 1, 2  # surface row and column
  pin-surface-to s-addr, 1, 1  # screen row and column
  render-surface s-addr
  var screen-ah/eax: (addr handle screen) <- get s-addr, screen
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  check-screen-row screen-addr, 1, "bcde", "F - test-surface-pin-5"
  check-screen-row screen-addr, 2, "hijk", "F - test-surface-pin-5"
  check-screen-row screen-addr, 3, "nopq", "F - test-surface-pin-5"
}

fn initialize-surface-with-fake-screen _self: (addr surface), nrows: int, ncols: int, in: (addr array byte) {
  var self/esi: (addr surface) <- copy _self
  # fill in screen
  var screen-ah/eax: (addr handle screen) <- get self, screen
  allocate screen-ah
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  initialize-screen screen-addr, nrows, ncols
  # fill in everything else
  initialize-surface-with self, in
}

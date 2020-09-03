# Wrappers for real screen primitives that can be passed a fake screen.
# There are no tests here, but commented scenarios are painstakingly validated
# against a real terminal emulator. I believe functionality here is broadly
# portable across terminal emulators.
#
# Remember: fake screen co-ordinates are 1-based, just like in real terminal
# emulators.

type screen {
  num-rows: int
  num-cols: int
  data: (handle array screen-cell)
  top-index: int
  cursor-row: int
  cursor-col: int
  cursor-hide?: boolean
  curr-attributes: screen-cell
}

type screen-cell {
  data: grapheme
  color: int
  background-color: int
  bold?: boolean
  underline?: boolean
  reverse?: boolean
  blink?: boolean
}

fn initialize-screen screen: (addr screen), nrows: int, ncols: int {
  var screen-addr/esi: (addr screen) <- copy screen
  var tmp/eax: int <- copy 0
  var dest/edi: (addr int) <- copy 0
  # screen->num-rows = nrows
  dest <- get screen-addr, num-rows
  tmp <- copy nrows
  copy-to *dest, tmp
  # screen->num-cols = ncols
  dest <- get screen-addr, num-cols
  tmp <- copy ncols
  copy-to *dest, tmp
  # screen->data = new screen-cell[nrows*ncols]
  {
    var data-addr/edi: (addr handle array screen-cell) <- get screen-addr, data
    tmp <- multiply nrows
    populate data-addr, tmp
  }
  # screen->cursor-row = 1
  dest <- get screen-addr, cursor-row
  copy-to *dest, 1
  # screen->cursor-col = 1
  dest <- get screen-addr, cursor-col
  copy-to *dest, 1
  # screen->curr-attributes->background-color = 7  (simulate light background)
  var tmp2/eax: (addr screen-cell) <- get screen-addr, curr-attributes
  dest <- get tmp2, background-color
  copy-to *dest, 7
}

fn screen-size screen: (addr screen) -> nrows/eax: int, ncols/ecx: int {
$screen-size:body: {
  compare screen, 0
  {
    break-if-!=
    nrows, ncols <- real-screen-size
    break $screen-size:body
  }
  {
    break-if-=
    # fake screen
    var screen-addr/esi: (addr screen) <- copy screen
    var tmp/edx: (addr int) <- get screen-addr, num-rows
    nrows <- copy *tmp
    tmp <- get screen-addr, num-cols
    ncols <- copy *tmp
  }
}
}

fn clear-screen screen: (addr screen) {
$clear-screen:body: {
  compare screen, 0
  {
    break-if-!=
    clear-real-screen
    break $clear-screen:body
  }
  {
    break-if-=
    # fake screen
    var space/edi: grapheme <- copy 0x20
    move-cursor screen, 1, 1
    var screen-addr/esi: (addr screen) <- copy screen
    var i/eax: int <- copy 1
    var nrows/ecx: (addr int) <- get screen-addr, num-rows
    {
      compare i, *nrows
      break-if->
      var j/edx: int <- copy 1
      var ncols/ebx: (addr int) <- get screen-addr, num-cols
      {
        compare j, *ncols
        break-if->
        print-grapheme screen, space
        j <- increment
        loop
      }
      i <- increment
      loop
    }
    move-cursor screen, 1, 1
  }
}
}

fn move-cursor screen: (addr screen), row: int, column: int {
$move-cursor:body: {
  compare screen, 0
  {
    break-if-!=
    move-cursor-on-real-screen row, column
    break $move-cursor:body
  }
  {
    break-if-=
    # fake screen
    var screen-addr/esi: (addr screen) <- copy screen
    # row < 0 is ignored
    {
      compare row, 0
      break-if-< $move-cursor:body
    }
    # row = 0 is treated same as 1
    {
      compare row, 0
      break-if-!=
      copy-to row, 1
    }
    # row > num-rows saturates to num-rows
    {
      var nrows-addr/eax: (addr int) <- get screen-addr, num-rows
      var nrows/eax: int <- copy *nrows-addr
      compare row, nrows
      break-if-<=
      copy-to row, nrows
    }
    # column < 0 is ignored
    {
      compare column, 0
      break-if-< $move-cursor:body
    }
    # column = 0 is treated same as 1
    {
      compare column, 0
      break-if-!=
      copy-to column, 1
    }
    # column > num-cols saturates to num-cols+1 (so wrapping to next row)
    {
      var ncols-addr/eax: (addr int) <- get screen-addr, num-cols
      var ncols/eax: int <- copy *ncols-addr
      compare column, ncols
      break-if-<=
      copy-to column, ncols
      increment column
    }
    # screen->cursor-row = row
    var dest/edi: (addr int) <- get screen-addr, cursor-row
    var src/eax: int <- copy row
    copy-to *dest, src
    # screen->cursor-col = column
    dest <- get screen-addr, cursor-col
    src <- copy column
    copy-to *dest, src
  }
}
}

fn print-string screen: (addr screen), s: (addr array byte) {
$print-string:body: {
  compare screen, 0
  {
    break-if-!=
    print-string-to-real-screen s
    break $print-string:body
  }
  {
    break-if-=
    # fake screen
    var s2: (stream byte 0x100)
    var s2-addr/esi: (addr stream byte) <- address s2
    write s2-addr, s
    var screen-addr/edi: (addr screen) <- copy screen
    {
      var done?/eax: boolean <- stream-empty? s2-addr
      compare done?, 0
      break-if-!=
      var idx/ecx: int <- current-screen-cell-index screen-addr
      var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
      var data/eax: (addr array screen-cell) <- lookup *data-ah
      var offset/ecx: (offset screen-cell) <- compute-offset data, idx
      var cell/eax: (addr screen-cell) <- index data, offset
      var dest/ecx: (addr grapheme) <- get cell, data
      var g/eax: grapheme <- read-grapheme s2-addr
      copy-to *dest, g
      var cursor-col-addr/ecx: (addr int) <- get screen-addr, cursor-col
      increment *cursor-col-addr
      loop
    }
  }
}
}

fn print-grapheme screen: (addr screen), c: grapheme {
$print-grapheme:body: {
  compare screen, 0
  {
    break-if-!=
    print-grapheme-to-real-screen c
    break $print-grapheme:body
  }
  {
    break-if-=
    # fake screen
    var screen-addr/esi: (addr screen) <- copy screen
    var idx/ecx: int <- current-screen-cell-index screen-addr
    var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
    var data/eax: (addr array screen-cell) <- lookup *data-ah
    var offset/ecx: (offset screen-cell) <- compute-offset data, idx
    var cell/eax: (addr screen-cell) <- index data, offset
    var dest/eax: (addr grapheme) <- get cell, data
    var c2/ecx: grapheme <- copy c
    copy-to *dest, c2
  }
}
}

fn current-screen-cell-index screen-on-stack: (addr screen) -> result/ecx: int {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var cursor-row-addr/ecx: (addr int) <- get screen, cursor-row
  var cursor-col-addr/eax: (addr int) <- get screen, cursor-col
  result <- screen-cell-index screen, *cursor-row-addr, *cursor-col-addr
}

fn screen-cell-index screen-on-stack: (addr screen), row: int, col: int -> result/ecx: int {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var num-cols-addr/eax: (addr int) <- get screen, num-cols
  var num-cols/eax: int <- copy *num-cols-addr
  result <- copy row
  result <- subtract 1
  result <- multiply num-cols
  result <- add col
  result <- subtract 1
}

fn screen-grapheme-at screen-on-stack: (addr screen), row: int, col: int -> result/eax: grapheme {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  result <- screen-grapheme-at-idx screen-addr, idx
}

fn screen-grapheme-at-idx screen-on-stack: (addr screen), idx-on-stack: int -> result/eax: grapheme {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr grapheme) <- get cell, data
  result <- copy *src
}

fn print-code-point screen: (addr screen), c: code-point {
  var g/eax: grapheme <- to-grapheme c
  print-grapheme screen, g
}

fn print-int32-hex screen: (addr screen), n: int {
$print-int32-hex:body: {
  compare screen, 0
  {
    break-if-!=
    print-int32-hex-to-real-screen n
    break $print-int32-hex:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn reset-formatting screen: (addr screen) {
$reset-formatting:body: {
  compare screen, 0
  {
    break-if-!=
    reset-formatting-on-real-screen
    break $reset-formatting:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn start-color screen: (addr screen), fg: int, bg: int {
$start-color:body: {
  compare screen, 0
  {
    break-if-!=
    start-color-on-real-screen fg, bg
    break $start-color:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn start-bold screen: (addr screen) {
$start-bold:body: {
  compare screen, 0
  {
    break-if-!=
    start-bold-on-real-screen
    break $start-bold:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn start-underline screen: (addr screen) {
$start-underline:body: {
  compare screen, 0
  {
    break-if-!=
    start-underline-on-real-screen
    break $start-underline:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn start-reverse-video screen: (addr screen) {
$start-reverse-video:body: {
  compare screen, 0
  {
    break-if-!=
    start-reverse-video-on-real-screen
    break $start-reverse-video:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn start-blinking screen: (addr screen) {
$start-blinking:body: {
  compare screen, 0
  {
    break-if-!=
    start-blinking-on-real-screen
    break $start-blinking:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn hide-cursor screen: (addr screen) {
$hide-cursor:body: {
  compare screen, 0
  {
    break-if-!=
    hide-cursor-on-real-screen
    break $hide-cursor:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

fn show-cursor screen: (addr screen) {
$show-cursor:body: {
  compare screen, 0
  {
    break-if-!=
    show-cursor-on-real-screen
    break $show-cursor:body
  }
  {
    break-if-=
    # fake screen
  }
}
}

# validate data on screen regardless of attributes (color, bold, etc.)
# Mu doesn't have multi-line strings, so we provide functions for rows or portions of rows.

fn check-screen-row screen-on-stack: (addr screen), row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, 1
  # compare 'expected' with the screen contents starting at 'idx', grapheme by grapheme
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var g/eax: grapheme <- screen-grapheme-at-idx screen, idx
    var g2/ebx: int <- copy g
    var expected-grapheme/eax: grapheme <- read-grapheme e-addr
    var expected-grapheme2/eax: int <- copy expected-grapheme
    check-ints-equal g2, expected-grapheme2, msg
    idx <- increment
    loop
  }
}

fn check-screen-row-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte) {
}

# various variants by screen-cell attribute; spaces in the 'expected' data should not match the attribute

fn check-screen-row-in-color screen-on-stack: (addr screen), fg: color, row-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-color-from screen-on-stack: (addr screen), fg: color, row-idx: int, col-idx: int, expected: (addr array byte) {
}

# background color is visible even for spaces, so 'expected' behaves as an array of booleans.
# non-space = given background must match; space = background must not match
fn check-screen-row-in-background-color screen-on-stack: (addr screen), fg: color, row-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-background-color-from screen-on-stack: (addr screen), fg: color, row-idx: int, col-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-bold screen-on-stack: (addr screen), row-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-bold-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-underline screen-on-stack: (addr screen), row-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-underline-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-reverse screen-on-stack: (addr screen), row-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-reverse-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-blinking screen-on-stack: (addr screen), row-idx: int, expected: (addr array byte) {
}

fn check-screen-row-in-blinking-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte) {
}

fn test-print-single-grapheme {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  var c/eax: grapheme <- copy 0x61  # 'a'
  print-grapheme screen, c
  check-screen-row screen, 1, "a", "F - test-print-single-grapheme"  # top-left corner of the screen
}

fn test-print-multiple-graphemes {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  print-string screen, "Hello, 世界"
  check-screen-row screen, 1, "Hello, 世界", "F - test-print-multiple-graphemes"  # top-left corner of the screen
}

#? fn main -> exit-status/ebx: int {
#?   test-print-single-grapheme
#?   test-print-multiple-graphemes
#?   exit-status <- copy 0
#? }

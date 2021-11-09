# Wrappers for real screen primitives that can be passed a fake screen.
# The tests here have been painstakingly validated against a real terminal
# emulator. I believe functionality here is broadly portable across terminal
# emulators.
#
# Remember: fake screen co-ordinates are 1-based, just like in real terminal
# emulators.

type screen {
  num-rows: int
  num-cols: int
  data: (handle array screen-cell)
  top-index: int  # 0-indexed
  cursor-row: int  # 1-indexed
  cursor-col: int  # 1-indexed
  cursor-hide?: boolean
  curr-attributes: screen-cell
}

type screen-cell {
  data: code-point-utf8
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

fn screen-size screen: (addr screen) -> _/eax: int, _/ecx: int {
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  compare screen, 0
  {
    break-if-!=
    nrows, ncols <- real-screen-size
    return nrows, ncols
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var tmp/edx: (addr int) <- get screen-addr, num-rows
  nrows <- copy *tmp
  tmp <- get screen-addr, num-cols
  ncols <- copy *tmp
  return nrows, ncols
}

fn clear-screen screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    clear-real-screen
    return
  }
  # fake screen
  var space/edi: code-point-utf8 <- copy 0x20
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
      print-code-point-utf8 screen, space
      j <- increment
      loop
    }
    i <- increment
    loop
  }
  move-cursor screen, 1, 1
}

fn move-cursor screen: (addr screen), row: int, column: int {
  compare screen, 0
  {
    break-if-!=
    move-cursor-on-real-screen row, column
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  # row < 0 is ignored
  {
    compare row, 0
    break-if->=
    return
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
    break-if->=
    return
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

fn print-string screen: (addr screen), s: (addr array byte) {
  compare screen, 0
  {
    break-if-!=
    print-string-to-real-screen s
    return
  }
  # fake screen
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, s
  print-stream screen, stream
}

fn print-stream _screen: (addr screen), s: (addr stream byte) {
  var screen/edi: (addr screen) <- copy _screen
  {
    var done?/eax: boolean <- stream-empty? s
    compare done?, 0
    break-if-!=
    var g/eax: code-point-utf8 <- read-code-point-utf8 s
    print-code-point-utf8 screen, g
    loop
  }
}

fn print-array-of-ints-in-decimal screen: (addr screen), _a: (addr array int) {
  var a/esi: (addr array int) <- copy _a
  var max/ecx: int <- length a
  var i/eax: int <- copy 0
  {
    compare i, max
    break-if->=
    {
      compare i, 0
      break-if-=
      print-string screen, " "
    }
    var x/ecx: (addr int) <- index a, i
    print-int32-decimal screen, *x
    i <- increment
    loop
  }
}

fn print-code-point-utf8 screen: (addr screen), c: code-point-utf8 {
  compare screen, 0
  {
    break-if-!=
    print-code-point-utf8-to-real-screen c
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var cursor-col-addr/edx: (addr int) <- get screen-addr, cursor-col
  # adjust cursor if necessary
  # to avoid premature scrolling it's important to do this lazily, at the last possible time
  {
    # next row
    var num-cols-addr/ecx: (addr int) <- get screen-addr, num-cols
    var num-cols/ecx: int <- copy *num-cols-addr
    compare *cursor-col-addr, num-cols
    break-if-<=
    copy-to *cursor-col-addr, 1
    var cursor-row-addr/ebx: (addr int) <- get screen-addr, cursor-row
    increment *cursor-row-addr
    # scroll
    var num-rows-addr/eax: (addr int) <- get screen-addr, num-rows
    var num-rows/eax: int <- copy *num-rows-addr
    compare *cursor-row-addr, num-rows
    break-if-<=
    copy-to *cursor-row-addr, num-rows
    # if (top-index > data size) top-index = 0, otherwise top-index += num-cols
    $print-code-point-utf8:perform-scroll: {
      var top-index-addr/ebx: (addr int) <- get screen-addr, top-index
      var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
      var data/eax: (addr array screen-cell) <- lookup *data-ah
      var max-index/edi: int <- length data
      compare *top-index-addr, max-index
      {
        break-if->=
        add-to *top-index-addr, num-cols
        break $print-code-point-utf8:perform-scroll
      }
      {
        break-if-<
        copy-to *top-index-addr, 0
      }
    }
  }
  var idx/ecx: int <- current-screen-cell-index screen-addr
#?   print-string-to-real-screen "printing code-point-utf8 at screen index "
#?   print-int32-hex-to-real-screen idx
#?   print-string-to-real-screen ": "
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var dest-cell/ecx: (addr screen-cell) <- index data, offset
  var src-cell/eax: (addr screen-cell) <- get screen-addr, curr-attributes
  copy-object src-cell, dest-cell
  var dest/eax: (addr code-point-utf8) <- get dest-cell, data
  var c2/ecx: code-point-utf8 <- copy c
#?   print-code-point-utf8-to-real-screen c2
#?   print-string-to-real-screen "\n"
  copy-to *dest, c2
  increment *cursor-col-addr
}

fn current-screen-cell-index screen-on-stack: (addr screen) -> _/ecx: int {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var cursor-row-addr/ecx: (addr int) <- get screen, cursor-row
  var cursor-col-addr/eax: (addr int) <- get screen, cursor-col
  var result/ecx: int <- screen-cell-index screen, *cursor-row-addr, *cursor-col-addr
  return result
}

fn screen-cell-index screen-on-stack: (addr screen), row: int, col: int -> _/ecx: int {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var num-cols-addr/eax: (addr int) <- get screen, num-cols
  var num-cols/eax: int <- copy *num-cols-addr
  var result/ecx: int <- copy row
  result <- subtract 1
  result <- multiply num-cols
  result <- add col
  result <- subtract 1
  # result = (result + top-index) % data length
  var top-index-addr/eax: (addr int) <- get screen, top-index
  result <- add *top-index-addr
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var max-index/eax: int <- length data
  compare result, max-index
  {
    break-if-<
    result <- subtract max-index
  }
  return result
}

fn screen-code-point-utf8-at screen-on-stack: (addr screen), row: int, col: int -> _/eax: code-point-utf8 {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen-addr, idx
  return result
}

fn screen-code-point-utf8-at-idx screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: code-point-utf8 {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr code-point-utf8) <- get cell, data
  return *src
}

fn screen-color-at screen-on-stack: (addr screen), row: int, col: int -> _/eax: int {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: int <- screen-color-at-idx screen-addr, idx
  return result
}

fn screen-color-at-idx screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: int {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, color
  var result/eax: int <- copy *src
  return result
}

fn screen-background-color-at screen-on-stack: (addr screen), row: int, col: int -> _/eax: int {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: int <- screen-background-color-at-idx screen-addr, idx
  return result
}

fn screen-background-color-at-idx screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: int {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, background-color
  return *src
}

fn screen-bold-at? screen-on-stack: (addr screen), row: int, col: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: boolean <- screen-bold-at-idx? screen-addr, idx
  return result
}

fn screen-bold-at-idx? screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr boolean) <- get cell, bold?
  return *src
}

fn screen-underline-at? screen-on-stack: (addr screen), row: int, col: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: boolean <- screen-underline-at-idx? screen-addr, idx
  return result
}

fn screen-underline-at-idx? screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr boolean) <- get cell, underline?
  return *src
}

fn screen-reverse-at? screen-on-stack: (addr screen), row: int, col: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: boolean <- screen-reverse-at-idx? screen-addr, idx
  return result
}

fn screen-reverse-at-idx? screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr boolean) <- get cell, reverse?
  return *src
}

fn screen-blink-at? screen-on-stack: (addr screen), row: int, col: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, row, col
  var result/eax: boolean <- screen-blink-at-idx? screen-addr, idx
  return result
}

fn screen-blink-at-idx? screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: boolean {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr boolean) <- get cell, blink?
  return *src
}

fn print-code-point screen: (addr screen), c: code-point {
  var g/eax: code-point-utf8 <- to-utf8 c
  print-code-point-utf8 screen, g
}

fn print-int32-hex screen: (addr screen), n: int {
  compare screen, 0
  {
    break-if-!=
    print-int32-hex-to-real-screen n
    return
  }
  # fake screen
  var s2: (stream byte 0x100)
  var s2-addr/esi: (addr stream byte) <- address s2
  write-int32-hex s2-addr, n
  var screen-addr/edi: (addr screen) <- copy screen
  {
    var done?/eax: boolean <- stream-empty? s2-addr
    compare done?, 0
    break-if-!=
    var g/eax: code-point-utf8 <- read-code-point-utf8 s2-addr
    print-code-point-utf8 screen, g
    loop
  }
}

fn print-int32-hex-bits screen: (addr screen), n: int, bits: int {
  compare screen, 0
  {
    break-if-!=
    print-int32-hex-bits-to-real-screen n, bits
    return
  }
  # fake screen
  var s2: (stream byte 0x100)
  var s2-addr/esi: (addr stream byte) <- address s2
  write-int32-hex-bits s2-addr, n, bits
  var screen-addr/edi: (addr screen) <- copy screen
  {
    var done?/eax: boolean <- stream-empty? s2-addr
    compare done?, 0
    break-if-!=
    var g/eax: code-point-utf8 <- read-code-point-utf8 s2-addr
    print-code-point-utf8 screen, g
    loop
  }
}

fn print-int32-decimal screen: (addr screen), n: int {
  compare screen, 0
  {
    break-if-!=
    print-int32-decimal-to-real-screen n
    return
  }
  # fake screen
  var s2: (stream byte 0x100)
  var s2-addr/esi: (addr stream byte) <- address s2
  write-int32-decimal s2-addr, n
  var screen-addr/edi: (addr screen) <- copy screen
  {
    var done?/eax: boolean <- stream-empty? s2-addr
    compare done?, 0
    break-if-!=
    var g/eax: code-point-utf8 <- read-code-point-utf8 s2-addr
    print-code-point-utf8 screen, g
    loop
  }
}

fn reset-formatting screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    reset-formatting-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var dest/ecx: (addr screen-cell) <- get screen-addr, curr-attributes
  var default-cell: screen-cell
  var bg/eax: (addr int) <- get default-cell, background-color
  copy-to *bg, 7
  var default-cell-addr/eax: (addr screen-cell) <- address default-cell
  copy-object default-cell-addr, dest
}

fn start-color screen: (addr screen), fg: int, bg: int {
  compare screen, 0
  {
    break-if-!=
    start-color-on-real-screen fg, bg
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var attr/ecx: (addr screen-cell) <- get screen-addr, curr-attributes
  var dest/edx: (addr int) <- get attr, color
  var src/eax: int <- copy fg
  copy-to *dest, src
  var dest/edx: (addr int) <- get attr, background-color
  var src/eax: int <- copy bg
  copy-to *dest, src
}

fn start-bold screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    start-bold-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var attr/ecx: (addr screen-cell) <- get screen-addr, curr-attributes
  var dest/edx: (addr boolean) <- get attr, bold?
  copy-to *dest, 1
}

fn start-underline screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    start-underline-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var attr/ecx: (addr screen-cell) <- get screen-addr, curr-attributes
  var dest/edx: (addr boolean) <- get attr, underline?
  copy-to *dest, 1
}

fn start-reverse-video screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    start-reverse-video-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var attr/ecx: (addr screen-cell) <- get screen-addr, curr-attributes
  var dest/edx: (addr boolean) <- get attr, reverse?
  copy-to *dest, 1
}

fn start-blinking screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    start-blinking-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var attr/ecx: (addr screen-cell) <- get screen-addr, curr-attributes
  var dest/edx: (addr boolean) <- get attr, blink?
  copy-to *dest, 1
}

fn hide-cursor screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    hide-cursor-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var hide?/ecx: (addr boolean) <- get screen-addr, cursor-hide?
  copy-to *hide?, 1
}

fn show-cursor screen: (addr screen) {
  compare screen, 0
  {
    break-if-!=
    show-cursor-on-real-screen
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var hide?/ecx: (addr boolean) <- get screen-addr, cursor-hide?
  copy-to *hide?, 0
}

# validate data on screen regardless of attributes (color, bold, etc.)
# Mu doesn't have multi-line strings, so we provide functions for rows or portions of rows.
# Tab characters (that translate into multiple screen cells) not supported.

fn check-screen-row screen: (addr screen), row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-from screen, row-idx, 1, expected, msg
}

fn check-screen-row-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    # compare code-point-utf8s
    $check-screen-row-from:compare-code-point-utf8s: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-from:compare-code-point-utf8s
      }
      # if (g == expected-code-point-utf8) print "."
      compare g, expected-code-point-utf8
      {
        break-if-!=
        print-string-to-real-screen "."
        break $check-screen-row-from:compare-code-point-utf8s
      }
      # otherwise print an error
      print-string-to-real-screen msg
      print-string-to-real-screen ": expected '"
      print-code-point-utf8-to-real-screen expected-code-point-utf8
      print-string-to-real-screen "' at ("
      print-int32-hex-to-real-screen row-idx
      print-string-to-real-screen ", "
      print-int32-hex-to-real-screen col-idx
      print-string-to-real-screen ") but observed '"
      print-code-point-utf8-to-real-screen g
      print-string-to-real-screen "'\n"
    }
    idx <- increment
    increment col-idx
    loop
  }
}

# various variants by screen-cell attribute; spaces in the 'expected' data should not match the attribute

fn check-screen-row-in-color screen: (addr screen), fg: int, row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-color-from screen, fg, row-idx, 1, expected, msg
}

fn check-screen-row-in-color-from screen-on-stack: (addr screen), fg: int, row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var _expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    var expected-code-point-utf8/edi: code-point-utf8 <- copy _expected-code-point-utf8
    $check-screen-row-in-color-from:compare-cells: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-color-from:compare-cells
      }
      # if expected-code-point-utf8 is space, a different color is ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        var color/eax: int <- screen-color-at-idx screen, idx
        compare color, fg
        break-if-!= $check-screen-row-in-color-from:compare-cells
      }
      # compare code-point-utf8s
      $check-screen-row-in-color-from:compare-code-point-utf8s: {
        # if (g == expected-code-point-utf8) print "."
        compare g, expected-code-point-utf8
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-color-from:compare-code-point-utf8s
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") but observed '"
        print-code-point-utf8-to-real-screen g
        print-string-to-real-screen "'\n"
      }
      $check-screen-row-in-color-from:compare-colors: {
        var color/eax: int <- screen-color-at-idx screen, idx
        compare fg, color
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-color-from:compare-colors
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") in color "
        print-int32-hex-to-real-screen fg
        print-string-to-real-screen " but observed color "
        print-int32-hex-to-real-screen color
        print-string-to-real-screen "\n"
      }
    }
    idx <- increment
    increment col-idx
    loop
  }
}

# background color is visible even for spaces, so 'expected' behaves as an array of booleans.
# non-space = given background must match; space = background must not match
fn check-screen-row-in-background-color screen: (addr screen), bg: int, row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-background-color-from screen, bg, row-idx, 1, expected, msg
}

fn check-screen-row-in-background-color-from screen-on-stack: (addr screen), bg: int, row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var _expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    var expected-code-point-utf8/edx: code-point-utf8 <- copy _expected-code-point-utf8
    $check-screen-row-in-background-color-from:compare-cells: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-background-color-from:compare-cells
      }
      # if expected-code-point-utf8 is space, a different color is ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        var color/eax: int <- screen-background-color-at-idx screen, idx
        compare color, bg
        break-if-!= $check-screen-row-in-background-color-from:compare-cells
      }
      # compare code-point-utf8s
      $check-screen-row-in-background-color-from:compare-code-point-utf8s: {
        # if (g == expected-code-point-utf8) print "."
        compare g, expected-code-point-utf8
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-background-color-from:compare-code-point-utf8s
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") but observed '"
        print-code-point-utf8-to-real-screen g
        print-string-to-real-screen "'\n"
      }
      $check-screen-row-in-background-color-from:compare-colors: {
        var color/eax: int <- screen-background-color-at-idx screen, idx
        compare bg, color
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-background-color-from:compare-colors
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") in background color "
        print-int32-hex-to-real-screen bg
        print-string-to-real-screen " but observed color "
        print-int32-hex-to-real-screen color
        print-string-to-real-screen "\n"
      }
    }
    idx <- increment
    increment col-idx
    loop
  }
}

fn check-screen-row-in-bold screen: (addr screen), row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-bold-from screen, row-idx, 1, expected, msg
}

fn check-screen-row-in-bold-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var _expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    var expected-code-point-utf8/edx: code-point-utf8 <- copy _expected-code-point-utf8
    $check-screen-row-in-bold-from:compare-cells: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-bold-from:compare-cells
      }
      # if expected-code-point-utf8 is space, non-bold is ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        var bold?/eax: boolean <- screen-bold-at-idx? screen, idx
        compare bold?, 1
        break-if-!= $check-screen-row-in-bold-from:compare-cells
      }
      # compare code-point-utf8s
      $check-screen-row-in-bold-from:compare-code-point-utf8s: {
        # if (g == expected-code-point-utf8) print "."
        compare g, expected-code-point-utf8
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-bold-from:compare-code-point-utf8s
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") but observed '"
        print-code-point-utf8-to-real-screen g
        print-string-to-real-screen "'\n"
      }
      $check-screen-row-in-bold-from:compare-bold: {
        var bold?/eax: boolean <- screen-bold-at-idx? screen, idx
        compare bold?, 1
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-bold-from:compare-bold
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") to be in bold\n"
      }
    }
    idx <- increment
    increment col-idx
    loop
  }
}

fn check-screen-row-in-underline screen: (addr screen), row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-underline-from screen, row-idx, 1, expected, msg
}

fn check-screen-row-in-underline-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var _expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    var expected-code-point-utf8/edx: code-point-utf8 <- copy _expected-code-point-utf8
    $check-screen-row-in-underline-from:compare-cells: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-underline-from:compare-cells
      }
      # if expected-code-point-utf8 is space, non-underline is ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        var underline?/eax: boolean <- screen-underline-at-idx? screen, idx
        compare underline?, 1
        break-if-!= $check-screen-row-in-underline-from:compare-cells
      }
      # compare code-point-utf8s
      $check-screen-row-in-underline-from:compare-code-point-utf8s: {
        # if (g == expected-code-point-utf8) print "."
        compare g, expected-code-point-utf8
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-underline-from:compare-code-point-utf8s
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") but observed '"
        print-code-point-utf8-to-real-screen g
        print-string-to-real-screen "'\n"
      }
      $check-screen-row-in-underline-from:compare-underline: {
        var underline?/eax: boolean <- screen-underline-at-idx? screen, idx
        compare underline?, 1
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-underline-from:compare-underline
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") to be underlined\n"
      }
    }
    idx <- increment
    increment col-idx
    loop
  }
}

fn check-screen-row-in-reverse screen: (addr screen), row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-reverse-from screen, row-idx, 1, expected, msg
}

fn check-screen-row-in-reverse-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var _expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    var expected-code-point-utf8/edx: code-point-utf8 <- copy _expected-code-point-utf8
    $check-screen-row-in-reverse-from:compare-cells: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-reverse-from:compare-cells
      }
      # if expected-code-point-utf8 is space, non-reverse is ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        var reverse?/eax: boolean <- screen-reverse-at-idx? screen, idx
        compare reverse?, 1
        break-if-!= $check-screen-row-in-reverse-from:compare-cells
      }
      # compare code-point-utf8s
      $check-screen-row-in-reverse-from:compare-code-point-utf8s: {
        # if (g == expected-code-point-utf8) print "."
        compare g, expected-code-point-utf8
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-reverse-from:compare-code-point-utf8s
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") but observed '"
        print-code-point-utf8-to-real-screen g
        print-string-to-real-screen "'\n"
      }
      $check-screen-row-in-reverse-from:compare-reverse: {
        var reverse?/eax: boolean <- screen-reverse-at-idx? screen, idx
        compare reverse?, 1
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-reverse-from:compare-reverse
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") to be in reverse-video\n"
      }
    }
    idx <- increment
    increment col-idx
    loop
  }
}

fn check-screen-row-in-blinking screen: (addr screen), row-idx: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-blinking-from screen, row-idx, 1, expected, msg
}

fn check-screen-row-in-blinking-from screen-on-stack: (addr screen), row-idx: int, col-idx: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, row-idx, col-idx
  # compare 'expected' with the screen contents starting at 'idx', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: code-point-utf8 <- screen-code-point-utf8-at-idx screen, idx
    var g/ebx: code-point-utf8 <- copy _g
    var _expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
    var expected-code-point-utf8/edx: code-point-utf8 <- copy _expected-code-point-utf8
    $check-screen-row-in-blinking-from:compare-cells: {
      # if expected-code-point-utf8 is space, null code-point-utf8 is also ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-blinking-from:compare-cells
      }
      # if expected-code-point-utf8 is space, non-blinking is ok
      {
        compare expected-code-point-utf8, 0x20
        break-if-!=
        var blinking?/eax: boolean <- screen-blink-at-idx? screen, idx
        compare blinking?, 1
        break-if-!= $check-screen-row-in-blinking-from:compare-cells
      }
      # compare code-point-utf8s
      $check-screen-row-in-blinking-from:compare-code-point-utf8s: {
        # if (g == expected-code-point-utf8) print "."
        compare g, expected-code-point-utf8
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-blinking-from:compare-code-point-utf8s
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") but observed '"
        print-code-point-utf8-to-real-screen g
        print-string-to-real-screen "'\n"
      }
      $check-screen-row-in-blinking-from:compare-blinking: {
        var blinking?/eax: boolean <- screen-blink-at-idx? screen, idx
        compare blinking?, 1
        {
          break-if-!=
          print-string-to-real-screen "."
          break $check-screen-row-in-blinking-from:compare-blinking
        }
        # otherwise print an error
        print-string-to-real-screen msg
        print-string-to-real-screen ": expected '"
        print-code-point-utf8-to-real-screen expected-code-point-utf8
        print-string-to-real-screen "' at ("
        print-int32-hex-to-real-screen row-idx
        print-string-to-real-screen ", "
        print-int32-hex-to-real-screen col-idx
        print-string-to-real-screen ") to be blinking\n"
      }
    }
    idx <- increment
    increment col-idx

    loop
  }
}

fn test-print-single-code-point-utf8 {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row screen, 1/row, "a", "F - test-print-single-code-point-utf8"  # top-left corner of the screen
}

fn test-print-multiple-code-point-utf8s {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  print-string screen, "Hello, 世界"
  check-screen-row screen, 1/row, "Hello, 世界", "F - test-print-multiple-code-point-utf8s"
}

fn test-move-cursor {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  move-cursor screen, 1, 4
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row screen, 1/row, "   a", "F - test-move-cursor"  # top row
}

fn test-move-cursor-zeroes {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  move-cursor screen, 0, 0
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row screen, 1/row, "a", "F - test-move-cursor-zeroes"  # top-left corner of the screen
}

fn test-move-cursor-zero-row {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  move-cursor screen, 0, 2
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row screen, 1/row, " a", "F - test-move-cursor-zero-row"  # top row
}

fn test-move-cursor-zero-column {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  move-cursor screen, 4, 0
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row screen, 4/row, "a", "F - test-move-cursor-zero-column"
}

fn test-move-cursor-negative-row {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 3
  move-cursor screen, -1/row, 2/col
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  # no move
  check-screen-row screen, 1/row, "a", "F - test-move-cursor-negative-row"
}

fn test-move-cursor-negative-column {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 3
  move-cursor screen, 2/row, -1/col
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  # no move
  check-screen-row screen, 1/row, "a", "F - test-move-cursor-negative-column"
}

fn test-move-cursor-column-too-large {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 3/cols
  move-cursor screen, 1/row, 4/col
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  # top row is empty
  check-screen-row screen, 1/row, "   ", "F - test-move-cursor-column-too-large"
  # character shows up on next row
  check-screen-row screen, 2/row, "a", "F - test-move-cursor-column-too-large"
}

fn test-move-cursor-column-too-large-saturates {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 3/cols
  move-cursor screen, 1/row, 6/col
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  # top row is empty
  check-screen-row screen, 1/row, "   ", "F - test-move-cursor-column-too-large-saturates"  # top-left corner of the screen
  # character shows up at the start of next row
  check-screen-row screen, 2/row, "a", "F - test-move-cursor-column-too-large-saturates"  # top-left corner of the screen
}

fn test-move-cursor-row-too-large {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 3/cols
  move-cursor screen, 6/row, 2/col
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  # bottom row shows the character
  check-screen-row screen, 5/row, " a", "F - test-move-cursor-row-too-large"
}

fn test-move-cursor-row-too-large-saturates {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 3/cols
  move-cursor screen, 9/row, 2/col
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  # bottom row shows the character
  check-screen-row screen, 5/row, " a", "F - test-move-cursor-row-too-large-saturates"
}

fn test-check-screen-row-from {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  move-cursor screen, 1, 4
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row screen, 1/row, "   a", "F - test-check-screen-row-from/baseline"
  check-screen-row-from screen, 1/row, 4/col, "a", "F - test-check-screen-row-from"
}

fn test-print-string-overflows-to-next-row {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  print-string screen, "abcdefg"
  check-screen-row screen, 1/row, "abcd", "F - test-print-string-overflows-to-next-row"
  check-screen-row screen, 2/row, "efg", "F - test-print-string-overflows-to-next-row"
}

fn test-check-screen-scrolls-on-overflow {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  # single character starting at bottom right
  move-cursor screen, 5/rows, 4/cols
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  check-screen-row-from screen, 5/row, 4/col, "a", "F - test-check-screen-scrolls-on-overflow/baseline"  # bottom-right corner of the screen
  # multiple characters starting at bottom right
  move-cursor screen, 5, 4
  print-string screen, "ab"
  # screen scrolled up one row
#?   check-screen-row screen, 1/row, "    ", "F - test-check-screen-scrolls-on-overflow/x1"
#?   check-screen-row screen, 2/row, "    ", "F - test-check-screen-scrolls-on-overflow/x2"
#?   check-screen-row screen, 3/row, "    ", "F - test-check-screen-scrolls-on-overflow/x3"
#?   check-screen-row screen, 4/row, "   a", "F - test-check-screen-scrolls-on-overflow/x4"
#?   check-screen-row screen, 5/row, "b   ", "F - test-check-screen-scrolls-on-overflow/x5"
  check-screen-row-from screen, 4/row, 4/col, "a", "F - test-check-screen-scrolls-on-overflow/1"
  check-screen-row-from screen, 5/row, 1/col, "b", "F - test-check-screen-scrolls-on-overflow/2"
}

fn test-check-screen-color {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  start-color screen, 1/fg, 0/bg
  c <- copy 0x62/b
  print-code-point-utf8 screen, c
  start-color screen, 0/fg, 7/bg
  c <- copy 0x63/c
  print-code-point-utf8 screen, c
  check-screen-row-in-color screen, 0/fg, 1/row, "a c", "F - test-check-screen-color"
}

fn test-check-screen-background-color {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  start-color screen, 0/fg, 1/bg
  c <- copy 0x62/b
  print-code-point-utf8 screen, c
  start-color screen, 0/fg, 7/bg
  c <- copy 0x63/c
  print-code-point-utf8 screen, c
  check-screen-row-in-background-color screen, 7/bg, 1/row, "a c", "F - test-check-screen-background-color"
}

fn test-check-screen-bold {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  start-bold screen
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  reset-formatting screen
  c <- copy 0x62/b
  print-code-point-utf8 screen, c
  start-bold screen
  c <- copy 0x63/c
  print-code-point-utf8 screen, c
  check-screen-row-in-bold screen, 1/row, "a c", "F - test-check-screen-bold"
}

fn test-check-screen-underline {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  start-underline screen
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  reset-formatting screen
  c <- copy 0x62/b
  print-code-point-utf8 screen, c
  start-underline screen
  c <- copy 0x63/c
  print-code-point-utf8 screen, c
  check-screen-row-in-underline screen, 1/row, "a c", "F - test-check-screen-underline"
}

fn test-check-screen-reverse {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  start-reverse-video screen
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  reset-formatting screen
  c <- copy 0x62/b
  print-code-point-utf8 screen, c
  start-reverse-video screen
  c <- copy 0x63/c
  print-code-point-utf8 screen, c
  check-screen-row-in-reverse screen, 1/row, "a c", "F - test-check-screen-reverse"
}

fn test-check-screen-blinking {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/rows, 4/cols
  start-blinking screen
  var c/eax: code-point-utf8 <- copy 0x61/a
  print-code-point-utf8 screen, c
  reset-formatting screen
  c <- copy 0x62/b
  print-code-point-utf8 screen, c
  start-blinking screen
  c <- copy 0x63/c
  print-code-point-utf8 screen, c
  check-screen-row-in-blinking screen, 1/row, "a c", "F - test-check-screen-blinking"
}

#? fn main -> _/ebx: int {
#? #?   test-check-screen-color
#?   run-tests
#?   return 0
#? }

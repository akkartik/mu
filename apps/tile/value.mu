fn render-value-at screen: (addr screen), row: int, col: int, _val: (addr value), top-level?: boolean {
  move-cursor screen, row, col
  var val/esi: (addr value) <- copy _val
  var val-type/ecx: (addr int) <- get val, type
  # per-type rendering logic goes here
  compare *val-type, 1/string
  {
    break-if-!=
    var val-ah/eax: (addr handle array byte) <- get val, text-data
    var val-string/eax: (addr array byte) <- lookup *val-ah
    compare val-string, 0
    break-if-=
    var orig-len/ecx: int <- length val-string
    var truncated: (handle array byte)
    var truncated-ah/esi: (addr handle array byte) <- address truncated
    substring val-string, 0, 0xc, truncated-ah
    var truncated-string/eax: (addr array byte) <- lookup *truncated-ah
    var len/edx: int <- length truncated-string
    start-color screen, 0xf2, 7
    print-code-point screen, 0x275d/open-quote
    print-string screen, truncated-string
    compare len, orig-len
    {
      break-if-=
      print-code-point screen, 0x2026/ellipses
    }
    print-code-point screen, 0x275e/close-quote
    reset-formatting screen
    return
  }
  compare *val-type, 2/array
  {
    break-if-!=
    var val-ah/eax: (addr handle array value) <- get val, array-data
    var val-array/eax: (addr array value) <- lookup *val-ah
    render-array-at screen, row, col, val-array
    return
  }
  compare *val-type, 3/file
  {
    break-if-!=
    var val-ah/eax: (addr handle buffered-file) <- get val, file-data
    var val-file/eax: (addr buffered-file) <- lookup *val-ah
    start-color screen, 0, 7
    # TODO
    print-string screen, " FILE "
    return
  }
  compare *val-type, 4/screen
  {
    break-if-!=
#?     print-string 0, "render-screen"
    var val-ah/eax: (addr handle screen) <- get val, screen-data
    var val-screen/eax: (addr screen) <- lookup *val-ah
    render-screen screen, row, col, val-screen
#?     print-string 0, "}\n"
    return
  }
  # render ints by default for now
  var val-num/eax: (addr float) <- get val, number-data
  render-number screen, *val-num, top-level?
}

# synaesthesia
# TODO: right-justify
fn render-number screen: (addr screen), val: float, top-level?: boolean {
  # if we're inside an array, don't color
  compare top-level?, 0
  {
    break-if-!=
    print-float-decimal-approximate screen, val, 3
    return
  }
  var val-int/eax: int <- convert val
  var bg/eax: int <- hash-color val-int
  var fg/ecx: int <- copy 7
  {
    compare bg, 2
    break-if-!=
    fg <- copy 0
  }
  {
    compare bg, 3
    break-if-!=
    fg <- copy 0
  }
  {
    compare bg, 6
    break-if-!=
    fg <- copy 0
  }
  start-color screen, fg, bg
  print-grapheme screen, 0x20/space
  print-float-decimal-approximate screen, val, 3
  print-grapheme screen, 0x20/space
}

fn render-array-at screen: (addr screen), row: int, col: int, _a: (addr array value) {
  start-color screen, 0xf2, 7
  # don't surround in spaces
  print-grapheme screen, 0x5b/[
  increment col
  var a/esi: (addr array value) <- copy _a
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
    var off/ecx: (offset value) <- compute-offset a, i
    var x/ecx: (addr value) <- index a, off
    render-value-at screen, row, col, x, 0
    {
      var w/eax: int <- value-width x, 0
      add-to col, w
      increment col
    }
    i <- increment
    loop
  }
  print-grapheme screen, 0x5d/]
}

fn render-screen screen: (addr screen), row: int, col: int, _target-screen: (addr screen) {
  reset-formatting screen
  move-cursor screen, row, col
  var target-screen/esi: (addr screen) <- copy _target-screen
  var ncols-a/ecx: (addr int) <- get target-screen, num-cols
  print-upper-border screen, *ncols-a
  var r/edx: int <- copy 1
  var nrows-a/ebx: (addr int) <- get target-screen, num-rows
  {
    compare r, *nrows-a
    break-if->
    increment row  # mutate arg
    move-cursor screen, row, col
    print-string screen, " "
    var c/edi: int <- copy 1
    {
      compare c, *ncols-a
      break-if->
      print-screen-cell-of-fake-screen screen, target-screen, r, c
      c <- increment
      loop
    }
    print-string screen, " "
    r <- increment
    loop
  }
  increment row  # mutate arg
  move-cursor screen, row, col
  print-lower-border screen, *ncols-a
}

fn hash-color val: int -> _/eax: int {
  var quotient/eax: int <- copy 0
  var remainder/edx: int <- copy 0
  quotient, remainder <- integer-divide val, 7  # assumes that 7 is always the background color
  return remainder
}

fn print-screen-cell-of-fake-screen screen: (addr screen), _target: (addr screen), _row: int, _col: int {
  start-color screen, 0, 0xf6
  var target/esi: (addr screen) <- copy _target
  var row/ecx: int <- copy _row
  var col/edx: int <- copy _col
  # if cursor is at screen-cell, add some fancy
  {
    var cursor-row/eax: (addr int) <- get target, cursor-row
    compare *cursor-row, row
    break-if-!=
    var cursor-col/eax: (addr int) <- get target, cursor-col
    compare *cursor-col, col
    break-if-!=
    start-blinking screen
    start-color screen, 0, 1
  }
  var g/eax: grapheme <- screen-grapheme-at target, row, col
  {
    compare g, 0
    break-if-!=
    g <- copy 0x20/space
  }
  print-grapheme screen, g
  reset-formatting screen
}

fn print-upper-border screen: (addr screen), width: int {
  print-code-point screen, 0x250c/top-left-corner
  var i/eax: int <- copy 0
  {
    compare i, width
    break-if->=
    print-code-point screen, 0x2500/horizontal-line
    i <- increment
    loop
  }
  print-code-point screen, 0x2510/top-right-corner
}

fn print-lower-border screen: (addr screen), width: int {
  print-code-point screen, 0x2514/bottom-left-corner
  var i/eax: int <- copy 0
  {
    compare i, width
    break-if->=
    print-code-point screen, 0x2500/horizontal-line
    i <- increment
    loop
  }
  print-code-point screen, 0x2518/bottom-right-corner
}

fn value-width _v: (addr value), top-level: boolean -> _/eax: int {
  var v/esi: (addr value) <- copy _v
  var type/eax: (addr int) <- get v, type
  {
    compare *type, 0/int
    break-if-!=
    var v-num/edx: (addr float) <- get v, number-data
    var result/eax: int <- float-size *v-num, 3
    return result
  }
  {
    compare *type, 1/string
    break-if-!=
    var s-ah/eax: (addr handle array byte) <- get v, text-data
    var s/eax: (addr array byte) <- lookup *s-ah
    compare s, 0
    break-if-=
    var result/eax: int <- length s
    compare result, 0xd/max-string-size
    {
      break-if-<=
      result <- copy 0xd
    }
    # if it's a nested string, include space for quotes
    # we don't do this for the top-level, where the quotes will overflow
    # into surrounding padding.
    compare top-level, 0/false
    {
      break-if-!=
      result <- add 2
    }
    return result
  }
  {
    compare *type, 2/array
    break-if-!=
    var a-ah/eax: (addr handle array value) <- get v, array-data
    var a/eax: (addr array value) <- lookup *a-ah
    compare a, 0
    break-if-=
    var result/eax: int <- array-width a
    return result
  }
  {
    compare *type, 3/file
    break-if-!=
    var f-ah/eax: (addr handle buffered-file) <- get v, file-data
    var f/eax: (addr buffered-file) <- lookup *f-ah
    compare f, 0
    break-if-=
    # TODO: visualizing file handles
    return 4
  }
  {
    compare *type, 4/screen
    break-if-!=
    var screen-ah/eax: (addr handle screen) <- get v, screen-data
    var screen/eax: (addr screen) <- lookup *screen-ah
    compare screen, 0
    break-if-=
    var ncols/ecx: (addr int) <- get screen, num-cols
    var result/eax: int <- copy *ncols
    result <- add 2  # left/right margins
    return *ncols
  }
  return 0
}

# keep sync'd with render-array-at
fn array-width _a: (addr array value) -> _/eax: int {
  var a/esi: (addr array value) <- copy _a
  var max/ecx: int <- length a
  var i/eax: int <- copy 0
  var result/edi: int <- copy 0
  {
    compare i, max
    break-if->=
    {
      compare i, 0
      break-if-=
      result <- increment  # for space
    }
    var off/ecx: (offset value) <- compute-offset a, i
    var x/ecx: (addr value) <- index a, off
    {
      var w/eax: int <- value-width x, 0
      result <- add w
    }
    i <- increment
    loop
  }
  # we won't add 2 for surrounding brackets since we don't surround arrays in
  # spaces like other value types
  return result
}

fn value-height _v: (addr value) -> _/eax: int {
  var v/esi: (addr value) <- copy _v
  var type/eax: (addr int) <- get v, type
  {
    compare *type, 3/file
    break-if-!=
    # TODO: visualizing file handles
    return 1
  }
  {
    compare *type, 4/screen
    break-if-!=
    var screen-ah/eax: (addr handle screen) <- get v, screen-data
    var screen/eax: (addr screen) <- lookup *screen-ah
    compare screen, 0
    break-if-=
    var nrows/ecx: (addr int) <- get screen, num-rows
    var result/eax: int <- copy *nrows
    result <- add 2  # top and bottom border
    return result
  }
  return 1
}

fn deep-copy-value _src: (addr value), _dest: (addr value) {
#?   print-string 0, "deep-copy-value\n"
  var src/esi: (addr value) <- copy _src
  var dest/edi: (addr value) <- copy _dest
  var type/ebx: (addr int) <- get src, type
  var y/ecx: (addr int) <- get dest, type
  copy-object type, y
  compare *type, 0   # int
  {
    break-if-!=
#?     print-string 0, "int value\n"
    var src-n/eax: (addr float) <- get src, number-data
    var dest-n/ecx: (addr float) <- get dest, number-data
    copy-object src-n, dest-n
    return
  }
  compare *type, 1/string
  {
    break-if-!=
#?     print-string 0, "string value\n"
    var src-ah/eax: (addr handle array byte) <- get src, text-data
    var src/eax: (addr array byte) <- lookup *src-ah
    var dest-ah/edx: (addr handle array byte) <- get dest, text-data
    copy-array-object src, dest-ah
    return
  }
  compare *type, 2/array
  {
    break-if-!=
#?     print-string 0, "array value\n"
    var src-ah/eax: (addr handle array value) <- get src, array-data
    var _src/eax: (addr array value) <- lookup *src-ah
    var src/esi: (addr array value) <- copy _src
    var n/ecx: int <- length src
    var dest-ah/edx: (addr handle array value) <- get dest, array-data
    populate dest-ah, n
    var _dest/eax: (addr array value) <- lookup *dest-ah
    var dest/edi: (addr array value) <- copy _dest
    var i/eax: int <- copy 0
    {
      compare i, n
      break-if->=
      {
        var offset/edx: (offset value) <- compute-offset src, i
        var src-element/eax: (addr value) <- index src, offset
        var dest-element/ecx: (addr value) <- index dest, offset
        deep-copy-value src-element, dest-element
      }
      i <- increment
      loop
    }
    copy-array-object src, dest-ah
    return
  }
  compare *type, 3/file
  {
    break-if-!=
#?     print-string 0, "file value\n"
    var src-filename-ah/eax: (addr handle array byte) <- get src, filename
    var _src-filename/eax: (addr array byte) <- lookup *src-filename-ah
    var src-filename/ecx: (addr array byte) <- copy _src-filename
    var dest-filename-ah/ebx: (addr handle array byte) <- get dest, filename
    copy-array-object src-filename, dest-filename-ah
    var src-file-ah/eax: (addr handle buffered-file) <- get src, file-data
    var src-file/eax: (addr buffered-file) <- lookup *src-file-ah
    var dest-file-ah/edx: (addr handle buffered-file) <- get dest, file-data
    copy-file src-file, dest-file-ah, src-filename
    return
  }
  compare *type, 4/screen
  {
    break-if-!=
#?     print-string 0, "screen value\n"
    var src-screen-ah/eax: (addr handle screen) <- get src, screen-data
    var _src-screen/eax: (addr screen) <- lookup *src-screen-ah
    var src-screen/ecx: (addr screen) <- copy _src-screen
    var dest-screen-ah/eax: (addr handle screen) <- get dest, screen-data
    allocate dest-screen-ah
    var dest-screen/eax: (addr screen) <- lookup *dest-screen-ah
    copy-object src-screen, dest-screen
    var dest-screen-data-ah/ebx: (addr handle array screen-cell) <- get dest-screen, data
    var src-screen-data-ah/eax: (addr handle array screen-cell) <- get src-screen, data
    var src-screen-data/eax: (addr array screen-cell) <- lookup *src-screen-data-ah
    copy-array-object src-screen-data, dest-screen-data-ah
    return
  }
}

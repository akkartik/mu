# Some primitives for checking the state of fake screen objects.

# validate data on screen regardless of attributes (color, bold, etc.)
# Mu doesn't have multi-line strings, so we provide functions for rows or portions of rows.
# Tab characters (that translate into multiple screen cells) not supported.

fn check-screen-row screen: (addr screen), y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-from screen, y, 0/row, expected, msg
}

fn check-screen-row-from screen-on-stack: (addr screen), x: int, y: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, y, x
  # compare 'expected' with the screen contents starting at 'idx', grapheme by grapheme
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: grapheme <- screen-grapheme-at-idx screen, idx
    var g/ebx: grapheme <- copy _g
    var expected-grapheme/eax: grapheme <- read-grapheme e-addr
    # compare graphemes
    $check-screen-row-from:compare-graphemes: {
      # if expected-grapheme is space, null grapheme is also ok
      {
        compare expected-grapheme, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-from:compare-graphemes
      }
      # if (g == expected-grapheme) print "."
      compare g, expected-grapheme
      {
        break-if-!=
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg/cyan, 0/bg
        break $check-screen-row-from:compare-graphemes
      }
      # otherwise print an error
      count-test-failure
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg/cyan, 0/bg
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg/cyan, 0/bg
      draw-grapheme-at-cursor 0/screen, expected-grapheme, 3/cyan, 0/bg
      move-cursor-rightward-and-downward 0/screen, 0/xmin, 0x80/xmax=screen-width
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg/cyan, 0/bg
      draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg/cyan, 0/bg
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg/cyan, 0/bg
      draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg/cyan, 0/bg
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") but observed '", 3/fg/cyan, 0/bg
      draw-grapheme-at-cursor 0/screen, g, 3/cyan, 0/bg
      move-cursor-rightward-and-downward 0/screen, 0/xmin, 0x80/xmax=screen-width
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "'", 3/fg/cyan, 0/bg
    }
    idx <- increment
    increment x
    loop
  }
}

# various variants by screen-cell attribute; spaces in the 'expected' data should not match the attribute

fn check-screen-row-in-color screen: (addr screen), fg: int, y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-color-from screen, fg, y, 0/x, expected, msg
}

fn check-screen-row-in-color-from screen-on-stack: (addr screen), fg: int, y: int, x: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen, y, x
  # compare 'expected' with the screen contents starting at 'idx', grapheme by grapheme
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    var _g/eax: grapheme <- screen-grapheme-at-idx screen, idx
    var g/ebx: grapheme <- copy _g
    var _expected-grapheme/eax: grapheme <- read-grapheme e-addr
    var expected-grapheme/edi: grapheme <- copy _expected-grapheme
    $check-screen-row-in-color-from:compare-cells: {
      # if expected-grapheme is space, null grapheme is also ok
      {
        compare expected-grapheme, 0x20
        break-if-!=
        compare g, 0
        break-if-= $check-screen-row-in-color-from:compare-cells
      }
      # if expected-grapheme is space, a different color is ok
      {
        compare expected-grapheme, 0x20
        break-if-!=
        var color/eax: int <- screen-color-at-idx screen, idx
        compare color, fg
        break-if-!= $check-screen-row-in-color-from:compare-cells
      }
      # compare graphemes
      $check-screen-row-in-color-from:compare-graphemes: {
        # if (g == expected-grapheme) print "."
        compare g, expected-grapheme
        {
          break-if-!=
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg/cyan, 0/bg
          break $check-screen-row-in-color-from:compare-graphemes
        }
        # otherwise print an error
        count-test-failure
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg/cyan, 0/bg
        draw-grapheme-at-cursor 0/screen, expected-grapheme, 3/cyan, 0/bg
        move-cursor-rightward-and-downward 0/screen, 0/xmin, 0x80/xmax=screen-width
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg/cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg/cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") but observed '", 3/fg/cyan, 0/bg
        draw-grapheme-at-cursor 0/screen, g, 3/cyan, 0/bg
        move-cursor-rightward-and-downward 0/screen, 0/xmin, 0x80/xmax=screen-width
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "'", 3/fg/cyan, 0/bg
      }
      $check-screen-row-in-color-from:compare-colors: {
        var color/eax: int <- screen-color-at-idx screen, idx
        compare fg, color
        {
          break-if-!=
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg/cyan, 0/bg
          break $check-screen-row-in-color-from:compare-colors
        }
        # otherwise print an error
        count-test-failure
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg/cyan, 0/bg
        draw-grapheme-at-cursor 0/screen, expected-grapheme, 3/cyan, 0/bg
        move-cursor-rightward-and-downward 0/screen, 0/xmin, 0x80/xmax=screen-width
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg/cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg/cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") in color ", 3/fg/cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, fg, 3/fg/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " but observed color ", 3/fg/cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, color, 3/fg/cyan, 0/bg
      }
    }
    idx <- increment
    increment x
    loop
  }
}

fn test-draw-single-grapheme {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  var c/eax: grapheme <- copy 0x61/a
  draw-grapheme screen, c, 0/x, 0/y, 1/color, 0/bg
  check-screen-row screen, 0/row, "a", "F - test-draw-single-grapheme"  # top-left corner of the screen
}

fn test-draw-multiple-graphemes {
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/rows, 4/cols
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "Hello, 世界", 1/fg, 0/bg
  check-screen-row screen, 0/screen, "Hello, 世界", "F - test-draw-multiple-graphemes"
}

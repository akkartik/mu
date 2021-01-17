# Some primitives for checking the state of fake screen objects.

# validate data on screen regardless of attributes (color, bold, etc.)
# Mu doesn't have multi-line strings, so we provide functions for rows or portions of rows.
# Tab characters (that translate into multiple screen cells) not supported.

fn check-screen-row screen: (addr screen), y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-from screen, y, 1, expected, msg
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
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ".", 3  # 3=cyan
        break $check-screen-row-from:compare-graphemes
      }
      # otherwise print an error
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, msg, 3  # 3=cyan
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ": expected '", 3
      draw-grapheme-at-cursor 0, expected-grapheme, 3
      move-cursor-rightward-and-downward 0, 0, 0x400
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, "' at (", 3
      draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, x, 3
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ", ", 3
      draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, y, 3
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ") but observed '", 3
      draw-grapheme-at-cursor 0, g, 3
      move-cursor-rightward-and-downward 0, 0, 0x400
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, "'", 3
    }
    idx <- increment
    increment x
    loop
  }
}

# various variants by screen-cell attribute; spaces in the 'expected' data should not match the attribute

fn check-screen-row-in-color screen: (addr screen), fg: int, y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-color-from screen, fg, y, 1, expected, msg
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
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ".", 3  # 3=cyan
          break $check-screen-row-in-color-from:compare-graphemes
        }
        # otherwise print an error
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, msg, 3  # 3=cyan
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ": expected '", 3
        draw-grapheme-at-cursor 0, expected-grapheme, 3
        move-cursor-rightward-and-downward 0, 0, 0x400
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, "' at (", 3
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, x, 3
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ", ", 3
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, y, 3
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ") but observed '", 3
        draw-grapheme-at-cursor 0, g, 3
        move-cursor-rightward-and-downward 0, 0, 0x400
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, "'", 3
      }
      $check-screen-row-in-color-from:compare-colors: {
        var color/eax: int <- screen-color-at-idx screen, idx
        compare fg, color
        {
          break-if-!=
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ".", 3  # 3=cyan
          break $check-screen-row-in-color-from:compare-colors
        }
        # otherwise print an error
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, msg, 3  # 3=cyan
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ": expected '", 3
        draw-grapheme-at-cursor 0, expected-grapheme, 3
        move-cursor-rightward-and-downward 0, 0, 0x400
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, "' at (", 3
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, x, 3
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ", ", 3
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, y, 3
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, ") in color ", 3
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, fg, 3
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0, " but observed color ", 3
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0, color, 3
      }
    }
    idx <- increment
    increment x
    loop
  }
}



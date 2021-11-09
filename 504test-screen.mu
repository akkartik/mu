# Some primitives for checking the state of fake screen objects.

# validate data on screen regardless of attributes (color, bold, etc.)
# Mu doesn't have multi-line strings, so we provide functions for rows or portions of rows.
# Tab characters (that translate into multiple screen cells) not supported.

fn check-screen-row screen: (addr screen), y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-from screen, 0/x, y, expected, msg
}

fn check-screen-row-from _screen: (addr screen), x: int, y: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy _screen
  var failure-count/edi: int <- copy 0
  var index/ecx: int <- screen-cell-index screen, x, y
  # compare 'expected' with the screen contents starting at 'index', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    {
      var unused?/eax: boolean <- screen-cell-unused-at-index? screen, index
      compare unused?, 0/false
      break-if-!=
      var _c/eax: code-point <- screen-code-point-at-index screen, index
      var c/ebx: code-point <- copy _c
      var expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
      var expected-code-point/eax: code-point <- to-code-point expected-code-point-utf8
      # compare code-point-utf8s
      $check-screen-row-from:compare-code-point-utf8s: {
        # if expected-code-point is space, null code-point-utf8 is also ok
        {
          compare expected-code-point, 0x20
          break-if-!=
          compare c, 0
          break-if-= $check-screen-row-from:compare-code-point-utf8s
        }
        # if (c == expected-code-point) print "."
        compare c, expected-code-point
        break-if-=
        # otherwise print an error
        failure-count <- increment
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg=cyan, 0/bg
        draw-code-point-at-cursor-over-full-screen 0/screen, expected-code-point, 3/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg=cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") but observed '", 3/fg=cyan, 0/bg
        draw-code-point-at-cursor-over-full-screen 0/screen, c, 3/cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "'", 3/fg=cyan, 0/bg
        move-cursor-to-left-margin-of-next-line 0/screen
      }
    }
    index <- increment
    increment x
    loop
  }
  # if any assertions failed, count the test as failed
  compare failure-count, 0
  {
    break-if-=
    count-test-failure
    return
  }
  # otherwise print a "."
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

# various variants by screen-cell attribute; spaces in the 'expected' data should not match the attribute

fn check-screen-row-in-color screen: (addr screen), fg: int, y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-color-from screen, fg, y, 0/x, expected, msg
}

fn check-screen-row-in-color-from _screen: (addr screen), fg: int, y: int, x: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy _screen
  var index/ecx: int <- screen-cell-index screen, x, y
  # compare 'expected' with the screen contents starting at 'index', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    {
      var unused?/eax: boolean <- screen-cell-unused-at-index? screen, index
      compare unused?, 0/false
      break-if-!=
      var _c/eax: code-point <- screen-code-point-at-index screen, index
      var c/ebx: code-point <- copy _c
      var expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
      var _expected-code-point/eax: code-point <- to-code-point expected-code-point-utf8
      var expected-code-point/edi: code-point <- copy _expected-code-point
      $check-screen-row-in-color-from:compare-cells: {
        # if expected-code-point is space, null code-point-utf8 is also ok
        {
          compare expected-code-point, 0x20
          break-if-!=
          compare c, 0
          break-if-= $check-screen-row-in-color-from:compare-cells
        }
        # if expected-code-point is space, a different color is ok
        {
          compare expected-code-point, 0x20
          break-if-!=
          var color/eax: int <- screen-color-at-index screen, index
          compare color, fg
          break-if-!= $check-screen-row-in-color-from:compare-cells
        }
        # compare code-point-utf8s
        $check-screen-row-in-color-from:compare-code-point-utf8s: {
          # if (c == expected-code-point) print "."
          compare c, expected-code-point
          {
            break-if-!=
            draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
            break $check-screen-row-in-color-from:compare-code-point-utf8s
          }
          # otherwise print an error
          count-test-failure
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg=cyan, 0/bg
          draw-code-point-at-cursor-over-full-screen 0/screen, expected-code-point, 3/cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") but observed '", 3/fg=cyan, 0/bg
          draw-code-point-at-cursor-over-full-screen 0/screen, c, 3/cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "'", 3/fg=cyan, 0/bg
          move-cursor-to-left-margin-of-next-line 0/screen
        }
        $check-screen-row-in-color-from:compare-colors: {
          var color/eax: int <- screen-color-at-index screen, index
          compare fg, color
          {
            break-if-!=
            draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
            break $check-screen-row-in-color-from:compare-colors
          }
          # otherwise print an error
          count-test-failure
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg=cyan, 0/bg
          draw-code-point-at-cursor-over-full-screen 0/screen, expected-code-point, 3/cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") in color ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, fg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " but observed color ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, color, 3/fg=cyan, 0/bg
          move-cursor-to-left-margin-of-next-line 0/screen
        }
      }
    }
    index <- increment
    increment x
    loop
  }
}

fn check-screen-row-in-background-color screen: (addr screen), bg: int, y: int, expected: (addr array byte), msg: (addr array byte) {
  check-screen-row-in-background-color-from screen, bg, y, 0/x, expected, msg
}

fn check-screen-row-in-background-color-from _screen: (addr screen), bg: int, y: int, x: int, expected: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy _screen
  var index/ecx: int <- screen-cell-index screen, x, y
  # compare 'expected' with the screen contents starting at 'index', code-point-utf8 by code-point-utf8
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    {
      var unused?/eax: boolean <- screen-cell-unused-at-index? screen, index
      compare unused?, 0/false
      break-if-!=
      var _g/eax: code-point <- screen-code-point-at-index screen, index
      var g/ebx: code-point <- copy _g
      var expected-code-point-utf8/eax: code-point-utf8 <- read-code-point-utf8 e-addr
      var _expected-code-point/eax: code-point <- to-code-point expected-code-point-utf8
      var expected-code-point/edi: code-point <- copy _expected-code-point
      $check-screen-row-in-background-color-from:compare-cells: {
        # if expected-code-point is space, null code-point-utf8 is also ok
        {
          compare expected-code-point, 0x20
          break-if-!=
          compare g, 0
          break-if-= $check-screen-row-in-background-color-from:compare-cells
        }
        # if expected-code-point is space, a different background-color is ok
        {
          compare expected-code-point, 0x20
          break-if-!=
          var background-color/eax: int <- screen-background-color-at-index screen, index
          compare background-color, bg
          break-if-!= $check-screen-row-in-background-color-from:compare-cells
        }
        # compare code-point-utf8s
        $check-screen-row-in-background-color-from:compare-code-point-utf8s: {
          # if (g == expected-code-point) print "."
          compare g, expected-code-point
          {
            break-if-!=
            draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
            break $check-screen-row-in-background-color-from:compare-code-point-utf8s
          }
          # otherwise print an error
          count-test-failure
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg=cyan, 0/bg
          draw-code-point-at-cursor-over-full-screen 0/screen, expected-code-point, 3/cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") but observed '", 3/fg=cyan, 0/bg
          draw-code-point-at-cursor-over-full-screen 0/screen, g, 3/cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "'", 3/fg=cyan, 0/bg
          move-cursor-to-left-margin-of-next-line 0/screen
          break $check-screen-row-in-background-color-from:compare-code-point-utf8s
        }
        $check-screen-row-in-background-color-from:compare-background-colors: {
          var background-color/eax: int <- screen-background-color-at-index screen, index
          compare bg, background-color
          {
            break-if-!=
            draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
            break $check-screen-row-in-background-color-from:compare-background-colors
          }
          # otherwise print an error
          count-test-failure
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected '", 3/fg=cyan, 0/bg
          draw-code-point-at-cursor-over-full-screen 0/screen, expected-code-point, 3/cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "' at (", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") in background-color ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, bg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " but observed background-color ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, background-color, 3/fg=cyan, 0/bg
          move-cursor-to-left-margin-of-next-line 0/screen
        }
      }
    }
    index <- increment
    increment x
    loop
  }
}

# helpers for checking just background color, not screen contents
# these can validate bg for spaces

fn check-background-color-in-screen-row screen: (addr screen), bg: int, y: int, expected-bitmap: (addr array byte), msg: (addr array byte) {
  check-background-color-in-screen-row-from screen, bg, y, 0/x, expected-bitmap, msg
}

fn check-background-color-in-screen-row-from _screen: (addr screen), bg: int, y: int, x: int, expected-bitmap: (addr array byte), msg: (addr array byte) {
  var screen/esi: (addr screen) <- copy _screen
  var failure-count: int
  var index/ecx: int <- screen-cell-index screen, x, y
  # compare background color where 'expected-bitmap' is a non-space
  var e: (stream byte 0x100)
  var e-addr/edx: (addr stream byte) <- address e
  write e-addr, expected-bitmap
  {
    var done?/eax: boolean <- stream-empty? e-addr
    compare done?, 0
    break-if-!=
    {
      var unused?/eax: boolean <- screen-cell-unused-at-index? screen, index
      compare unused?, 0/false
      break-if-!=
      var _expected-bit/eax: code-point-utf8 <- read-code-point-utf8 e-addr
      var expected-bit/edi: code-point-utf8 <- copy _expected-bit
      $check-background-color-in-screen-row-from:compare-cells: {
        var background-color/eax: int <- screen-background-color-at-index screen, index
        # if expected-bit is space, assert that background is NOT bg
        compare expected-bit, 0x20
        {
          break-if-!=
          compare background-color, bg
          break-if-!= $check-background-color-in-screen-row-from:compare-cells
          increment failure-count
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected (", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
          draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") to not be in background-color ", 3/fg=cyan, 0/bg
          draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, bg, 3/fg=cyan, 0/bg
          move-cursor-to-left-margin-of-next-line 0/screen
          break $check-background-color-in-screen-row-from:compare-cells
        }
        # otherwise assert that background IS bg
        compare background-color, bg
        break-if-= $check-background-color-in-screen-row-from:compare-cells
        increment failure-count
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, msg, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ": expected (", 3/fg=cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ", ", 3/fg=cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ") in background-color ", 3/fg=cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, bg, 3/fg=cyan, 0/bg
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " but observed background-color ", 3/fg=cyan, 0/bg
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, background-color, 3/fg=cyan, 0/bg
        move-cursor-to-left-margin-of-next-line 0/screen
      }
    }
    index <- increment
    increment x
    loop
  }
  # if any assertions failed, count the test as failed
  compare failure-count, 0
  {
    break-if-=
    count-test-failure
    return
  }
  # otherwise print a "."
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, ".", 3/fg=cyan, 0/bg
}

fn test-draw-single-code-point-utf8 {
  var _screen: screen
  var screen/esi: (addr screen) <- address _screen
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  var dummy/eax: int <- draw-code-point screen, 0x61/a, 0/x, 0/y, 1/fg, 2/bg
  check-screen-row screen, 0/y, "a", "F - test-draw-single-code-point-utf8"  # top-left corner of the screen
  check-screen-row-in-color screen, 1/fg, 0/y, "a", "F - test-draw-single-code-point-utf8-fg"
  check-screen-row-in-background-color screen, 2/bg, 0/y, "a", "F - test-draw-single-code-point-utf8-bg"
  check-background-color-in-screen-row screen, 2/bg, 0/y, "x ", "F - test-draw-single-code-point-utf8-bg2"
}

fn test-draw-multiple-code-point-utf8s {
  var _screen: screen
  var screen/esi: (addr screen) <- address _screen
  initialize-screen screen, 0x10/rows, 4/cols, 0/no-pixel-graphics
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "Hello, 世界", 1/fg, 2/bg
  check-screen-row screen, 0/y, "Hello, 世界", "F - test-draw-multiple-code-point-utf8s"
  check-screen-row-in-color screen, 1/fg, 0/y, "Hello, 世界", "F - test-draw-multiple-code-point-utf8s-fg"
  check-background-color-in-screen-row screen, 2/bg, 0/y, "xxxxxxxxx ", "F - test-draw-multiple-code-point-utf8s-bg2"
}

# grapheme stacks are the smallest unit of editable text

type grapheme-stack {
  data: (handle array grapheme)
  top: int
}

fn initialize-grapheme-stack _self: (addr grapheme-stack), n: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var d/edi: (addr handle array grapheme) <- get self, data
  populate d, n
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn clear-grapheme-stack _self: (addr grapheme-stack) {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn grapheme-stack-empty? _self: (addr grapheme-stack) -> _/eax: boolean {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn grapheme-stack-length _self: (addr grapheme-stack) -> _/eax: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  return *top
}

fn push-grapheme-stack _self: (addr grapheme-stack), _val: grapheme {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array grapheme) <- get self, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-addr/edx: (addr grapheme) <- index data, top
  var val/eax: grapheme <- copy _val
  copy-to *dest-addr, val
  add-to *top-addr, 1
}

fn pop-grapheme-stack _self: (addr grapheme-stack) -> _/eax: grapheme {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    return -1
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array grapheme) <- get self, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr grapheme) <- index data, top
  return *result-addr
}

fn copy-grapheme-stack _src: (addr grapheme-stack), dest: (addr grapheme-stack) {
  var src/esi: (addr grapheme-stack) <- copy _src
  var data-ah/edi: (addr handle array grapheme) <- get src, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get src, top
  var i/eax: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr grapheme) <- index data, i
    push-grapheme-stack dest, *g
    i <- increment
    loop
  }
}

# dump stack to screen from bottom to top
# hardcoded colors:
#   matching paren
fn render-stack-from-bottom-wrapping-right-then-down screen: (addr screen), _self: (addr grapheme-stack), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, highlight-matching-open-paren?: boolean, open-paren-depth: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var matching-open-paren-index/edx: int <- get-matching-open-paren-index self, highlight-matching-open-paren?, open-paren-depth
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var x/eax: int <- copy _x
  var y/ecx: int <- copy _y
  var top-addr/esi: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    {
      var g/esi: (addr grapheme) <- index data, i
      var fg: int
      {
        var tmp/eax: int <- copy color
        copy-to fg, tmp
      }
      {
        compare i, matching-open-paren-index
        break-if-!=
        copy-to fg, 0xf/highlight
      }
      x, y <- render-grapheme screen, *g, xmin, ymin, xmax, ymax, x, y, fg, background-color
    }
    i <- increment
    loop
  }
  return x, y
}

# helper for small words
fn render-stack-from-bottom screen: (addr screen), self: (addr grapheme-stack), x: int, y: int, highlight-matching-open-paren?: boolean, open-paren-depth: int -> _/eax: int {
  var _width/eax: int <- copy 0
  var _height/ecx: int <- copy 0
  _width, _height <- screen-size screen
  var width/edx: int <- copy _width
  var height/ebx: int <- copy _height
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- render-stack-from-bottom-wrapping-right-then-down screen, self, x, y, width, height, x, y, highlight-matching-open-paren?, open-paren-depth, 3/fg=cyan, 0xc5/bg=blue-bg
  return x2  # y2? yolo
}

# dump stack to screen from top to bottom
# optionally render a 'cursor' with the top grapheme
# hard-coded colors:
#   matching paren
#   cursor
fn render-stack-from-top-wrapping-right-then-down screen: (addr screen), _self: (addr grapheme-stack), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, render-cursor?: boolean, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var matching-close-paren-index/edx: int <- get-matching-close-paren-index self, render-cursor?
  var data-ah/eax: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var x/eax: int <- copy _x
  var y/ecx: int <- copy _y
  var top-addr/ebx: (addr int) <- get self, top
  var i/ebx: int <- copy *top-addr
  i <- decrement
  # if render-cursor?, peel off first iteration
  {
    compare render-cursor?, 0/false
    break-if-=
    compare i, 0
    break-if-<
    var g/esi: (addr grapheme) <- index data, i
    x, y <- render-grapheme screen, *g, xmin, ymin, xmax, ymax, x, y, background-color, color
    i <- decrement
  }
  # remaining iterations
  {
    compare i, 0
    break-if-<
    # highlight matching paren if needed
    var fg: int
    {
      var tmp/eax: int <- copy color
      copy-to fg, tmp
    }
    compare i, matching-close-paren-index
    {
      break-if-!=
      copy-to fg, 0xf/highlight
    }
    #
    var g/esi: (addr grapheme) <- index data, i
    x, y <- render-grapheme screen, *g, xmin, ymin, xmax, ymax, x, y, fg, background-color
    i <- decrement
    loop
  }
  return x, y
}

# helper for small words
fn render-stack-from-top screen: (addr screen), self: (addr grapheme-stack), x: int, y: int, render-cursor?: boolean -> _/eax: int {
  var _width/eax: int <- copy 0
  var _height/ecx: int <- copy 0
  _width, _height <- screen-size screen
  var width/edx: int <- copy _width
  var height/ebx: int <- copy _height
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- render-stack-from-top-wrapping-right-then-down screen, self, x, y, width, height, x, y, render-cursor?, 3/fg=cyan, 0xc5/bg=blue-bg
  return x2  # y2? yolo
}

fn test-render-grapheme-stack {
  # setup: gs = "abc"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 5
  var g/eax: grapheme <- copy 0x61/a
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  g <- copy 0x63/c
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-bottom screen, gs, 0/x, 0/y, 0/no-highlight-matching-open-paren, 0/open-paren-depth
  check-screen-row screen, 0/y, "abc ", "F - test-render-grapheme-stack from bottom"
  check-ints-equal x, 3, "F - test-render-grapheme-stack from bottom: result"
  check-background-color-in-screen-row screen, 3/bg=reverse, 0/y, "   ", "F - test-render-grapheme-stack from bottom: bg"
  #
  var x/eax: int <- render-stack-from-top screen, gs, 0/x, 1/y, 0/cursor=false
  check-screen-row screen, 1/y, "cba ", "F - test-render-grapheme-stack from top without cursor"
  check-ints-equal x, 3, "F - test-render-grapheme-stack from top without cursor: result"
  check-background-color-in-screen-row screen, 3/bg=reverse, 1/y, "   ", "F - test-render-grapheme-stack from top without cursor: bg"
  #
  var x/eax: int <- render-stack-from-top screen, gs, 0/x, 2/y, 1/cursor=true
  check-screen-row screen, 2/y, "cba ", "F - test-render-grapheme-stack from top with cursor"
  check-ints-equal x, 3, "F - test-render-grapheme-stack from top with cursor: result"
  check-background-color-in-screen-row screen, 3/bg=reverse, 2/y, "|   ", "F - test-render-grapheme-stack from top with cursor: bg"
}

fn test-render-grapheme-stack-while-highlighting-matching-close-paren {
  # setup: gs = "(b)"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 5
  var g/eax: grapheme <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-top screen, gs, 0/x, 2/y, 1/cursor=true
  check-screen-row                      screen,               2/y, "(b) ", "F - test-render-grapheme-stack-while-highlighting-matching-close-paren"
  check-background-color-in-screen-row  screen, 3/bg=reverse,  2/y, "|   ", "F - test-render-grapheme-stack-while-highlighting-matching-close-paren: cursor"
  check-screen-row-in-color             screen, 0xf/fg=white, 2/y, "  ) ", "F - test-render-grapheme-stack-while-highlighting-matching-close-paren: matching paren"
}

fn test-render-grapheme-stack-while-highlighting-matching-close-paren-2 {
  # setup: gs = "(a (b)) c"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 0x10
  var g/eax: grapheme <- copy 0x63/c
  push-grapheme-stack gs, g
  g <- copy 0x20/space
  push-grapheme-stack gs, g
  g <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  g <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x20/space
  push-grapheme-stack gs, g
  g <- copy 0x61/a
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-top screen, gs, 0/x, 2/y, 1/cursor=true
  check-screen-row                      screen,               2/y, "(a (b)) c ", "F - test-render-grapheme-stack-while-highlighting-matching-close-paren-2"
  check-background-color-in-screen-row  screen, 3/bg=reverse,  2/y, "|         ", "F - test-render-grapheme-stack-while-highlighting-matching-close-paren-2: cursor"
  check-screen-row-in-color             screen, 0xf/fg=white, 2/y, "      )   ", "F - test-render-grapheme-stack-while-highlighting-matching-close-paren-2: matching paren"
}

fn test-render-grapheme-stack-while-highlighting-matching-open-paren-with-close-paren-at-end {
  # setup: gs = "(b)"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 5
  var g/eax: grapheme <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  g <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-bottom screen, gs, 0/x, 2/y, 1/highlight-matching-open-paren, 1/open-paren-depth
  check-screen-row          screen,               2/y, "(b) ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren-with-close-paren-at-end"
  check-screen-row-in-color screen, 0xf/fg=white, 2/y, "(   ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren-with-close-paren-at-end: matching paren"
}

fn test-render-grapheme-stack-while-highlighting-matching-open-paren-with-close-paren-at-end-2 {
  # setup: gs = "a((b))"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 0x10
  var g/eax: grapheme <- copy 0x61/a
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  g <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  g <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-bottom screen, gs, 0/x, 2/y, 1/highlight-matching-open-paren, 1/open-paren-depth
  check-screen-row          screen,               2/y, "a((b)) ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren-with-close-paren-at-end-2"
  check-screen-row-in-color screen, 0xf/fg=white, 2/y, " (     ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren-with-close-paren-at-end-2: matching paren"
}

fn test-render-grapheme-stack-while-highlighting-matching-open-paren {
  # setup: gs = "(b"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 5
  var g/eax: grapheme <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-bottom screen, gs, 0/x, 2/y, 1/highlight-matching-open-paren, 0/open-paren-depth
  check-screen-row          screen,               2/y, "(b ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren"
  check-screen-row-in-color screen, 0xf/fg=white, 2/y, "(  ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren: matching paren"
}

fn test-render-grapheme-stack-while-highlighting-matching-open-paren-2 {
  # setup: gs = "a((b)"
  var gs-storage: grapheme-stack
  var gs/edi: (addr grapheme-stack) <- address gs-storage
  initialize-grapheme-stack gs, 0x10
  var g/eax: grapheme <- copy 0x61/a
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x28/open-paren
  push-grapheme-stack gs, g
  g <- copy 0x62/b
  push-grapheme-stack gs, g
  g <- copy 0x29/close-paren
  push-grapheme-stack gs, g
  # setup: screen
  var screen-storage: screen
  var screen/esi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-stack-from-bottom screen, gs, 0/x, 2/y, 1/highlight-matching-open-paren, 0/open-paren-depth
  check-screen-row          screen,               2/y, "a((b) ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren-2"
  check-screen-row-in-color screen, 0xf/fg=white, 2/y, " (    ", "F - test-render-grapheme-stack-while-highlighting-matching-open-paren-2: matching paren"
}

# return the index of the matching close-paren of the grapheme at cursor (top of stack)
# or top index if there's no matching close-paren
fn get-matching-close-paren-index _self: (addr grapheme-stack), render-cursor?: boolean -> _/edx: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top-addr/edx: (addr int) <- get self, top
  # if not rendering cursor, return
  compare render-cursor?, 0/false
  {
    break-if-!=
    return *top-addr
  }
  var data-ah/eax: (addr handle array grapheme) <- get self, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var i/ecx: int <- copy *top-addr
  # if stack is empty, return
  compare i, 0
  {
    break-if->
    return *top-addr
  }
  # if cursor is not '(' return
  i <- decrement
  var g/esi: (addr grapheme) <- index data, i
  compare *g, 0x28/open-paren
  {
    break-if-=
    return *top-addr
  }
  # otherwise scan to matching paren
  var paren-count/ebx: int <- copy 1
  i <- decrement
  {
    compare i, 0
    break-if-<
    var g/esi: (addr grapheme) <- index data, i
    compare *g, 0x28/open-paren
    {
      break-if-!=
      paren-count <- increment
    }
    compare *g, 0x29/close-paren
    {
      break-if-!=
      compare paren-count, 1
      {
        break-if-!=
        return i
      }
      paren-count <- decrement
    }
    i <- decrement
    loop
  }
  return *top-addr
}

# return the index of the first open-paren at the given depth
# or top index if there's no matching close-paren
fn get-matching-open-paren-index _self: (addr grapheme-stack), control: boolean, depth: int -> _/edx: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top-addr/edx: (addr int) <- get self, top
  # if not rendering cursor, return
  compare control, 0/false
  {
    break-if-!=
    return *top-addr
  }
  var data-ah/eax: (addr handle array grapheme) <- get self, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var i/ecx: int <- copy *top-addr
  # if stack is empty, return
  compare i, 0
  {
    break-if->
    return *top-addr
  }
  # scan to matching open paren
  var paren-count/ebx: int <- copy 0
  i <- decrement
  {
    compare i, 0
    break-if-<
    var g/esi: (addr grapheme) <- index data, i
    compare *g, 0x29/close-paren
    {
      break-if-!=
      paren-count <- increment
    }
    compare *g, 0x28/open-paren
    {
      break-if-!=
      compare paren-count, depth
      {
        break-if-!=
        return i
      }
      paren-count <- decrement
    }
    i <- decrement
    loop
  }
  return *top-addr
}

# compare from bottom
# beware: modifies 'stream', which must be disposed of after a false result
fn prefix-match? _self: (addr grapheme-stack), s: (addr stream byte) -> _/eax: boolean {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    # if curr != expected, return false
    {
      var curr-a/edx: (addr grapheme) <- index data, i
      var expected/eax: grapheme <- read-grapheme s
      {
        compare expected, *curr-a
        break-if-=
        return 0/false
      }
    }
    i <- increment
    loop
  }
  return 1   # true
}

# compare from bottom
# beware: modifies 'stream', which must be disposed of after a false result
fn suffix-match? _self: (addr grapheme-stack), s: (addr stream byte) -> _/eax: boolean {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/eax: (addr int) <- get self, top
  var i/ebx: int <- copy *top-addr
  i <- decrement
  {
    compare i, 0
    break-if-<
    {
      var curr-a/edx: (addr grapheme) <- index data, i
      var expected/eax: grapheme <- read-grapheme s
      # if curr != expected, return false
      {
        compare expected, *curr-a
        break-if-=
        return 0/false
      }
    }
    i <- decrement
    loop
  }
  return 1   # true
}

fn grapheme-stack-is-decimal-integer? _self: (addr grapheme-stack) -> _/eax: boolean {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/eax: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edx: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  var result/eax: boolean <- copy 1/true
  $grapheme-stack-is-integer?:loop: {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr grapheme) <- index data, i
    result <- decimal-digit? *g
    compare result, 0/false
    break-if-=
    i <- increment
    loop
  }
  return result
}

# grapheme stacks are the smallest unit of editable text
# they are typically rendered horizontally

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
# colors hardcoded
fn render-stack-from-bottom screen: (addr screen), _self: (addr grapheme-stack), x: int, y: int -> _/eax: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/eax: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr grapheme) <- index data, i
    draw-grapheme screen, *g, x, y, 3/fg=cyan, 0/bg
    i <- increment
    increment x  # assume left to right
    loop
  }
  return x
}

# dump stack to screen from top to bottom
# optionally render a 'cursor' with the top grapheme
fn render-stack-from-top screen: (addr screen), _self: (addr grapheme-stack), x: int, y: int, render-cursor?: boolean -> _/eax: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/eax: int <- copy *top-addr
  i <- decrement
  # if render-cursor?, peel off first iteration
  {
    compare render-cursor?, 0/false
    break-if-=
    compare i, 0
    break-if-<
    var g/edx: (addr grapheme) <- index data, i
    draw-grapheme screen, *g, x, y, 3/fg=cyan, 7/bg=cursor
    i <- decrement
    increment x  # assume left to right
  }
  # remaining iterations
  {
    compare i, 0
    break-if-<
    var g/edx: (addr grapheme) <- index data, i
    draw-grapheme screen, *g, x, y, 3/fg=cyan, 0/bg
    i <- decrement
    increment x  # assume left to right
    loop
  }
  return x
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
  var screen-on-stack: screen
  var screen/esi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var x/eax: int <- render-stack-from-bottom screen, gs, 0/x, 0/y
  check-screen-row screen, 0/y, "abc ", "F - test-render-grapheme-stack from bottom"
  check-ints-equal x, 3, "F - test-render-grapheme-stack from bottom: result"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "   ", "F - test-render-grapheme-stack from bottom: bg"
  #
  var x/eax: int <- render-stack-from-top screen, gs, 0/x, 1/y, 0/cursor=false
  check-screen-row screen, 1/y, "cba ", "F - test-render-grapheme-stack from top without cursor"
  check-ints-equal x, 3, "F - test-render-grapheme-stack from top without cursor: result"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "   ", "F - test-render-grapheme-stack from top without cursor: bg"
  #
  var x/eax: int <- render-stack-from-top screen, gs, 0/x, 2/y, 1/cursor=true
  check-screen-row screen, 2/y, "cba ", "F - test-render-grapheme-stack from top with cursor"
  check-ints-equal x, 3, "F - test-render-grapheme-stack from top without cursor: result"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|   ", "F - test-render-grapheme-stack from top with cursor: bg"
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
    result <- is-decimal-digit? *g
    compare result, 0/false
    break-if-=
    i <- increment
    loop
  }
  return result
}

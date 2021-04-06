# primitive for editing text

type gap-buffer {
  left: grapheme-stack
  right: grapheme-stack
  # some fields for scanning incrementally through a gap-buffer
  left-read-index: int
  right-read-index: int
}

fn initialize-gap-buffer _self: (addr gap-buffer), max-word-size: int {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  initialize-grapheme-stack left, max-word-size
  var right/eax: (addr grapheme-stack) <- get self, right
  initialize-grapheme-stack right, max-word-size
}

# just for tests
fn initialize-gap-buffer-with self: (addr gap-buffer), s: (addr array byte) {
  initialize-gap-buffer self, 0x10/max-word-size
  var stream-storage: (stream byte 0x10/max-word-size)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, s
  {
    var done?/eax: boolean <- stream-empty? stream
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme stream
    add-grapheme-at-gap self, g
    loop
  }
}

fn emit-gap-buffer _self: (addr gap-buffer), out: (addr stream byte) {
  var self/esi: (addr gap-buffer) <- copy _self
  clear-stream out
  var left/eax: (addr grapheme-stack) <- get self, left
  emit-stack-from-bottom left, out
  var right/eax: (addr grapheme-stack) <- get self, right
  emit-stack-from-top right, out
}

# dump stack from bottom to top
fn emit-stack-from-bottom _self: (addr grapheme-stack), out: (addr stream byte) {
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
    write-grapheme out, *g
    i <- increment
    loop
  }
}

# dump stack from top to bottom
fn emit-stack-from-top _self: (addr grapheme-stack), out: (addr stream byte) {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/eax: int <- copy *top-addr
  i <- decrement
  {
    compare i, 0
    break-if-<
    var g/edx: (addr grapheme) <- index data, i
    write-grapheme out, *g
    i <- decrement
    loop
  }
}

# We implicitly render everything editable in a single color, and assume the
# cursor is a single other color.
fn render-gap-buffer-wrapping-right-then-down screen: (addr screen), _gap: (addr gap-buffer), xmin: int, ymin: int, xmax: int, ymax: int, render-cursor?: boolean -> _/eax: int, _/ecx: int {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/edx: (addr grapheme-stack) <- get gap, left
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- render-stack-from-bottom-wrapping-right-then-down screen, left, xmin, ymin, xmax, ymax, xmin, ymin
  var right/edx: (addr grapheme-stack) <- get gap, right
  x2, y2 <- render-stack-from-top-wrapping-right-then-down screen, right, xmin, ymin, xmax, ymax, x2, y2, render-cursor?
  # decide whether we still need to print a cursor
  var bg/ebx: int <- copy 0
  compare render-cursor?, 0/false
  {
    break-if-=
    # if the right side is empty, grapheme stack didn't print the cursor
    var empty?/eax: boolean <- grapheme-stack-empty? right
    compare empty?, 0/false
    break-if-=
    bg <- copy 7/cursor
  }
  # print a grapheme either way so that cursor position doesn't affect printed width
  var space/edx: grapheme <- copy 0x20
  x2, y2 <- render-grapheme screen, space, xmin, ymin, xmax, ymax, x2, y2, 3/fg=cyan, bg
  return x2, y2
}

fn render-gap-buffer screen: (addr screen), gap: (addr gap-buffer), x: int, y: int, render-cursor?: boolean -> _/eax: int {
  var _width/eax: int <- copy 0
  var _height/ecx: int <- copy 0
  _width, _height <- screen-size screen
  var width/edx: int <- copy _width
  var height/ebx: int <- copy _height
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- render-gap-buffer-wrapping-right-then-down screen, gap, x, y, width, height, render-cursor?
  return x2  # y2? yolo
}

fn gap-buffer-length _gap: (addr gap-buffer) -> _/eax: int {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/eax: (addr grapheme-stack) <- get gap, left
  var tmp/eax: (addr int) <- get left, top
  var left-length/ecx: int <- copy *tmp
  var right/esi: (addr grapheme-stack) <- get gap, right
  tmp <- get right, top
  var result/eax: int <- copy *tmp
  result <- add left-length
  return result
}

fn add-grapheme-at-gap _self: (addr gap-buffer), g: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  push-grapheme-stack left, g
}

fn gap-to-start self: (addr gap-buffer) {
  {
    var curr/eax: grapheme <- gap-left self
    compare curr, -1
    loop-if-!=
  }
}

fn gap-to-end self: (addr gap-buffer) {
  {
    var curr/eax: grapheme <- gap-right self
    compare curr, -1
    loop-if-!=
  }
}

fn gap-at-start? _self: (addr gap-buffer) -> _/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  var result/eax: boolean <- grapheme-stack-empty? left
  return result
}

fn gap-at-end? _self: (addr gap-buffer) -> _/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  var right/eax: (addr grapheme-stack) <- get self, right
  var result/eax: boolean <- grapheme-stack-empty? right
  return result
}

fn gap-right _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  var g/eax: grapheme <- copy 0
  var right/ecx: (addr grapheme-stack) <- get self, right
  g <- pop-grapheme-stack right
  compare g, -1
  {
    break-if-=
    var left/ecx: (addr grapheme-stack) <- get self, left
    push-grapheme-stack left, g
  }
  return g
}

fn gap-left _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  var g/eax: grapheme <- copy 0
  {
    var left/ecx: (addr grapheme-stack) <- get self, left
    g <- pop-grapheme-stack left
  }
  compare g, -1
  {
    break-if-=
    var right/ecx: (addr grapheme-stack) <- get self, right
    push-grapheme-stack right, g
  }
  return g
}

fn index-of-gap _self: (addr gap-buffer) -> _/eax: int {
  var self/eax: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  var top-addr/eax: (addr int) <- get left, top
  var result/eax: int <- copy *top-addr
  return result
}

fn first-grapheme-in-gap-buffer _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  # try to read from left
  var left/eax: (addr grapheme-stack) <- get self, left
  var top-addr/ecx: (addr int) <- get left, top
  compare *top-addr, 0
  {
    break-if-<=
    var data-ah/eax: (addr handle array grapheme) <- get left, data
    var data/eax: (addr array grapheme) <- lookup *data-ah
    var result-addr/eax: (addr grapheme) <- index data, 0
    return *result-addr
  }
  # try to read from right
  var right/eax: (addr grapheme-stack) <- get self, right
  top-addr <- get right, top
  compare *top-addr, 0
  {
    break-if-<=
    var data-ah/eax: (addr handle array grapheme) <- get right, data
    var data/eax: (addr array grapheme) <- lookup *data-ah
    var top/ecx: int <- copy *top-addr
    top <- decrement
    var result-addr/eax: (addr grapheme) <- index data, top
    return *result-addr
  }
  # give up
  return -1
}

fn grapheme-before-cursor-in-gap-buffer _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  # try to read from left
  var left/ecx: (addr grapheme-stack) <- get self, left
  var top-addr/edx: (addr int) <- get left, top
  compare *top-addr, 0
  {
    break-if-<=
    var result/eax: grapheme <- pop-grapheme-stack left
    push-grapheme-stack left, result
    return result
  }
  # give up
  return -1
}

fn delete-before-gap _self: (addr gap-buffer) {
  var self/eax: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  var dummy/eax: grapheme <- pop-grapheme-stack left
}

fn pop-after-gap _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/eax: (addr gap-buffer) <- copy _self
  var right/eax: (addr grapheme-stack) <- get self, right
  var result/eax: grapheme <- pop-grapheme-stack right
  return result
}

fn gap-buffer-equal? _self: (addr gap-buffer), s: (addr array byte) -> _/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  # complication: graphemes may be multiple bytes
  # so don't rely on length
  # instead turn the expected result into a stream and arrange to read from it in order
  var stream-storage: (stream byte 0x10/max-word-size)
  var expected-stream/ecx: (addr stream byte) <- address stream-storage
  write expected-stream, s
  # compare left
  var left/edx: (addr grapheme-stack) <- get self, left
  var result/eax: boolean <- prefix-match? left, expected-stream
  compare result, 0/false
  {
    break-if-!=
    return result
  }
  # compare right
  var right/edx: (addr grapheme-stack) <- get self, right
  result <- suffix-match? right, expected-stream
  compare result, 0/false
  {
    break-if-!=
    return result
  }
  # ensure there's nothing left over
  result <- stream-empty? expected-stream
  return result
}

fn test-gap-buffer-equal-from-end {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g, 0x10
  #
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  # gap is at end (right is empty)
  var result/eax: boolean <- gap-buffer-equal? g, "aaa"
  check result, "F - test-gap-buffer-equal-from-end"
}

fn test-gap-buffer-equal-from-middle {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g, 0x10
  #
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  var dummy/eax: grapheme <- gap-left g
  # gap is in the middle
  var result/eax: boolean <- gap-buffer-equal? g, "aaa"
  check result, "F - test-gap-buffer-equal-from-middle"
}

fn test-gap-buffer-equal-from-start {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g, 0x10
  #
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  var dummy/eax: grapheme <- gap-left g
  dummy <- gap-left g
  dummy <- gap-left g
  # gap is at the start
  var result/eax: boolean <- gap-buffer-equal? g, "aaa"
  check result, "F - test-gap-buffer-equal-from-start"
}

fn test-gap-buffer-equal-fails {
  # g = "aaa"
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g, 0x10
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  #
  var result/eax: boolean <- gap-buffer-equal? g, "aa"
  check-not result, "F - test-gap-buffer-equal-fails"
}

fn gap-buffers-equal? self: (addr gap-buffer), g: (addr gap-buffer) -> _/eax: boolean {
  var tmp/eax: int <- gap-buffer-length self
  var len/ecx: int <- copy tmp
  var leng/eax: int <- gap-buffer-length g
  compare len, leng
  {
    break-if-=
    return 0/false
  }
  var i/edx: int <- copy 0
  {
    compare i, len
    break-if->=
    {
      var tmp/eax: grapheme <- gap-index self, i
      var curr/ecx: grapheme <- copy tmp
      var currg/eax: grapheme <- gap-index g, i
      compare curr, currg
      break-if-=
      return 0/false
    }
    i <- increment
    loop
  }
  return 1/true
}

fn gap-index _self: (addr gap-buffer), _n: int -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  var n/ebx: int <- copy _n
  # if n < left->length, index into left
  var left/edi: (addr grapheme-stack) <- get self, left
  var left-len-a/edx: (addr int) <- get left, top
  compare n, *left-len-a
  {
    break-if->=
    var data-ah/eax: (addr handle array grapheme) <- get left, data
    var data/eax: (addr array grapheme) <- lookup *data-ah
    var result/eax: (addr grapheme) <- index data, n
    return *result
  }
  # shrink n
  n <- subtract *left-len-a
  # if n < right->length, index into right
  var right/edi: (addr grapheme-stack) <- get self, right
  var right-len-a/edx: (addr int) <- get right, top
  compare n, *right-len-a
  {
    break-if->=
    var data-ah/eax: (addr handle array grapheme) <- get right, data
    var data/eax: (addr array grapheme) <- lookup *data-ah
    # idx = right->len - n - 1
    var idx/ebx: int <- copy n
    idx <- subtract *right-len-a
    idx <- negate
    idx <- subtract 1
    var result/eax: (addr grapheme) <- index data, idx
    return *result
  }
  # error
  abort "gap-index: out of bounds"
  return 0
}

fn test-gap-buffers-equal? {
  var _a: gap-buffer
  var a/esi: (addr gap-buffer) <- address _a
  initialize-gap-buffer-with a, "abc"
  var _b: gap-buffer
  var b/edi: (addr gap-buffer) <- address _b
  initialize-gap-buffer-with b, "abc"
  var _c: gap-buffer
  var c/ebx: (addr gap-buffer) <- address _c
  initialize-gap-buffer-with c, "ab"
  var _d: gap-buffer
  var d/edx: (addr gap-buffer) <- address _d
  initialize-gap-buffer-with d, "abd"
  #
  var result/eax: boolean <- gap-buffers-equal? a, a
  check result, "F - test-gap-buffers-equal? - reflexive"
  result <- gap-buffers-equal? a, b
  check result, "F - test-gap-buffers-equal? - equal"
  # length not equal
  result <- gap-buffers-equal? a, c
  check-not result, "F - test-gap-buffers-equal? - not equal"
  # contents not equal
  result <- gap-buffers-equal? a, d
  check-not result, "F - test-gap-buffers-equal? - not equal 2"
  result <- gap-buffers-equal? d, a
  check-not result, "F - test-gap-buffers-equal? - not equal 3"
}

fn test-gap-buffer-index {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  # gap is at end, all contents are in left
  var g/eax: grapheme <- gap-index gap, 0
  var x/ecx: int <- copy g
  check-ints-equal x, 0x61/a, "F - test-gap-index/left-1"
  var g/eax: grapheme <- gap-index gap, 1
  var x/ecx: int <- copy g
  check-ints-equal x, 0x62/b, "F - test-gap-index/left-2"
  var g/eax: grapheme <- gap-index gap, 2
  var x/ecx: int <- copy g
  check-ints-equal x, 0x63/c, "F - test-gap-index/left-3"
  # now check when everything is to the right
  gap-to-start gap
  rewind-gap-buffer gap
  var g/eax: grapheme <- gap-index gap, 0
  var x/ecx: int <- copy g
  check-ints-equal x, 0x61/a, "F - test-gap-index/right-1"
  var g/eax: grapheme <- gap-index gap, 1
  var x/ecx: int <- copy g
  check-ints-equal x, 0x62/b, "F - test-gap-index/right-2"
  var g/eax: grapheme <- gap-index gap, 2
  var x/ecx: int <- copy g
  check-ints-equal x, 0x63/c, "F - test-gap-index/right-3"
}

fn copy-gap-buffer _src-ah: (addr handle gap-buffer), _dest-ah: (addr handle gap-buffer) {
  # obtain src-a, dest-a
  var src-ah/eax: (addr handle gap-buffer) <- copy _src-ah
  var _src-a/eax: (addr gap-buffer) <- lookup *src-ah
  var src-a/esi: (addr gap-buffer) <- copy _src-a
  var dest-ah/eax: (addr handle gap-buffer) <- copy _dest-ah
  var _dest-a/eax: (addr gap-buffer) <- lookup *dest-ah
  var dest-a/edi: (addr gap-buffer) <- copy _dest-a
  # copy left grapheme-stack
  var src/ecx: (addr grapheme-stack) <- get src-a, left
  var dest/edx: (addr grapheme-stack) <- get dest-a, left
  copy-grapheme-stack src, dest
  # copy right grapheme-stack
  src <- get src-a, right
  dest <- get dest-a, right
  copy-grapheme-stack src, dest
}

fn gap-buffer-is-decimal-integer? _self: (addr gap-buffer) -> _/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  var curr/ecx: (addr grapheme-stack) <- get self, left
  var result/eax: boolean <- grapheme-stack-is-decimal-integer? curr
  {
    compare result, 0/false
    break-if-=
    curr <- get self, right
    result <- grapheme-stack-is-decimal-integer? curr
  }
  return result
}

fn test-render-gap-buffer-without-cursor {
  # setup
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 0/no-cursor
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-without-cursor"
  check-ints-equal x, 4, "F - test-render-gap-buffer-without-cursor: result"
                                                                # abc
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "    ", "F - test-render-gap-buffer-without-cursor: bg"
}

fn test-render-gap-buffer-with-cursor-at-end {
  # setup
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  gap-to-end gap
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-with-cursor-at-end"
  # we've drawn one extra grapheme for the cursor
  check-ints-equal x, 4, "F - test-render-gap-buffer-with-cursor-at-end: result"
                                                                # abc
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "   |", "F - test-render-gap-buffer-with-cursor-at-end: bg"
}

fn test-render-gap-buffer-with-cursor-in-middle {
  # setup
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  gap-to-end gap
  var dummy/eax: grapheme <- gap-left gap
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-with-cursor-in-middle"
  check-ints-equal x, 4, "F - test-render-gap-buffer-with-cursor-in-middle: result"
                                                                # abc
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  | ", "F - test-render-gap-buffer-with-cursor-in-middle: bg"
}

fn test-render-gap-buffer-with-cursor-at-start {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  gap-to-start gap
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-with-cursor-at-start"
  check-ints-equal x, 4, "F - test-render-gap-buffer-with-cursor-at-start: result"
                                                                # abc
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|   ", "F - test-render-gap-buffer-with-cursor-at-start: bg"
}

## some primitives for scanning through a gap buffer
# don't modify the gap buffer while scanning
# this includes moving the cursor around

# restart scan without affecting gap-buffer contents
fn rewind-gap-buffer _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var dest/eax: (addr int) <- get self, left-read-index
  copy-to *dest, 0
  dest <- get self, right-read-index
  copy-to *dest, 0
}

fn gap-buffer-scan-done? _self: (addr gap-buffer) -> _/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  # more in left?
  var left/eax: (addr grapheme-stack) <- get self, left
  var left-size/eax: int <- grapheme-stack-length left
  var left-read-index/ecx: (addr int) <- get self, left-read-index
  compare *left-read-index, left-size
  {
    break-if->=
    return 0/false
  }
  # more in right?
  var right/eax: (addr grapheme-stack) <- get self, right
  var right-size/eax: int <- grapheme-stack-length right
  var right-read-index/ecx: (addr int) <- get self, right-read-index
  compare *right-read-index, right-size
  {
    break-if->=
    return 0/false
  }
  #
  return 1/true
}

fn peek-from-gap-buffer _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  # more in left?
  var left/ecx: (addr grapheme-stack) <- get self, left
  var left-size/eax: int <- grapheme-stack-length left
  var left-read-index-a/edx: (addr int) <- get self, left-read-index
  compare *left-read-index-a, left-size
  {
    break-if->=
    var left-data-ah/eax: (addr handle array grapheme) <- get left, data
    var left-data/eax: (addr array grapheme) <- lookup *left-data-ah
    var left-read-index/ecx: int <- copy *left-read-index-a
    var result/eax: (addr grapheme) <- index left-data, left-read-index
    return *result
  }
  # more in right?
  var right/ecx: (addr grapheme-stack) <- get self, right
  var _right-size/eax: int <- grapheme-stack-length right
  var right-size/ebx: int <- copy _right-size
  var right-read-index-a/edx: (addr int) <- get self, right-read-index
  compare *right-read-index-a, right-size
  {
    break-if->=
    # read the right from reverse
    var right-data-ah/eax: (addr handle array grapheme) <- get right, data
    var right-data/eax: (addr array grapheme) <- lookup *right-data-ah
    var right-read-index/ebx: int <- copy right-size
    right-read-index <- subtract *right-read-index-a
    right-read-index <- subtract 1
    var result/eax: (addr grapheme) <- index right-data, right-read-index
    return *result
  }
  # if we get here there's nothing left
  return 0/nul
}

fn read-from-gap-buffer _self: (addr gap-buffer) -> _/eax: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  # more in left?
  var left/ecx: (addr grapheme-stack) <- get self, left
  var left-size/eax: int <- grapheme-stack-length left
  var left-read-index-a/edx: (addr int) <- get self, left-read-index
  compare *left-read-index-a, left-size
  {
    break-if->=
    var left-data-ah/eax: (addr handle array grapheme) <- get left, data
    var left-data/eax: (addr array grapheme) <- lookup *left-data-ah
    var left-read-index/ecx: int <- copy *left-read-index-a
    var result/eax: (addr grapheme) <- index left-data, left-read-index
    increment *left-read-index-a
    return *result
  }
  # more in right?
  var right/ecx: (addr grapheme-stack) <- get self, right
  var _right-size/eax: int <- grapheme-stack-length right
  var right-size/ebx: int <- copy _right-size
  var right-read-index-a/edx: (addr int) <- get self, right-read-index
  compare *right-read-index-a, right-size
  {
    break-if->=
    # read the right from reverse
    var right-data-ah/eax: (addr handle array grapheme) <- get right, data
    var right-data/eax: (addr array grapheme) <- lookup *right-data-ah
    var right-read-index/ebx: int <- copy right-size
    right-read-index <- subtract *right-read-index-a
    right-read-index <- subtract 1
    var result/eax: (addr grapheme) <- index right-data, right-read-index
    increment *right-read-index-a
    return *result
  }
  # if we get here there's nothing left
  return 0/nul
}

fn test-read-from-gap-buffer {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  # gap is at end, all contents are in left
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check-not done?, "F - test-read-from-gap-buffer/left-1/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0x61/a, "F - test-read-from-gap-buffer/left-1"
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check-not done?, "F - test-read-from-gap-buffer/left-2/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0x62/b, "F - test-read-from-gap-buffer/left-2"
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check-not done?, "F - test-read-from-gap-buffer/left-3/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0x63/c, "F - test-read-from-gap-buffer/left-3"
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check done?, "F - test-read-from-gap-buffer/left-4/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0/nul, "F - test-read-from-gap-buffer/left-4"
  # now check when everything is to the right
  gap-to-start gap
  rewind-gap-buffer gap
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check-not done?, "F - test-read-from-gap-buffer/right-1/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0x61/a, "F - test-read-from-gap-buffer/right-1"
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check-not done?, "F - test-read-from-gap-buffer/right-2/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0x62/b, "F - test-read-from-gap-buffer/right-2"
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check-not done?, "F - test-read-from-gap-buffer/right-3/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0x63/c, "F - test-read-from-gap-buffer/right-3"
  var done?/eax: boolean <- gap-buffer-scan-done? gap
  check done?, "F - test-read-from-gap-buffer/right-4/done"
  var g/eax: grapheme <- read-from-gap-buffer gap
  var x/ecx: int <- copy g
  check-ints-equal x, 0/nul, "F - test-read-from-gap-buffer/right-4"
}

fn skip-whitespace-from-gap-buffer self: (addr gap-buffer) {
  var done?/eax: boolean <- gap-buffer-scan-done? self
  compare done?, 0/false
  break-if-!=
  var g/eax: grapheme <- peek-from-gap-buffer self
  {
    compare g, 0x20/space
    break-if-=
    compare g, 0xa/newline
    break-if-=
    return
  }
  g <- read-from-gap-buffer self
  loop
}

fn edit-gap-buffer self: (addr gap-buffer), key: grapheme {
  var g/edx: grapheme <- copy key
  {
    compare g, 8/backspace
    break-if-!=
    delete-before-gap self
    return
  }
  {
    compare g, 0x80/left-arrow
    break-if-!=
    var dummy/eax: grapheme <- gap-left self
    return
  }
  {
    compare g, 0x83/right-arrow
    break-if-!=
    var dummy/eax: grapheme <- gap-right self
    return
  }
  {
    compare g, 1/ctrl-a
    break-if-!=
    gap-to-start self
    return
  }
  {
    compare g, 5/ctrl-e
    break-if-!=
    gap-to-end self
    return
  }
  # default: insert character
  add-grapheme-at-gap self, g
}

fn cursor-on-final-line? self: (addr gap-buffer) -> _/eax: boolean {
  return 1/true
}

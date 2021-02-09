type gap-buffer {
  left: grapheme-stack
  right: grapheme-stack
}

fn initialize-gap-buffer _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  initialize-grapheme-stack left, 0x10/max-word-size
  var right/eax: (addr grapheme-stack) <- get self, right
  initialize-grapheme-stack right, 0x10/max-word-size
}

# just for tests
fn initialize-gap-buffer-with self: (addr gap-buffer), s: (addr array byte) {
  initialize-gap-buffer self
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
fn render-gap-buffer screen: (addr screen), _gap: (addr gap-buffer), x: int, y: int, render-cursor?: boolean -> _/eax: int {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/eax: (addr grapheme-stack) <- get gap, left
  var x2/eax: int <- render-stack-from-bottom left, screen, x, y
  var right/ecx: (addr grapheme-stack) <- get gap, right
  x2 <- render-stack-from-top right, screen, x2, y, render-cursor?
  var x3/ebx: int <- copy x2
  # if we must render cursor and the right side is empty, print a grapheme anyway
  {
    compare render-cursor?, 0/false
    break-if-=
    var empty?/eax: boolean <- grapheme-stack-empty? right
    compare empty?, 0/false
    break-if-=
    var space/eax: grapheme <- copy 0x20
    draw-grapheme screen, space, x3, y, 3/fg=cyan, 7/bg
    x3 <- increment
  }
  return x3
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

fn gap-index _self: (addr gap-buffer) -> _/eax: int {
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

fn test-gap-buffer-equal-from-end? {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g
  #
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  # gap is at end (right is empty)
  var _result/eax: boolean <- gap-buffer-equal? g, "aaa"
  var result/eax: int <- copy _result
  check-ints-equal result, 1, "F - test-gap-buffer-equal-from-end?"
}

fn test-gap-buffer-equal-from-middle? {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g
  #
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  var dummy/eax: grapheme <- gap-left g
  # gap is in the middle
  var _result/eax: boolean <- gap-buffer-equal? g, "aaa"
  var result/eax: int <- copy _result
  check-ints-equal result, 1, "F - test-gap-buffer-equal-from-middle?"
}

fn test-gap-buffer-equal-from-start? {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g
  #
  var c/eax: grapheme <- copy 0x61/a
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  add-grapheme-at-gap g, c
  var dummy/eax: grapheme <- gap-left g
  dummy <- gap-left g
  dummy <- gap-left g
  # gap is at the start
  var _result/eax: boolean <- gap-buffer-equal? g, "aaa"
  var result/eax: int <- copy _result
  check-ints-equal result, 1, "F - test-gap-buffer-equal-from-start?"
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
  check-ints-equal x, 3, "F - test-render-gap-buffer-without-cursor: result"
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
  check-ints-equal x, 3, "F - test-render-gap-buffer-with-cursor-in-middle: result"
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
  check-ints-equal x, 3, "F - test-render-gap-buffer-with-cursor-at-start: result"
                                                                # abc
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|   ", "F - test-render-gap-buffer-with-cursor-at-start: bg"
}

# primitive for editing text

type gap-buffer {
  left: grapheme-stack
  right: grapheme-stack
  # some fields for scanning incrementally through a gap-buffer
  left-read-index: int
  right-read-index: int
}

fn initialize-gap-buffer _self: (addr gap-buffer), capacity: int {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  initialize-grapheme-stack left, capacity
  var right/eax: (addr grapheme-stack) <- get self, right
  initialize-grapheme-stack right, capacity
}

fn clear-gap-buffer _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  clear-grapheme-stack left
  var right/eax: (addr grapheme-stack) <- get self, right
  clear-grapheme-stack right
}

fn gap-buffer-empty? _self: (addr gap-buffer) -> _/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  # if !empty?(left) return false
  {
    var left/eax: (addr grapheme-stack) <- get self, left
    var result/eax: boolean <- grapheme-stack-empty? left
    compare result, 0/false
    break-if-!=
    return 0/false
  }
  # return empty?(right)
  var left/eax: (addr grapheme-stack) <- get self, left
  var result/eax: boolean <- grapheme-stack-empty? left
  return result
}

fn gap-buffer-capacity _gap: (addr gap-buffer) -> _/edx: int {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/eax: (addr grapheme-stack) <- get gap, left
  var left-data-ah/eax: (addr handle array grapheme) <- get left, data
  var left-data/eax: (addr array grapheme) <- lookup *left-data-ah
  var result/eax: int <- length left-data
  return result
}

# just for tests
fn initialize-gap-buffer-with self: (addr gap-buffer), keys: (addr array byte) {
  initialize-gap-buffer self, 0x40/capacity
  var input-stream-storage: (stream byte 0x40/capacity)
  var input-stream/ecx: (addr stream byte) <- address input-stream-storage
  write input-stream, keys
  {
    var done?/eax: boolean <- stream-empty? input-stream
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme input-stream
    add-grapheme-at-gap self, g
    loop
  }
}

fn load-gap-buffer-from-stream self: (addr gap-buffer), in: (addr stream byte) {
  rewind-stream in
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var key/eax: byte <- read-byte in
    compare key, 0/null
    break-if-=
    var g/eax: grapheme <- copy key
    edit-gap-buffer self, g
    loop
  }
}

fn emit-gap-buffer self: (addr gap-buffer), out: (addr stream byte) {
  clear-stream out
  append-gap-buffer self, out
}

fn append-gap-buffer _self: (addr gap-buffer), out: (addr stream byte) {
  var self/esi: (addr gap-buffer) <- copy _self
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

fn word-at-gap _self: (addr gap-buffer), out: (addr stream byte) {
  var self/esi: (addr gap-buffer) <- copy _self
  clear-stream out
  {
    var g/eax: grapheme <- grapheme-at-gap self
    var at-word?/eax: boolean <- is-ascii-word-grapheme? g
    compare at-word?, 0/false
    break-if-!=
    return
  }
  var left/ecx: (addr grapheme-stack) <- get self, left
  var left-index/eax: int <- top-most-word left
  emit-stack-from-index left, left-index, out
  var right/ecx: (addr grapheme-stack) <- get self, right
  var right-index/eax: int <- top-most-word right
  emit-stack-to-index right, right-index, out
}

fn test-word-at-gap-single-word-with-gap-at-end {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "abc"
  # gap is at end (right is empty)
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "abc", "F - test-word-at-gap-single-word-with-gap-at-end"
}

fn test-word-at-gap-single-word-with-gap-at-start {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "abc"
  gap-to-start g
  #
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "abc", "F - test-word-at-gap-single-word-with-gap-at-start"
}

fn test-word-at-gap-multiple-words-with-gap-at-non-word-grapheme-at-end {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "abc "
  # gap is at end (right is empty)
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "", "F - test-word-at-gap-multiple-words-with-gap-at-non-word-grapheme-at-end"
}

fn test-word-at-gap-multiple-words-with-gap-at-non-word-grapheme-at-start {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, " abc"
  gap-to-start g
  #
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "", "F - test-word-at-gap-multiple-words-with-gap-at-non-word-grapheme-at-start"
}

fn test-word-at-gap-multiple-words-with-gap-at-end {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "a bc d"
  # gap is at end (right is empty)
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "d", "F - test-word-at-gap-multiple-words-with-gap-at-end"
}

fn test-word-at-gap-multiple-words-with-gap-at-initial-word {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "a bc d"
  gap-to-start g
  #
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "a", "F - test-word-at-gap-multiple-words-with-gap-at-initial-word"
}

fn test-word-at-gap-multiple-words-with-gap-at-final-word {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "a bc d"
  var dummy/eax: grapheme <- gap-left g
  # gap is at final word
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "d", "F - test-word-at-gap-multiple-words-with-gap-at-final-word"
}

fn test-word-at-gap-multiple-words-with-gap-at-final-non-word {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer-with g, "abc "
  var dummy/eax: grapheme <- gap-left g
  # gap is at final word
  var out-storage: (stream byte 0x10)
  var out/eax: (addr stream byte) <- address out-storage
  word-at-gap g, out
  check-stream-equal out, "", "F - test-word-at-gap-multiple-words-with-gap-at-final-non-word"
}

fn grapheme-at-gap _self: (addr gap-buffer) -> _/eax: grapheme {
  # send top of right most of the time
  var self/esi: (addr gap-buffer) <- copy _self
  var right/edi: (addr grapheme-stack) <- get self, right
  var data-ah/eax: (addr handle array grapheme) <- get right, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var top-addr/ecx: (addr int) <- get right, top
  {
    compare *top-addr, 0
    break-if-<=
    var top/ecx: int <- copy *top-addr
    top <- decrement
    var result/eax: (addr grapheme) <- index data, top
    return *result
  }
  # send top of left only if right is empty
  var left/edi: (addr grapheme-stack) <- get self, left
  var data-ah/eax: (addr handle array grapheme) <- get left, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var top-addr/ecx: (addr int) <- get left, top
  {
    compare *top-addr, 0
    break-if-<=
    var top/ecx: int <- copy *top-addr
    top <- decrement
    var result/eax: (addr grapheme) <- index data, top
    return *result
  }
  # send null if everything is empty
  return 0
}

fn top-most-word _self: (addr grapheme-stack) -> _/eax: int {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy *top-addr
  i <- decrement
  {
    compare i, 0
    break-if-<
    var g/edx: (addr grapheme) <- index data, i
    var is-word?/eax: boolean <- is-ascii-word-grapheme? *g
    compare is-word?, 0/false
    break-if-=
    i <- decrement
    loop
  }
  i <- increment
  return i
}

fn emit-stack-from-index _self: (addr grapheme-stack), start: int, out: (addr stream byte) {
  var self/esi: (addr grapheme-stack) <- copy _self
  var data-ah/edi: (addr handle array grapheme) <- get self, data
  var _data/eax: (addr array grapheme) <- lookup *data-ah
  var data/edi: (addr array grapheme) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/eax: int <- copy start
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr grapheme) <- index data, i
    write-grapheme out, *g
    i <- increment
    loop
  }
}

fn emit-stack-to-index _self: (addr grapheme-stack), end: int, out: (addr stream byte) {
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
    compare i, end
    break-if-<
    var g/edx: (addr grapheme) <- index data, i
    write-grapheme out, *g
    i <- decrement
    loop
  }
}

fn is-ascii-word-grapheme? g: grapheme -> _/eax: boolean {
  compare g, 0x21/!
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x30/0
  {
    break-if->=
    return 0/false
  }
  compare g, 0x39/9
  {
    break-if->
    return 1/true
  }
  compare g, 0x3f/?
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x41/A
  {
    break-if->=
    return 0/false
  }
  compare g, 0x5a/Z
  {
    break-if->
    return 1/true
  }
  compare g, 0x5f/_
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x61/a
  {
    break-if->=
    return 0/false
  }
  compare g, 0x7a/z
  {
    break-if->
    return 1/true
  }
  return 0/false
}

# We implicitly render everything editable in a single color, and assume the
# cursor is a single other color.
fn render-gap-buffer-wrapping-right-then-down screen: (addr screen), _gap: (addr gap-buffer), xmin: int, ymin: int, xmax: int, ymax: int, render-cursor?: boolean, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/edx: (addr grapheme-stack) <- get gap, left
  var highlight-matching-open-paren?/ebx: boolean <- copy 0/false
  var matching-open-paren-depth/edi: int <- copy 0
  highlight-matching-open-paren?, matching-open-paren-depth <- highlight-matching-open-paren? gap, render-cursor?
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- render-stack-from-bottom-wrapping-right-then-down screen, left, xmin, ymin, xmax, ymax, xmin, ymin, highlight-matching-open-paren?, matching-open-paren-depth, color, background-color
  var right/edx: (addr grapheme-stack) <- get gap, right
  x2, y2 <- render-stack-from-top-wrapping-right-then-down screen, right, xmin, ymin, xmax, ymax, x2, y2, render-cursor?, color, background-color
  # decide whether we still need to print a cursor
  var fg/edi: int <- copy color
  var bg/ebx: int <- copy background-color
  compare render-cursor?, 0/false
  {
    break-if-=
    # if the right side is empty, grapheme stack didn't print the cursor
    var empty?/eax: boolean <- grapheme-stack-empty? right
    compare empty?, 0/false
    break-if-=
    # swap foreground and background
    fg <- copy background-color
    bg <- copy color
  }
  # print a grapheme either way so that cursor position doesn't affect printed width
  var space/edx: code-point <- copy 0x20
  x2, y2 <- render-code-point screen, space, xmin, ymin, xmax, ymax, x2, y2, fg, bg
  return x2, y2
}

fn render-gap-buffer screen: (addr screen), gap: (addr gap-buffer), x: int, y: int, render-cursor?: boolean, color: int, background-color: int -> _/eax: int {
  var _width/eax: int <- copy 0
  var _height/ecx: int <- copy 0
  _width, _height <- screen-size screen
  var width/edx: int <- copy _width
  var height/ebx: int <- copy _height
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- render-gap-buffer-wrapping-right-then-down screen, gap, x, y, width, height, render-cursor?, color, background-color
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

fn add-code-point-at-gap self: (addr gap-buffer), c: code-point {
  var g/eax: grapheme <- copy c
  add-grapheme-at-gap self, g
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
  var stream-storage: (stream byte 0x10/capacity)
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
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
  # gap is at end (right is empty)
  var result/eax: boolean <- gap-buffer-equal? g, "aaa"
  check result, "F - test-gap-buffer-equal-from-end"
}

fn test-gap-buffer-equal-from-middle {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g, 0x10
  #
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
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
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
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
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
  add-code-point-at-gap g, 0x61/a
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
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 0/no-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-without-cursor"
  check-ints-equal x, 4, "F - test-render-gap-buffer-without-cursor: result"
                                                                # abc
  check-background-color-in-screen-row screen, 3/bg=reverse, 0/y, "    ", "F - test-render-gap-buffer-without-cursor: bg"
}

fn test-render-gap-buffer-with-cursor-at-end {
  # setup
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  gap-to-end gap
  # setup: screen
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-with-cursor-at-end"
  # we've drawn one extra grapheme for the cursor
  check-ints-equal x, 4, "F - test-render-gap-buffer-with-cursor-at-end: result"
                                                                # abc
  check-background-color-in-screen-row screen, 3/bg=reverse, 0/y, "   |", "F - test-render-gap-buffer-with-cursor-at-end: bg"
}

fn test-render-gap-buffer-with-cursor-in-middle {
  # setup
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  gap-to-end gap
  var dummy/eax: grapheme <- gap-left gap
  # setup: screen
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-with-cursor-in-middle"
  check-ints-equal x, 4, "F - test-render-gap-buffer-with-cursor-in-middle: result"
                                                                # abc
  check-background-color-in-screen-row screen, 3/bg=reverse, 0/y, "  | ", "F - test-render-gap-buffer-with-cursor-in-middle: bg"
}

fn test-render-gap-buffer-with-cursor-at-start {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "abc"
  gap-to-start gap
  # setup: screen
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row screen, 0/y, "abc ", "F - test-render-gap-buffer-with-cursor-at-start"
  check-ints-equal x, 4, "F - test-render-gap-buffer-with-cursor-at-start: result"
                                                                # abc
  check-background-color-in-screen-row screen, 3/bg=reverse, 0/y, "|   ", "F - test-render-gap-buffer-with-cursor-at-start: bg"
}

fn test-render-gap-buffer-highlight-matching-close-paren {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "(a)"
  gap-to-start gap
  # setup: screen
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row                     screen, 0/y,                   "(a) ", "F - test-render-gap-buffer-highlight-matching-close-paren"
  check-ints-equal x, 4, "F - test-render-gap-buffer-highlight-matching-close-paren: result"
  check-background-color-in-screen-row screen, 3/bg=reverse,      0/y, "|   ", "F - test-render-gap-buffer-highlight-matching-close-paren: cursor"
  check-screen-row-in-color            screen, 0xf/fg=highlight, 0/y, "  ) ", "F - test-render-gap-buffer-highlight-matching-close-paren: matching paren"
}

fn test-render-gap-buffer-highlight-matching-open-paren {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "(a)"
  gap-to-end gap
  var dummy/eax: grapheme <- gap-left gap
  # setup: screen
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row                     screen, 0/y,                   "(a) ", "F - test-render-gap-buffer-highlight-matching-open-paren"
  check-ints-equal x, 4, "F - test-render-gap-buffer-highlight-matching-open-paren: result"
  check-background-color-in-screen-row screen, 3/bg=reverse,      0/y, "  | ", "F - test-render-gap-buffer-highlight-matching-open-paren: cursor"
  check-screen-row-in-color            screen, 0xf/fg=highlight, 0/y, "(   ", "F - test-render-gap-buffer-highlight-matching-open-paren: matching paren"
}

fn test-render-gap-buffer-highlight-matching-open-paren-of-end {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "(a)"
  gap-to-end gap
  # setup: screen
  var screen-storage: screen
  var screen/edi: (addr screen) <- address screen-storage
  initialize-screen screen, 5, 4, 0/no-pixel-graphics
  #
  var x/eax: int <- render-gap-buffer screen, gap, 0/x, 0/y, 1/show-cursor, 3/fg, 0xc5/bg=blue-bg
  check-screen-row                     screen, 0/y,                   "(a) ", "F - test-render-gap-buffer-highlight-matching-open-paren-of-end"
  check-ints-equal x, 4, "F - test-render-gap-buffer-highlight-matching-open-paren-of-end: result"
  check-background-color-in-screen-row screen, 3/bg=reverse,      0/y, "   |", "F - test-render-gap-buffer-highlight-matching-open-paren-of-end: cursor"
  check-screen-row-in-color            screen, 0xf/fg=highlight, 0/y, "(   ", "F - test-render-gap-buffer-highlight-matching-open-paren-of-end: matching paren"
}

# should I highlight a matching open paren? And if so, at what depth from top of left?
# basically there are two cases to disambiguate here:
#   Usually the cursor is at top of right. Highlight first '(' at depth 0 from top of left.
#   If right is empty, match the ')' _before_ cursor. Highlight first '(' at depth _1_ from top of left.
fn highlight-matching-open-paren? _gap: (addr gap-buffer), render-cursor?: boolean -> _/ebx: boolean, _/edi: int {
  # if not rendering cursor, return
  compare render-cursor?, 0/false
  {
    break-if-!=
    return 0/false, 0
  }
  var gap/esi: (addr gap-buffer) <- copy _gap
  var stack/edi: (addr grapheme-stack) <- get gap, right
  var top-addr/eax: (addr int) <- get stack, top
  var top-index/ecx: int <- copy *top-addr
  compare top-index, 0
  {
    break-if->
    # if cursor at end, return (char before cursor == ')', 1)
    stack <- get gap, left
    top-addr <- get stack, top
    top-index <- copy *top-addr
    compare top-index, 0
    {
      break-if->
      return 0/false, 0
    }
    top-index <- decrement
    var data-ah/eax: (addr handle array grapheme) <- get stack, data
    var data/eax: (addr array grapheme) <- lookup *data-ah
    var g/eax: (addr grapheme) <- index data, top-index
    compare *g, 0x29/close-paren
    {
      break-if-=
      return 0/false, 0
    }
    return 1/true, 1
  }
  # cursor is not at end; return (char at cursor == ')')
  top-index <- decrement
  var data-ah/eax: (addr handle array grapheme) <- get stack, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var g/eax: (addr grapheme) <- index data, top-index
  compare *g, 0x29/close-paren
  {
    break-if-=
    return 0/false, 0
  }
  return 1/true, 0
}

fn test-highlight-matching-open-paren {
  var gap-storage: gap-buffer
  var gap/esi: (addr gap-buffer) <- address gap-storage
  initialize-gap-buffer-with gap, "(a)"
  gap-to-end gap
  var highlight-matching-open-paren?/ebx: boolean <- copy 0/false
  var open-paren-depth/edi: int <- copy 0
  highlight-matching-open-paren?, open-paren-depth <- highlight-matching-open-paren? gap, 0/no-cursor
  check-not highlight-matching-open-paren?, "F - test-highlight-matching-open-paren: no cursor"
  highlight-matching-open-paren?, open-paren-depth <- highlight-matching-open-paren? gap, 1/render-cursor
  check highlight-matching-open-paren?, "F - test-highlight-matching-open-paren: at end immediately after ')'"
  check-ints-equal open-paren-depth, 1, "F - test-highlight-matching-open-paren: depth at end immediately after ')'"
  var dummy/eax: grapheme <- gap-left gap
  highlight-matching-open-paren?, open-paren-depth <- highlight-matching-open-paren? gap, 1/render-cursor
  check highlight-matching-open-paren?, "F - test-highlight-matching-open-paren: on ')'"
  dummy <- gap-left gap
  highlight-matching-open-paren?, open-paren-depth <- highlight-matching-open-paren? gap, 1/render-cursor
  check-not highlight-matching-open-paren?, "F - test-highlight-matching-open-paren: not on ')'"
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

fn put-back-from-gap-buffer _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  # more in right?
  var right/eax: (addr grapheme-stack) <- get self, right
  var right-size/eax: int <- grapheme-stack-length right
  var right-read-index-a/eax: (addr int) <- get self, right-read-index
  compare *right-read-index-a, 0
  {
    break-if-<=
    decrement *right-read-index-a
    return
  }
  # more in left?
  var left/eax: (addr grapheme-stack) <- get self, left
  var left-size/eax: int <- grapheme-stack-length left
  var left-read-index-a/eax: (addr int) <- get self, left-read-index
  decrement *left-read-index-a
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

fn skip-spaces-from-gap-buffer self: (addr gap-buffer) {
  var done?/eax: boolean <- gap-buffer-scan-done? self
  compare done?, 0/false
  break-if-!=
  var g/eax: grapheme <- peek-from-gap-buffer self
  {
    compare g, 0x20/space
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
    compare g, 6/ctrl-f
    break-if-!=
    gap-to-start-of-next-word self
    return
  }
  {
    compare g, 2/ctrl-b
    break-if-!=
    gap-to-end-of-previous-word self
    return
  }
  {
    compare g, 1/ctrl-a
    break-if-!=
    gap-to-previous-start-of-line self
    return
  }
  {
    compare g, 5/ctrl-e
    break-if-!=
    gap-to-next-end-of-line self
    return
  }
  {
    compare g, 0x81/down-arrow
    break-if-!=
    gap-down self
    return
  }
  {
    compare g, 0x82/up-arrow
    break-if-!=
    gap-up self
    return
  }
  {
    compare g, 0x15/ctrl-u
    break-if-!=
    clear-gap-buffer self
    return
  }
  {
    compare g, 9/tab
    break-if-!=
    # tab = 2 spaces
    add-code-point-at-gap self, 0x20/space
    add-code-point-at-gap self, 0x20/space
    return
  }
  # default: insert character
  add-grapheme-at-gap self, g
}

fn gap-to-start-of-next-word self: (addr gap-buffer) {
  var curr/eax: grapheme <- copy 0
  # skip to next space
  {
    curr <- gap-right self
    compare curr, -1
    break-if-=
    compare curr, 0x20/space
    break-if-=
    compare curr, 0xa/newline
    break-if-=
    loop
  }
  # skip past spaces
  {
    curr <- gap-right self
    compare curr, -1
    break-if-=
    compare curr, 0x20/space
    loop-if-=
    compare curr, 0xa/space
    loop-if-=
    curr <- gap-left self
    break
  }
}

fn gap-to-end-of-previous-word self: (addr gap-buffer) {
  var curr/eax: grapheme <- copy 0
  # skip to previous space
  {
    curr <- gap-left self
    compare curr, -1
    break-if-=
    compare curr, 0x20/space
    break-if-=
    compare curr, 0xa/newline
    break-if-=
    loop
  }
  # skip past all spaces but one
  {
    curr <- gap-left self
    compare curr, -1
    break-if-=
    compare curr, 0x20/space
    loop-if-=
    compare curr, 0xa/space
    loop-if-=
    curr <- gap-right self
    break
  }
}

fn gap-to-previous-start-of-line self: (addr gap-buffer) {
  # skip past immediate newline
  var dummy/eax: grapheme <- gap-left self
  # skip to previous newline
  {
    dummy <- gap-left self
    {
      compare dummy, -1
      break-if-!=
      return
    }
    {
      compare dummy, 0xa/newline
      break-if-!=
      dummy <- gap-right self
      return
    }
    loop
  }
}

fn gap-to-next-end-of-line self: (addr gap-buffer) {
  # skip past immediate newline
  var dummy/eax: grapheme <- gap-right self
  # skip to next newline
  {
    dummy <- gap-right self
    {
      compare dummy, -1
      break-if-!=
      return
    }
    {
      compare dummy, 0xa/newline
      break-if-!=
      dummy <- gap-left self
      return
    }
    loop
  }
}

fn gap-up self: (addr gap-buffer) {
  # compute column
  var col/edx: int <- count-columns-to-start-of-line self
  #
  gap-to-previous-start-of-line self
  # skip ahead by up to col on previous line
  var i/ecx: int <- copy 0
  {
    compare i, col
    break-if->=
    var curr/eax: grapheme <- gap-right self
    {
      compare curr, -1
      break-if-!=
      return
    }
    compare curr, 0xa/newline
    {
      break-if-!=
      curr <- gap-left self
      return
    }
    i <- increment
    loop
  }
}

fn gap-down self: (addr gap-buffer) {
  # compute column
  var col/edx: int <- count-columns-to-start-of-line self
  # skip to start of next line
  gap-to-end-of-line self
  var dummy/eax: grapheme <- gap-right self
  # skip ahead by up to col on previous line
  var i/ecx: int <- copy 0
  {
    compare i, col
    break-if->=
    var curr/eax: grapheme <- gap-right self
    {
      compare curr, -1
      break-if-!=
      return
    }
    compare curr, 0xa/newline
    {
      break-if-!=
      curr <- gap-left self
      return
    }
    i <- increment
    loop
  }
}

fn count-columns-to-start-of-line self: (addr gap-buffer) -> _/edx: int {
  var count/edx: int <- copy 0
  var dummy/eax: grapheme <- copy 0
  # skip to previous newline
  {
    dummy <- gap-left self
    {
      compare dummy, -1
      break-if-!=
      return count
    }
    {
      compare dummy, 0xa/newline
      break-if-!=
      dummy <- gap-right self
      return count
    }
    count <- increment
    loop
  }
  return count
}

fn gap-to-end-of-line self: (addr gap-buffer) {
  var dummy/eax: grapheme <- copy 0
  # skip to next newline
  {
    dummy <- gap-right self
    {
      compare dummy, -1
      break-if-!=
      return
    }
    {
      compare dummy, 0xa/newline
      break-if-!=
      dummy <- gap-left self
      return
    }
    loop
  }
}

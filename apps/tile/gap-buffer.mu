type gap-buffer {
  left: grapheme-stack
  right: grapheme-stack
}

fn initialize-gap-buffer _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  initialize-grapheme-stack left, 0x10  # max-word-size
  var right/eax: (addr grapheme-stack) <- get self, right
  initialize-grapheme-stack right, 0x10  # max-word-size
}

# just for tests
fn initialize-gap-buffer-with self: (addr gap-buffer), s: (addr array byte) {
  initialize-gap-buffer self
  var stream-storage: (stream byte 0x10)  # max-word-size
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, s
  {
    var done?/eax: boolean <- stream-empty? stream
    compare done?, 0  # false
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

fn render-gap-buffer screen: (addr screen), _gap: (addr gap-buffer) {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/eax: (addr grapheme-stack) <- get gap, left
  render-stack-from-bottom left, screen
  var right/eax: (addr grapheme-stack) <- get gap, right
  render-stack-from-top right, screen
}

fn gap-buffer-length _gap: (addr gap-buffer) -> result/eax: int {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/eax: (addr grapheme-stack) <- get gap, left
  var tmp/eax: (addr int) <- get left, top
  var left-length/ecx: int <- copy *tmp
  var right/esi: (addr grapheme-stack) <- get gap, right
  tmp <- get right, top
  result <- copy *tmp
  result <- add left-length
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

fn gap-at-start? _self: (addr gap-buffer) -> result/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  result <- grapheme-stack-empty? left
}

fn gap-at-end? _self: (addr gap-buffer) -> result/eax: boolean {
  var self/esi: (addr gap-buffer) <- copy _self
  var right/eax: (addr grapheme-stack) <- get self, right
  result <- grapheme-stack-empty? right
}

fn gap-right _self: (addr gap-buffer) -> result/eax: grapheme {
$gap-right:body: {
  var self/esi: (addr gap-buffer) <- copy _self
  var g/edx: grapheme <- copy 0
  {
    var right/ecx: (addr grapheme-stack) <- get self, right
    result <- pop-grapheme-stack right
    compare result, -1
    break-if-= $gap-right:body
    g <- copy result
  }
  {
    var left/ecx: (addr grapheme-stack) <- get self, left
    push-grapheme-stack left, g
  }
}
}

fn gap-left _self: (addr gap-buffer) -> result/eax: grapheme {
$gap-left:body: {
  var self/esi: (addr gap-buffer) <- copy _self
  var g/edx: grapheme <- copy 0
  {
    var left/ecx: (addr grapheme-stack) <- get self, left
    result <- pop-grapheme-stack left
    compare result, -1
    break-if-= $gap-left:body
    g <- copy result
  }
  {
    var right/ecx: (addr grapheme-stack) <- get self, right
    push-grapheme-stack right, g
  }
}
}

fn gap-index _self: (addr gap-buffer) -> result/eax: int {
  var self/eax: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  var top-addr/eax: (addr int) <- get left, top
  result <- copy *top-addr
}

fn gap-buffer-equal? _self: (addr gap-buffer), s: (addr array byte) -> result/eax: boolean {
$gap-buffer-equal?:body: {
  var self/esi: (addr gap-buffer) <- copy _self
  # complication: graphemes may be multiple bytes
  # so don't rely on length
  # instead turn the expected result into a stream and arrange to read from it in order
  var stream-storage: (stream byte 0x10)  # max-word-size
  var expected-stream/ecx: (addr stream byte) <- address stream-storage
  write expected-stream, s
  # compare left
  var left/edx: (addr grapheme-stack) <- get self, left
  result <- prefix-match? left, expected-stream
  compare result, 0  # false
  break-if-= $gap-buffer-equal?:body
  # compare right
  var right/edx: (addr grapheme-stack) <- get self, right
  result <- suffix-match? right, expected-stream
  compare result, 0  # false
  break-if-= $gap-buffer-equal?:body
  # ensure there's nothing left over
  result <- stream-empty? expected-stream
}
}

fn test-gap-buffer-equal-from-end? {
  var _g: gap-buffer
  var g/esi: (addr gap-buffer) <- address _g
  initialize-gap-buffer g
  #
  var c/eax: grapheme <- copy 0x61  # 'a'
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
  var c/eax: grapheme <- copy 0x61  # 'a'
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
  var c/eax: grapheme <- copy 0x61  # 'a'
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

fn grapheme-stack-empty? _self: (addr grapheme-stack) -> result/eax: boolean {
$grapheme-stack-empty?:body: {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-=
    result <- copy 1  # false
    break $grapheme-stack-empty?:body
  }
  result <- copy 0  # false
}
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

fn pop-grapheme-stack _self: (addr grapheme-stack) -> val/eax: grapheme {
$pop-grapheme-stack:body: {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    val <- copy -1
    break $pop-grapheme-stack:body
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array grapheme) <- get self, data
  var data/eax: (addr array grapheme) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr grapheme) <- index data, top
  val <- copy *result-addr
}
}

# dump stack to screen from bottom to top
# don't move the cursor or anything
fn render-stack-from-bottom _self: (addr grapheme-stack), screen: (addr screen) {
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
    print-grapheme screen, *g
    i <- increment
    loop
  }
}

# dump stack to screen from top to bottom
# don't move the cursor or anything
fn render-stack-from-top _self: (addr grapheme-stack), screen: (addr screen) {
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
    print-grapheme screen, *g
    i <- decrement
    loop
  }
}

# compare from bottom
# beware: modifies 'stream', which must be disposed of after a false result
fn prefix-match? _self: (addr grapheme-stack), s: (addr stream byte) -> result/eax: boolean {
$prefix-match?:body: {
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
        result <- copy 0  # false
        break $prefix-match?:body
      }
    }
    i <- increment
    loop
  }
  result <- copy 1   # true
}
}

# compare from bottom
# beware: modifies 'stream', which must be disposed of after a false result
fn suffix-match? _self: (addr grapheme-stack), s: (addr stream byte) -> result/eax: boolean {
$suffix-match?:body: {
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
        result <- copy 0  # false
        break $suffix-match?:body
      }
    }
    i <- decrement
    loop
  }
  result <- copy 1   # true
}
}

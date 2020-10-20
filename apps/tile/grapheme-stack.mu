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

fn grapheme-stack-empty? _self: (addr grapheme-stack) -> result/eax: boolean {
$grapheme-stack-empty?:body: {
  var self/esi: (addr grapheme-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-!=
    result <- copy 1  # true
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

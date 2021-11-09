type code-point-utf8-stack {
  data: (handle array code-point-utf8)
  top: int
}

fn initialize-code-point-utf8-stack _self: (addr code-point-utf8-stack), n: int {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var d/edi: (addr handle array code-point-utf8) <- get self, data
  populate d, n
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn clear-code-point-utf8-stack _self: (addr code-point-utf8-stack) {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn code-point-utf8-stack-empty? _self: (addr code-point-utf8-stack) -> _/eax: boolean {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn push-code-point-utf8-stack _self: (addr code-point-utf8-stack), _val: code-point-utf8 {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array code-point-utf8) <- get self, data
  var data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-addr/edx: (addr code-point-utf8) <- index data, top
  var val/eax: code-point-utf8 <- copy _val
  copy-to *dest-addr, val
  add-to *top-addr, 1
}

fn pop-code-point-utf8-stack _self: (addr code-point-utf8-stack) -> _/eax: code-point-utf8 {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    return -1
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array code-point-utf8) <- get self, data
  var data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr code-point-utf8) <- index data, top
  return *result-addr
}

fn copy-code-point-utf8-stack _src: (addr code-point-utf8-stack), dest: (addr code-point-utf8-stack) {
  var src/esi: (addr code-point-utf8-stack) <- copy _src
  var data-ah/edi: (addr handle array code-point-utf8) <- get src, data
  var _data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var data/edi: (addr array code-point-utf8) <- copy _data
  var top-addr/ecx: (addr int) <- get src, top
  var i/eax: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr code-point-utf8) <- index data, i
    push-code-point-utf8-stack dest, *g
    i <- increment
    loop
  }
}

# dump stack to screen from bottom to top
# don't move the cursor or anything
fn render-stack-from-bottom _self: (addr code-point-utf8-stack), screen: (addr screen) {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var data-ah/edi: (addr handle array code-point-utf8) <- get self, data
  var _data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var data/edi: (addr array code-point-utf8) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/eax: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr code-point-utf8) <- index data, i
    print-code-point-utf8 screen, *g
    i <- increment
    loop
  }
}

# dump stack to screen from top to bottom
# don't move the cursor or anything
fn render-stack-from-top _self: (addr code-point-utf8-stack), screen: (addr screen) {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var data-ah/edi: (addr handle array code-point-utf8) <- get self, data
  var _data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var data/edi: (addr array code-point-utf8) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/eax: int <- copy *top-addr
  i <- decrement
  {
    compare i, 0
    break-if-<
    var g/edx: (addr code-point-utf8) <- index data, i
    print-code-point-utf8 screen, *g
    i <- decrement
    loop
  }
}

# compare from bottom
# beware: modifies 'stream', which must be disposed of after a false result
fn prefix-match? _self: (addr code-point-utf8-stack), s: (addr stream byte) -> _/eax: boolean {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var data-ah/edi: (addr handle array code-point-utf8) <- get self, data
  var _data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var data/edi: (addr array code-point-utf8) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    # if curr != expected, return false
    {
      var curr-a/edx: (addr code-point-utf8) <- index data, i
      var expected/eax: code-point-utf8 <- read-code-point-utf8 s
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
fn suffix-match? _self: (addr code-point-utf8-stack), s: (addr stream byte) -> _/eax: boolean {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var data-ah/edi: (addr handle array code-point-utf8) <- get self, data
  var _data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var data/edi: (addr array code-point-utf8) <- copy _data
  var top-addr/eax: (addr int) <- get self, top
  var i/ebx: int <- copy *top-addr
  i <- decrement
  {
    compare i, 0
    break-if-<
    {
      var curr-a/edx: (addr code-point-utf8) <- index data, i
      var expected/eax: code-point-utf8 <- read-code-point-utf8 s
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

fn code-point-utf8-stack-is-decimal-integer? _self: (addr code-point-utf8-stack) -> _/eax: boolean {
  var self/esi: (addr code-point-utf8-stack) <- copy _self
  var data-ah/eax: (addr handle array code-point-utf8) <- get self, data
  var _data/eax: (addr array code-point-utf8) <- lookup *data-ah
  var data/edx: (addr array code-point-utf8) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  var result/eax: boolean <- copy 1/true
  $code-point-utf8-stack-is-integer?:loop: {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr code-point-utf8) <- index data, i
    result <- decimal-digit? *g
    compare result, 0/false
    break-if-=
    i <- increment
    loop
  }
  return result
}

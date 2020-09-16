type gap-buffer {
  left: grapheme-stack
  right: grapheme-stack
}

fn initialize-gap-buffer _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  initialize-grapheme-stack left, 0x10
  var right/eax: (addr grapheme-stack) <- get self, right
  initialize-grapheme-stack right, 0x10
}

fn render-gap-buffer screen: (addr screen), _gap: (addr gap-buffer) {
  var gap/esi: (addr gap-buffer) <- copy _gap
  var left/eax: (addr grapheme-stack) <- get gap, left
  render-stack-from-bottom left, screen
  var right/eax: (addr grapheme-stack) <- get gap, right
  render-stack-from-top right, screen
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

fn add-grapheme _self: (addr gap-buffer), g: grapheme {
  var self/esi: (addr gap-buffer) <- copy _self
  var left/eax: (addr grapheme-stack) <- get self, left
  push-grapheme-stack left, g
}

fn cursor-right _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var g/ecx: grapheme <- copy 0
  {
    var right/eax: (addr grapheme-stack) <- get self, right
    var tmp/eax: grapheme <- pop-grapheme-stack right
    g <- copy tmp
  }
  {
    var left/eax: (addr grapheme-stack) <- get self, left
    push-grapheme-stack left, g
  }
}

fn cursor-left _self: (addr gap-buffer) {
  var self/esi: (addr gap-buffer) <- copy _self
  var g/ecx: grapheme <- copy 0
  {
    var left/eax: (addr grapheme-stack) <- get self, left
    var tmp/eax: grapheme <- pop-grapheme-stack left
    g <- copy tmp
  }
  {
    var right/eax: (addr grapheme-stack) <- get self, right
    push-grapheme-stack right, g
  }
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
    val <- copy 0
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

type float-stack {
  data: (handle array float)
  top: int
}

fn initialize-float-stack _self: (addr float-stack), n: int {
  var self/esi: (addr float-stack) <- copy _self
  var d/edi: (addr handle array float) <- get self, data
  populate d, n
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn clear-float-stack _self: (addr float-stack) {
  var self/esi: (addr float-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn push-float-stack _self: (addr float-stack), _val: float {
  var self/esi: (addr float-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array float) <- get self, data
  var data/eax: (addr array float) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-addr/edx: (addr float) <- index data, top
  var val/xmm0: float <- copy _val
  copy-to *dest-addr, val
  add-to *top-addr, 1
}

fn pop-float-stack _self: (addr float-stack) -> _/xmm0: float {
  var self/esi: (addr float-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    var zero: float
    return zero
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array float) <- get self, data
  var data/eax: (addr array float) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr float) <- index data, top
  return *result-addr
}

fn float-stack-empty? _self: (addr float-stack) -> _/eax: boolean {
  var self/esi: (addr float-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  compare *top-addr, 0
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn float-stack-length _self: (addr float-stack) -> _/eax: int {
  var self/esi: (addr float-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  return *top-addr
}

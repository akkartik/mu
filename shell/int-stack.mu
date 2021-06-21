type int-stack {
  data: (handle array int)
  top: int
}

fn initialize-int-stack _self: (addr int-stack), n: int {
  var self/esi: (addr int-stack) <- copy _self
  var d/edi: (addr handle array int) <- get self, data
  populate d, n
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn push-int-stack _self: (addr int-stack), _val: int {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array int) <- get self, data
  var data/eax: (addr array int) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-addr/edx: (addr int) <- index data, top
  var val/eax: int <- copy _val
  copy-to *dest-addr, val
  add-to *top-addr, 1
}

fn pop-int-stack _self: (addr int-stack) -> _/eax: int {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    return 0
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array int) <- get self, data
  var data/eax: (addr array int) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr int) <- index data, top
  var val/eax: int <- copy *result-addr
  return val
}

fn int-stack-empty? _self: (addr int-stack) -> _/eax: boolean {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  compare *top-addr, 0
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn int-stack-top _self: (addr int-stack) -> _/eax: int {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var top/ecx: int <- copy *top-addr
  {
    compare top, 0
    break-if->
    return 0
  }
  top <- decrement
  var data-ah/edx: (addr handle array int) <- get self, data
  var data/eax: (addr array int) <- lookup *data-ah
  var result-addr/eax: (addr int) <- index data, top
  var val/eax: int <- copy *result-addr
  return val
}

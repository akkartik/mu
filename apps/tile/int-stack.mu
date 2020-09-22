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

fn clear-int-stack _self: (addr int-stack) {
  var self/esi: (addr int-stack) <- copy _self
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

fn pop-int-stack _self: (addr int-stack) -> val/eax: int {
$pop-int-stack:body: {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    val <- copy 0
    break $pop-int-stack:body
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array int) <- get self, data
  var data/eax: (addr array int) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var result-addr/eax: (addr int) <- index data, top
  val <- copy *result-addr
}
}

fn int-stack-empty? _self: (addr int-stack) -> result/eax: boolean {
$int-stack-empty?:body: {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  compare *top-addr, 0
  {
    break-if-!=
    result <- copy 1  # true
    break $int-stack-empty?:body
  }
  result <- copy 0  # false
}
}

fn int-stack-length _self: (addr int-stack) -> result/eax: int {
  var self/esi: (addr int-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  result <- copy *top-addr
}

fn max-stack-value _self: (addr int-stack) -> result/eax: int {
  var self/esi: (addr int-stack) <- copy _self
  var data-ah/edi: (addr handle array int) <- get self, data
  var _data/eax: (addr array int) <- lookup *data-ah
  var data/edi: (addr array int) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  result <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr int) <- index data, i
    compare *g, result
    {
      break-if-<=
      result <- copy *g
    }
    i <- increment
    loop
  }
}

type value-stack {
  data: (handle array value)
  top: int
}

fn initialize-value-stack _self: (addr value-stack), n: int {
  var self/esi: (addr value-stack) <- copy _self
  var d/edi: (addr handle array value) <- get self, data
  populate d, n
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn clear-value-stack _self: (addr value-stack) {
  var self/esi: (addr value-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  copy-to *top, 0
}

fn push-value-stack _self: (addr value-stack), _val: value {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var val/eax: value <- copy _val
  copy-to *dest-addr, val
  add-to *top-addr, 1
}

fn pop-value-stack _self: (addr value-stack) -> val/eax: value {
$pop-value-stack:body: {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    val <- copy -1
    break $pop-value-stack:body
  }
  subtract-from *top-addr, 1
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var result-addr/eax: (addr value) <- index data, dest-offset
  val <- copy *result-addr
}
}

fn value-stack-empty? _self: (addr value-stack) -> result/eax: boolean {
$value-stack-empty?:body: {
  var self/esi: (addr value-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-=
    result <- copy 1  # false
    break $value-stack-empty?:body
  }
  result <- copy 0  # false
}
}

fn value-stack-length _self: (addr value-stack) -> result/eax: int {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  result <- copy *top-addr
}

# value stacks encode the result of a program at a single point in time
# they are typically rendered vertically

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

fn push-number-to-value-stack _self: (addr value-stack), _val: float {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr float) <- get dest-addr, number-data
  var val/xmm0: float <- copy _val
  copy-to *dest-addr2, val
  increment *top-addr
  var type-addr/eax: (addr int) <- get dest-addr, type
  copy-to *type-addr, 0/number
}

fn push-int-to-value-stack _self: (addr value-stack), _val: int {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr float) <- get dest-addr, number-data
  var val/xmm0: float <- convert _val
  copy-to *dest-addr2, val
  increment *top-addr
  var type-addr/eax: (addr int) <- get dest-addr, type
  copy-to *type-addr, 0/number
}

fn push-string-to-value-stack _self: (addr value-stack), val: (handle array byte) {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr handle array byte) <- get dest-addr, text-data
  copy-handle val, dest-addr2
  var dest-addr3/eax: (addr int) <- get dest-addr, type
  copy-to *dest-addr3, 1/string
  increment *top-addr
}

fn push-array-to-value-stack _self: (addr value-stack), val: (handle array value) {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr handle array value) <- get dest-addr, array-data
  copy-handle val, dest-addr2
  # update type
  var dest-addr3/eax: (addr int) <- get dest-addr, type
  copy-to *dest-addr3, 2/array
  increment *top-addr
}

fn push-boolean-to-value-stack _self: (addr value-stack), _val: boolean {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr boolean) <- get dest-addr, boolean-data
  var val/esi: boolean <- copy _val
  copy-to *dest-addr2, val
  increment *top-addr
  var type-addr/eax: (addr int) <- get dest-addr, type
  copy-to *type-addr, 3/boolean
}

fn push-value-stack _self: (addr value-stack), val: (addr value) {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  copy-object val, dest-addr
  increment *top-addr
}

fn pop-number-from-value-stack _self: (addr value-stack) -> _/xmm0: float {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    abort "pop number: empty stack"
  }
  decrement *top-addr
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var result-addr/eax: (addr value) <- index data, dest-offset
  var result-addr2/eax: (addr float) <- get result-addr, number-data
  return *result-addr2
}

fn pop-boolean-from-value-stack _self: (addr value-stack) -> _/eax: boolean {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    abort "pop boolean: empty stack"
  }
  decrement *top-addr
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var result-addr/eax: (addr value) <- index data, dest-offset
  var result-addr2/eax: (addr boolean) <- get result-addr, boolean-data
  return *result-addr2
}

fn value-stack-empty? _self: (addr value-stack) -> _/eax: boolean {
  var self/esi: (addr value-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn value-stack-length _self: (addr value-stack) -> _/eax: int {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  return *top-addr
}

fn test-boolean {
  var stack-storage: value-stack
  var stack/esi: (addr value-stack) <- address stack-storage
  push-boolean-to-value-stack stack, 0/false
  var result/eax: boolean <- pop-boolean-from-value-stack stack
  check-not result, "F - test-boolean/false"
  push-boolean-to-value-stack stack, 1/true
  var result/eax: boolean <- pop-boolean-from-value-stack stack
  check result, "F - test-boolean/true"
}

fn dump-stack _self: (addr value-stack) {
  var self/esi: (addr value-stack) <- copy _self
  var data-ah/eax: (addr handle array value) <- get self, data
  var _data/eax: (addr array value) <- lookup *data-ah
  var data/edi: (addr array value) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var top/ecx: int <- copy *top-addr
  top <- decrement
  var y/edx: int <- copy 0xa
  var dummy/eax: int <- draw-text-rightward-over-full-screen 0/screen, "==", 0/x, 9/y, 0xc/red, 0/bg
  {
    compare top, 0
    break-if-<
    var dest-offset/eax: (offset value) <- compute-offset data, top
    var curr/eax: (addr value) <- index data, dest-offset
    var dummy/eax: int <- render-value 0/screen, curr, 0/x, y, 0/no-color
    top <- decrement
    y <- increment
    loop
  }
}

fn render-value-stack screen: (addr screen), _self: (addr value-stack), x: int, y: int -> _/eax: int, _/ecx: int {
  var self/ecx: (addr value-stack) <- copy _self
  var data-ah/eax: (addr handle array value) <- get self, data
  var _data/eax: (addr array value) <- lookup *data-ah
  var data/edi: (addr array value) <- copy _data
  var top-addr/eax: (addr int) <- get self, top
  var curr-idx/ecx: int <- copy *top-addr
  curr-idx <- decrement
  var new-x/edx: int <- copy 0
  {
    compare curr-idx, 0
    break-if-<
    var dest-offset/eax: (offset value) <- compute-offset data, curr-idx
    var curr/eax: (addr value) <- index data, dest-offset
    var curr-x/eax: int <- render-value screen, curr, x, y, 1/top-level
    {
      compare curr-x, new-x
      break-if-<=
      new-x <- copy curr-x
    }
    curr-idx <- decrement
    increment y
    loop
  }
  return new-x, y
}

fn test-render-value-stack {
  var stack-storage: value-stack
  var stack/esi: (addr value-stack) <- address stack-storage
  push-int-to-value-stack stack, 3
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 4
  #
  var final-x/eax: int <- copy 0
  var final-y/ecx: int <- copy 0
  final-x, final-y <- render-value-stack screen, stack, 0/x, 0/y
  check-ints-equal final-y, 1, "F - test-render-value-stack y"
  check-ints-equal final-x, 3, "F - test-render-value-stack x"
}

# support for non-int values is untested

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
#?   print-float-decimal-approximate 0, val, 3
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
#?   print-string 0, "setting type to 1: "
#?   {
#?     var foo/eax: int <- copy dest-addr3
#?     print-int32-hex 0, foo
#?   }
#?   print-string 0, "\n"
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
    var minus-one/eax: int <- copy -1
    var minus-one-f/xmm0: float <- convert minus-one
    return minus-one-f
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

fn save-lines in-h: (handle array (handle array byte)), _out-ah: (addr handle array value) {
  var _in/eax: (addr array (handle array byte)) <- lookup in-h
  var in/esi: (addr array (handle array byte)) <- copy _in
  var len/ecx: int <- length in
  var out-ah/edi: (addr handle array value) <- copy _out-ah
  populate out-ah, len
  var out/eax: (addr array value) <- lookup *out-ah
  # copy in into out
  var i/ebx: int <- copy 0
  {
    compare i, len
    break-if->=
#?     print-int32-hex 0, i
#?     print-string 0, "\n"
    var src/ecx: (addr handle array byte) <- index in, i
    var dest-offset/edx: (offset value) <- compute-offset out, i
    var dest-val/edx: (addr value) <- index out, dest-offset
    var dest/eax: (addr handle array byte) <- get dest-val, text-data
    copy-object src, dest
    var type/edx: (addr int) <- get dest-val, type
    copy-to *type, 1/string
    i <- increment
    loop
  }
}

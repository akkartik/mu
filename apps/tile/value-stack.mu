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

fn push-int-to-value-stack _self: (addr value-stack), _val: int {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr int) <- get dest-addr, int-data
  var val/esi: int <- copy _val
#?   print-int32-hex-to-real-screen val
  copy-to *dest-addr2, val
  increment *top-addr
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
  copy-to *dest-addr3, 1  # type string
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
  copy-to *dest-addr3, 2  # type array
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

fn pop-int-from-value-stack _self: (addr value-stack) -> _/eax: int {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    return -1
  }
  decrement *top-addr
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var result-addr/eax: (addr value) <- index data, dest-offset
  var result-addr2/eax: (addr int) <- get result-addr, int-data
  return *result-addr2
}

fn value-stack-empty? _self: (addr value-stack) -> _/eax: boolean {
  var self/esi: (addr value-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-!=
    return 1  # true
  }
  return 0  # false
}

fn value-stack-length _self: (addr value-stack) -> _/eax: int {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/eax: (addr int) <- get self, top
  return *top-addr
}

fn value-stack-max-width _self: (addr value-stack) -> _/eax: int {
  var self/esi: (addr value-stack) <- copy _self
  var data-ah/edi: (addr handle array value) <- get self, data
  var _data/eax: (addr array value) <- lookup *data-ah
  var data/edi: (addr array value) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  var result: int
  {
    compare i, *top-addr
    break-if->=
    var o/edx: (offset value) <- compute-offset data, i
    var v/edx: (addr value) <- index data, o
    var w/eax: int <- value-width v, 1  # top-level=true
    # if (w > result) w = result
    {
      compare w, result
      break-if-<=
      copy-to result, w
    }
    i <- increment
    loop
  }
  return result
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
    copy-to *type, 1  # string
    i <- increment
    loop
  }
}

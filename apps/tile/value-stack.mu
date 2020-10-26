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

fn push-array-to-value-stack _self: (addr value-stack), val: (handle array int) {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var dest-addr/edx: (addr value) <- index data, dest-offset
  var dest-addr2/eax: (addr handle array int) <- get dest-addr, array-data
  copy-handle val, dest-addr2
  var dest-addr3/eax: (addr int) <- get dest-addr, type
#?   print-string 0, "setting type to 1: "
#?   {
#?     var foo/eax: int <- copy dest-addr3
#?     print-int32-hex 0, foo
#?   }
#?   print-string 0, "\n"
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

fn pop-int-from-value-stack _self: (addr value-stack) -> val/eax: int {
$pop-int-from-value-stack:body: {
  var self/esi: (addr value-stack) <- copy _self
  var top-addr/ecx: (addr int) <- get self, top
  {
    compare *top-addr, 0
    break-if->
    val <- copy -1
    break $pop-int-from-value-stack:body
  }
  decrement *top-addr
  var data-ah/edx: (addr handle array value) <- get self, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var result-addr/eax: (addr value) <- index data, dest-offset
  var result-addr2/eax: (addr int) <- get result-addr, int-data
  val <- copy *result-addr2
}
}

fn value-stack-empty? _self: (addr value-stack) -> result/eax: boolean {
$value-stack-empty?:body: {
  var self/esi: (addr value-stack) <- copy _self
  var top/eax: (addr int) <- get self, top
  compare *top, 0
  {
    break-if-!=
    result <- copy 1  # true
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

fn value-stack-max-width _self: (addr value-stack) -> result/eax: int {
  var self/esi: (addr value-stack) <- copy _self
  var data-ah/edi: (addr handle array value) <- get self, data
  var _data/eax: (addr array value) <- lookup *data-ah
  var data/edi: (addr array value) <- copy _data
  var top-addr/ecx: (addr int) <- get self, top
  var i/ebx: int <- copy 0
  var out: int
  {
    compare i, *top-addr
    break-if->=
    var o/edx: (offset value) <- compute-offset data, i
    var g/edx: (addr value) <- index data, o
    var type/eax: (addr int) <- get g, type
    {
      compare *type, 0  # int
      break-if-!=
      var g2/edx: (addr int) <- get g, int-data
      var w/eax: int <- decimal-size *g2
      compare w, out
      break-if-<=
      copy-to out, w
    }
    {
      compare *type, 1  # string
      break-if-!=
      var s-ah/eax: (addr handle array byte) <- get g, text-data
      var s/eax: (addr array byte) <- lookup *s-ah
      compare s, 0
      break-if-=
      var w/eax: int <- length s
      compare w, out
      break-if-<=
      copy-to out, w
    }
    {
      compare *type, 2  # array
      break-if-!=
      var a-ah/eax: (addr handle array int) <- get g, array-data
      var a/eax: (addr array int) <- lookup *a-ah
      compare a, 0
      break-if-=
      var w/eax: int <- array-decimal-size a
      compare w, out
      break-if-<=
      copy-to out, w
    }
    i <- increment
    loop
  }
  result <- copy out
}

# keep sync'd with print-array-of-ints
fn array-decimal-size _a: (addr array int) -> result/eax: int {
  var a/esi: (addr array int) <- copy _a
  var max/ecx: int <- length a
  var i/eax: int <- copy 0
  var out/edi: int <- copy 0
  {
    compare i, max
    break-if->=
    {
      compare i, 0
      break-if-=
      out <- increment  # for space
    }
    var x/ecx: (addr int) <- index a, i
    {
      var w/eax: int <- decimal-size *x
      out <- add w
    }
    i <- increment
    loop
  }
  result <- copy out
  # we won't add 2 for surrounding brackets since we don't surround arrays in
  # spaces like other value types
}

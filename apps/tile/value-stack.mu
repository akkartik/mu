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
    var v/edx: (addr value) <- index data, o
    var w/eax: int <- value-width v
    # if (w > out) w = out
    {
      compare w, out
      break-if-<=
      copy-to out, w
    }
    i <- increment
    loop
  }
  result <- copy out
}

fn value-width _v: (addr value) -> result/eax: int {
  var out/edi: int <- copy 0
  $value-width:body: {
    var v/esi: (addr value) <- copy _v
    var type/eax: (addr int) <- get v, type
    {
      compare *type, 0  # int
      break-if-!=
      var v-int/edx: (addr int) <- get v, int-data
      var _out/eax: int <- decimal-size *v-int
      out <- copy _out
      break $value-width:body
    }
    {
      compare *type, 1  # string
      break-if-!=
      var s-ah/eax: (addr handle array byte) <- get v, text-data
      var s/eax: (addr array byte) <- lookup *s-ah
      compare s, 0
      break-if-=
      var _out/eax: int <- length s
      out <- copy _out
      break $value-width:body
    }
    {
      compare *type, 2  # array
      break-if-!=
      var a-ah/eax: (addr handle array value) <- get v, array-data
      var a/eax: (addr array value) <- lookup *a-ah
      compare a, 0
      break-if-=
      var _out/eax: int <- array-width a
      out <- copy _out
      break $value-width:body
    }
    {
      compare *type, 3  # file handle
      break-if-!=
      var f-ah/eax: (addr handle buffered-file) <- get v, file-data
      var f/eax: (addr buffered-file) <- lookup *f-ah
      compare f, 0
      break-if-=
      # TODO
      out <- copy 4
      break $value-width:body
    }
  }
  result <- copy out
}

# keep sync'd with render-array
fn array-width _a: (addr array value) -> result/eax: int {
  var a/esi: (addr array value) <- copy _a
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
    var off/ecx: (offset value) <- compute-offset a, i
    var x/ecx: (addr value) <- index a, off
    {
      var w/eax: int <- value-width x
      out <- add w
    }
    i <- increment
    loop
  }
  result <- copy out
  # we won't add 2 for surrounding brackets since we don't surround arrays in
  # spaces like other value types
}

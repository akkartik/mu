fn initialize-table _self: (addr table), n: int {
  var self/esi: (addr table) <- copy _self
  var data-ah/eax: (addr handle array bind) <- get self, data
  populate data-ah, n
}

fn deep-copy-table _src: (addr table), _dest: (addr table) {
#?   print-string 0, "deep-copy-table\n"
  var src/eax: (addr table) <- copy _src
  var src-data-ah/eax: (addr handle array bind) <- get src, data
  var _src-data/eax: (addr array bind) <- lookup *src-data-ah
  var src-data/esi: (addr array bind) <- copy _src-data
  var n/ecx: int <- length src-data
  var dest/eax: (addr table) <- copy _dest
  initialize-table dest, n
  var dest-data-ah/eax: (addr handle array bind) <- get dest, data
  var _dest-data/eax: (addr array bind) <- lookup *dest-data-ah
  var dest-data/edi: (addr array bind) <- copy _dest-data
  var i/eax: int <- copy 0
  {
    compare i, n
    break-if->=
#?     print-string 0, "iter\n"
    $deep-copy:element: {
      var offset/edx: (offset bind) <- compute-offset src-data, i
      var src-bind/ecx: (addr bind) <- index src-data, offset
      var dest-bind/edx: (addr bind) <- index dest-data, offset
      var src-key-ah/ebx: (addr handle array byte) <- get src-bind, key
      var src-key/eax: (addr array byte) <- lookup *src-key-ah
      compare src-key, 0
      break-if-=
      # copy key
      var dest-key-ah/eax: (addr handle array byte) <- get dest-bind, key
      copy-object src-key-ah, dest-key-ah
      # deep copy value
      var src-val-ah/eax: (addr handle value) <- get src-bind, value
      var _src-val/eax: (addr value) <- lookup *src-val-ah
      var src-val/ecx: (addr value) <- copy _src-val
      var dest-val-ah/eax: (addr handle value) <- get dest-bind, value
      allocate dest-val-ah
      var dest-val/eax: (addr value) <- lookup *dest-val-ah
#?       print-string 0, "deep copy value {\n"
      deep-copy-value src-val, dest-val
#?       print-string 0, "}\n"
    }
    i <- increment
    loop
  }
#?   print-string 0, "end deep-copy-table\n"
}

fn bind-in-table _self: (addr table), key: (addr handle array byte), val: (addr value) {
  var self/esi: (addr table) <- copy _self
  var data-ah/esi: (addr handle array bind) <- get self, data
  var _data/eax: (addr array bind) <- lookup *data-ah
  var data/esi: (addr array bind) <- copy _data
  var next-empty-slot-index/eax: (offset bind) <- next-empty-slot data, key
  var dest/eax: (addr bind) <- index data, next-empty-slot-index
  make-binding dest, key, val
}

# manual test: full array of binds
fn next-empty-slot _data: (addr array bind), key: (addr handle array byte) -> _/eax: (offset bind) {
  var data/esi: (addr array bind) <- copy _data
  var len/ecx: int <- length data
  var i/edx: int <- copy 0
  var result/eax: (offset bind) <- copy 0
  $next-empty-slot:loop: {
    result <- compute-offset data, i
    compare i, len
    break-if->=
    {
      var target/esi: (addr bind) <- index data, result
      var target2/esi: (addr handle array byte) <- get target, key
      var target3/eax: (addr array byte) <- lookup *target2
      compare target3, 0
      break-if-= $next-empty-slot:loop
      # TODO: how to indicate that key already exists? we don't want to permit rebinding
    }
    i <- increment
    loop
  }
  return result
}

fn make-number-binding _self: (addr bind), key: (addr handle array byte), _val: float {
  var self/esi: (addr bind) <- copy _self
  var dest/eax: (addr handle array byte) <- get self, key
  copy-object key, dest
  var dest2/eax: (addr handle value) <- get self, value
  allocate dest2
  var dest3/eax: (addr value) <- lookup *dest2
  var dest4/eax: (addr float) <- get dest3, number-data
  var val/xmm0: float <- copy _val
  copy-to *dest4, val
}

fn make-binding _self: (addr bind), key: (addr handle array byte), val: (addr value) {
  var self/esi: (addr bind) <- copy _self
  var dest/eax: (addr handle array byte) <- get self, key
  copy-object key, dest
  var dest2/eax: (addr handle value) <- get self, value
  allocate dest2
  var dest3/eax: (addr value) <- lookup *dest2
  copy-object val, dest3
}

fn lookup-binding _self: (addr table), key: (addr array byte), out: (addr handle value) {
  var self/esi: (addr table) <- copy _self
  var data-ah/esi: (addr handle array bind) <- get self, data
  var _data/eax: (addr array bind) <- lookup *data-ah
  var data/esi: (addr array bind) <- copy _data
  var len/edx: int <- length data
  var i/ebx: int <- copy 0
  $lookup-binding:loop: {
    compare i, len
    break-if->=
    {
      var offset/edx: (offset bind) <- compute-offset data, i
      var target-bind/esi: (addr bind) <- index data, offset
      var target2/edx: (addr handle array byte) <- get target-bind, key
      var target3/eax: (addr array byte) <- lookup *target2
      compare target3, 0
      break-if-= $lookup-binding:loop
      var is-match?/eax: boolean <- string-equal? target3, key
      compare is-match?, 0/false
      break-if-=
      # found
      var target/eax: (addr handle value) <- get target-bind, value
      copy-object target, out
      break $lookup-binding:loop
    }
    i <- increment
    loop
  }
}

fn dump-table _self: (addr table) {
  var self/esi: (addr table) <- copy _self
  var data-ah/esi: (addr handle array bind) <- get self, data
  var _data/eax: (addr array bind) <- lookup *data-ah
  var data/esi: (addr array bind) <- copy _data
  var len/edx: int <- length data
  var i/ebx: int <- copy 0
  {
    compare i, len
    break-if->=
    var offset/edx: (offset bind) <- compute-offset data, i
    var target-bind/esi: (addr bind) <- index data, offset
    var key-ah/edx: (addr handle array byte) <- get target-bind, key
    var key/eax: (addr array byte) <- lookup *key-ah
    compare key, 0
    break-if-=
    print-string 0, key
    print-string 0, ": "
    var val-ah/eax: (addr handle value) <- get target-bind, value
    var val/eax: (addr value) <- lookup *val-ah
    var type/eax: (addr int) <- get val, type
    print-int32-hex 0, *type
    print-string 0, "\n"
    i <- increment
    loop
  }
  print-string 0, "\n"
}

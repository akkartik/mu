fn initialize-table _self: (addr table), n: int {
  var self/esi: (addr table) <- copy _self
  var data-ah/eax: (addr handle array bind) <- get self, data
  populate data-ah, n
}

fn shallow-copy-table-values _src: (addr table), dest: (addr table) {
  var src/eax: (addr table) <- copy _src
#?   print-string 0, "before copy: "
#?   dump-table src
  var src-data-ah/eax: (addr handle array bind) <- get src, data
  var _src-data/eax: (addr array bind) <- lookup *src-data-ah
  var src-data/esi: (addr array bind) <- copy _src-data
  var n/ecx: int <- length src-data
  initialize-table dest, n
  var i/eax: int <- copy 0
  {
    compare i, n
    break-if->=
    {
      var offset/edx: (offset bind) <- compute-offset src-data, i
      var src-bind/ecx: (addr bind) <- index src-data, offset
      var key-ah/ebx: (addr handle array byte) <- get src-bind, key
      var key/eax: (addr array byte) <- lookup *key-ah
      compare key, 0
      break-if-=
      var val-ah/eax: (addr handle value) <- get src-bind, value
      var val/eax: (addr value) <- lookup *val-ah
#?       {
#?         print-string-to-real-screen "before\n"
#?         var val2/ecx: (addr value) <- copy val
#?         var foo5/eax: (addr int) <- get val2, type
#?         print-int32-decimal-to-real-screen *foo5
#?         print-string-to-real-screen ": "
#?         var foo6/eax: (addr int) <- get val2, int-data
#?         print-int32-decimal-to-real-screen *foo6
#?         var foo7/eax: (addr handle array byte) <- get val2, text-data
#?         var foo8/eax: (addr array byte) <- lookup *foo7
#?         var foo9/eax: int <- copy foo8
#?         print-int32-decimal-to-real-screen foo9
#?         var foo10/eax: (addr handle array value) <- get val2, array-data
#?         var foo11/eax: (addr array value) <- lookup *foo10
#?         var foo12/eax: int <- copy foo11
#?         print-int32-decimal-to-real-screen foo12
#?         var foo13/eax: (addr handle buffered-file) <- get val2, file-data
#?         var foo14/eax: (addr buffered-file) <- lookup *foo13
#?         var foo15/eax: int <- copy foo14
#?         print-int32-decimal-to-real-screen foo15
#?         var foo16/eax: (addr handle screen) <- get val2, screen-data
#?         var foo17/eax: (addr screen) <- lookup *foo16
#?         var foo18/eax: int <- copy foo17
#?         print-int32-decimal-to-real-screen foo18
#?         print-string-to-real-screen "\n"
#?       }
      bind-in-table dest, key-ah, val
      var foo: (handle value)
      var foo2/ecx: (addr handle value) <- address foo
      var foo3/eax: (addr array byte) <- lookup *key-ah
      print-string-to-real-screen foo3
      print-string-to-real-screen " -> "
      lookup-binding dest, foo3, foo2
      var _foo4/eax: (addr value) <- lookup *foo2
      var foo4/ecx: (addr value) <- copy _foo4
      var foo5/eax: (addr int) <- get foo4, type
      print-int32-hex-to-real-screen *foo5
      print-string-to-real-screen ": "
      var foo6/eax: (addr int) <- get foo4, int-data
      print-int32-hex-to-real-screen *foo6
      print-string-to-real-screen " "
      var foo7/eax: (addr handle array byte) <- get foo4, text-data
      var foo8/eax: (addr array byte) <- lookup *foo7
      var foo9/eax: int <- copy foo8
      print-int32-hex-to-real-screen foo9
      print-string-to-real-screen " "
      var foo10/eax: (addr handle array value) <- get foo4, array-data
      var foo11/eax: (addr array value) <- lookup *foo10
      var foo12/eax: int <- copy foo11
      print-int32-hex-to-real-screen foo12
      print-string-to-real-screen " "
      var foo10/eax: (addr handle array value) <- get foo4, array-data
      var foo13/eax: (addr handle buffered-file) <- get foo4, file-data
      var foo14/eax: (addr buffered-file) <- lookup *foo13
      var foo15/eax: int <- copy foo14
      print-int32-hex-to-real-screen foo15
      print-string-to-real-screen " "
      var foo10/eax: (addr handle array value) <- get foo4, array-data
      var foo16/eax: (addr handle screen) <- get foo4, screen-data
      var foo17/eax: (addr screen) <- lookup *foo16
      var foo18/eax: int <- copy foo17
      print-int32-hex-to-real-screen foo18
      print-string-to-real-screen "\n"
    }
    i <- increment
    loop
  }
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

fn make-int-binding _self: (addr bind), key: (addr handle array byte), _val: int {
  var self/esi: (addr bind) <- copy _self
  var dest/eax: (addr handle array byte) <- get self, key
  copy-object key, dest
  var dest2/eax: (addr handle value) <- get self, value
  allocate dest2
  var dest3/eax: (addr value) <- lookup *dest2
  var dest4/eax: (addr int) <- get dest3, int-data
  var val/ecx: int <- copy _val
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
      compare is-match?, 0  # false
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

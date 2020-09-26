fn initialize-table _self: (address table) {
  var self/esi: (addr table) <- copy _self
  var data-ah/eax: (addr handle array bind) <- get self, data
  populate data-ah, 0x10
}

fn bind-int-in-table _self: (addr table), key: (addr array byte), val: int {
  var self/esi: (addr table) <- copy _self
  var data-ah/esi: (addr handle array bind) <- get self, data
  var _data/eax: (addr array bind) <- lookup *data-ah
  var data/esi: (addr array bind) <- copy _data
  var next-empty-slot-index/eax: (offset bind) <- next-empty-slot data, key
  var dest/eax: (addr bind) <- index data, next-empty-slot-index
  make-binding dest, key, val
}

# manual test: full array of binds
fn next-empty-slot _data: (addr array bind), key: (addr array byte) -> result/eax: (offset bind) {
  var data/esi: (addr array bind) <- copy _data
  var len/ecx: int <- length data
  var i/edx: int <- copy 0
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
}

fn make-binding _self: (addr bind), key: (addr array byte), _val: int {
  var self/esi: (addr bind) <- copy _self
  var dest/eax: (addr handle array byte) <- get self, key
  populate-text-with dest, key
  var dest2/eax: (addr value) <- get self, value
  var dest3/eax: (addr int) <- get dest2, scalar-data
  var val/ecx: int <- copy _val
  copy-to *dest3, val
}

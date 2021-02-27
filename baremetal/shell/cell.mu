type cell {
  type: int
  # type 0: pair
  left: (handle cell)
  right: (handle cell)
  # type 1: number
  number-data: float
  # type 2: symbol
  # type 3: string
  text-data: (handle stream byte)
  # TODO: array, (associative) table, stream
}

fn new-symbol _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 2/symbol
  var dest-ah/eax: (addr handle stream byte) <- get out-addr, text-data
  populate-stream dest-ah, 0x40/max-symbol-size
}

fn new-number _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 1/number
}

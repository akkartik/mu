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
  # type 4: primitive function
  index-data: int
  # TODO: array, (associative) table, stream
}

fn allocate-symbol _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 2/symbol
  var dest-ah/eax: (addr handle stream byte) <- get out-addr, text-data
  populate-stream dest-ah, 0x40/max-symbol-size
}

fn initialize-symbol _out: (addr handle cell), val: (addr array byte) {
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-ah/eax: (addr handle stream byte) <- get out-addr, text-data
  var dest/eax: (addr stream byte) <- lookup *dest-ah
  write dest, val
}

fn new-symbol out: (addr handle cell), val: (addr array byte) {
  allocate-symbol out
  initialize-symbol out, val
}

fn allocate-number _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 1/number
}

fn initialize-integer _out: (addr handle cell), n: int {
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-addr/eax: (addr float) <- get out-addr, number-data
  var src/xmm0: float <- convert n
  copy-to *dest-addr, src
}

fn new-integer out: (addr handle cell), n: int {
  allocate-number out
  initialize-integer out, n
}

fn initialize-float _out: (addr handle cell), n: float {
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-ah/eax: (addr float) <- get out-addr, number-data
  var src/xmm0: float <- copy n
  copy-to *dest-ah, src
}

fn new-float out: (addr handle cell), n: float {
  allocate-number out
  initialize-float out, n
}

fn allocate-pair _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  # new cells have type pair by default
}

fn initialize-pair _out: (addr handle cell), left: (handle cell), right: (handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-ah/ecx: (addr handle cell) <- get out-addr, left
  copy-handle left, dest-ah
  dest-ah <- get out-addr, right
  copy-handle right, dest-ah
}

fn new-pair out: (addr handle cell), left: (handle cell), right: (handle cell) {
  allocate-pair out
  initialize-pair out, left, right
}

fn allocate-primitive-function _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 4/primitive-function
}

fn initialize-primitive-function _out: (addr handle cell), n: int {
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-addr/eax: (addr int) <- get out-addr, index-data
  var src/ecx: int <- copy n
  copy-to *dest-addr, src
}

fn new-primitive-function out: (addr handle cell), n: int {
  allocate-primitive-function out
  initialize-primitive-function out, n
}

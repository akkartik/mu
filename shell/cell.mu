type cell {
  type: int
  # type 0: pair; the unit of lists, trees, DAGS or graphs
  left: (handle cell)
  right: (handle cell)
  # type 1: number
  number-data: float
  # type 2: symbol
  # type 3: stream
  text-data: (handle stream byte)
  # type 4: primitive function
  index-data: int
  # type 5: screen
  screen-data: (handle screen)
  # type 6: keyboard
  keyboard-data: (handle gap-buffer)
  # TODO: array, (associative) table
  # if you add types here, don't forget to update cell-isomorphic?
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

fn symbol-equal? _in: (addr cell), name: (addr array byte) -> _/eax: boolean {
  var in/esi: (addr cell) <- copy _in
  var in-type/eax: (addr int) <- get in, type
  compare *in-type, 2/symbol
  {
    break-if-=
    return 0/false
  }
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  var result/eax: boolean <- stream-data-equal? in-data, name
  return result
}

fn allocate-stream _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 3/stream
  var dest-ah/eax: (addr handle stream byte) <- get out-addr, text-data
  populate-stream dest-ah, 0x40/max-stream-size
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

fn allocate-pair out: (addr handle cell) {
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

fn nil out: (addr handle cell) {
  allocate-pair out
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

fn allocate-screen _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 5/screen
}

fn new-fake-screen _out: (addr handle cell), width: int, height: int, pixel-graphics?: boolean {
  var out/eax: (addr handle cell) <- copy _out
  allocate-screen out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-ah/eax: (addr handle screen) <- get out-addr, screen-data
  allocate dest-ah
  var dest-addr/eax: (addr screen) <- lookup *dest-ah
  initialize-screen dest-addr, width, height, pixel-graphics?
}

fn clear-screen-cell _self-ah: (addr handle cell) {
  var self-ah/eax: (addr handle cell) <- copy _self-ah
  var self/eax: (addr cell) <- lookup *self-ah
  compare self, 0
  {
    break-if-!=
    return
  }
  var screen-ah/eax: (addr handle screen) <- get self, screen-data
  var screen/eax: (addr screen) <- lookup *screen-ah
  clear-screen screen
}

fn allocate-keyboard _out: (addr handle cell) {
  var out/eax: (addr handle cell) <- copy _out
  allocate out
  var out-addr/eax: (addr cell) <- lookup *out
  var type/ecx: (addr int) <- get out-addr, type
  copy-to *type, 6/keyboard
}

fn new-fake-keyboard _out: (addr handle cell), capacity: int {
  var out/eax: (addr handle cell) <- copy _out
  allocate-keyboard out
  var out-addr/eax: (addr cell) <- lookup *out
  var dest-ah/eax: (addr handle gap-buffer) <- get out-addr, keyboard-data
  allocate dest-ah
  var dest-addr/eax: (addr gap-buffer) <- lookup *dest-ah
  initialize-gap-buffer dest-addr, capacity
}

fn rewind-keyboard-cell _self-ah: (addr handle cell) {
  var self-ah/eax: (addr handle cell) <- copy _self-ah
  var self/eax: (addr cell) <- lookup *self-ah
  compare self, 0
  {
    break-if-!=
    return
  }
  var keyboard-ah/eax: (addr handle gap-buffer) <- get self, keyboard-data
  var keyboard/eax: (addr gap-buffer) <- lookup *keyboard-ah
  rewind-gap-buffer keyboard
}

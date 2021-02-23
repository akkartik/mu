type sandbox {
  data: (handle gap-buffer)
  value: (handle stream byte)
  trace: (handle trace)
}

fn initialize-sandbox _self: (addr sandbox) {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data, 0x1000/4KB
  var value-ah/eax: (addr handle stream byte) <- get self, value
  populate-stream value-ah, 0x1000/4KB
  var trace-ah/eax: (addr handle trace) <- get self, trace
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 0x100/lines
}

## some helpers for tests

fn initialize-sandbox-with _self: (addr sandbox), s: (addr array byte) {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer-with data, s
}

fn allocate-sandbox-with _out: (addr handle sandbox), s: (addr array byte) {
  var out/eax: (addr handle sandbox) <- copy _out
  allocate out
  var out-addr/eax: (addr sandbox) <- lookup *out
  initialize-sandbox-with out-addr, s
}

fn add-grapheme-to-sandbox _self: (addr sandbox), c: grapheme {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  add-grapheme-at-gap data, c
}

fn delete-grapheme-before-cursor _self: (addr sandbox) {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  delete-before-gap data
}

fn render-sandbox screen: (addr screen), _self: (addr sandbox), _x: int, _y: int {
  clear-screen screen
  var self/esi: (addr sandbox) <- copy _self
  # data
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/edx: (addr gap-buffer) <- copy _data
  var x/eax: int <- copy _x
  var y/ecx: int <- copy _y
  x, y <- render-gap-buffer-wrapping-right-then-down screen, data, x, y, 0x20/xmax, 0x20/ymax, x, y, 1/show-cursor
  y <- increment
  # trace
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  y <- render-trace screen, trace, _x, y, 0x20/xmax, 0x20/ymax
  # value
  var value-ah/eax: (addr handle stream byte) <- get self, value
  var _value/eax: (addr stream byte) <- lookup *value-ah
  var value/esi: (addr stream byte) <- copy _value
  var done?/eax: boolean <- stream-empty? value
  compare done?, 0/false
  {
    break-if-=
    return
  }
  var x/eax: int <- copy 0
  x, y <- draw-text-wrapping-right-then-down screen, "=> ", _x, y, 0x20/xmax, 0x20/ymax, _x, y, 7/fg, 0/bg
  var x2/edx: int <- copy x
  var dummy/eax: int <- draw-stream-rightward screen, value, x2, 0x30/xmax, y, 7/fg=grey, 0/bg
}

fn edit-sandbox _self: (addr sandbox), key: byte {
  var self/esi: (addr sandbox) <- copy _self
  var g/edx: grapheme <- copy key
  {
    compare g, 8/backspace
    break-if-!=
    delete-grapheme-before-cursor self
    return
  }
  {
    compare g, 0x12/ctrl-r
    break-if-!=
    # ctrl-r: run function outside sandbox
    # required: fn (addr screen), (addr keyboard)
    # Mu will pass in the real screen and keyboard.
    return
  }
  {
    compare g, 0x13/ctrl-s
    break-if-!=
    # ctrl-s: run sandbox(es)
    var data-ah/eax: (addr handle gap-buffer) <- get self, data
    var _data/eax: (addr gap-buffer) <- lookup *data-ah
    var data/ecx: (addr gap-buffer) <- copy _data
    var value-ah/eax: (addr handle stream byte) <- get self, value
    var _value/eax: (addr stream byte) <- lookup *value-ah
    var value/edx: (addr stream byte) <- copy _value
    var trace-ah/eax: (addr handle trace) <- get self, trace
    var trace/eax: (addr trace) <- lookup *trace-ah
    clear-trace trace
    run data, value, trace
    return
  }
  add-grapheme-to-sandbox self, g
}

fn run in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  var read-result-storage: (handle cell)
  var read-result/esi: (addr handle cell) <- address read-result-storage
  read-cell in, read-result, trace
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  # TODO: eval
  print-cell read-result, out
}

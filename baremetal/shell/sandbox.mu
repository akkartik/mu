type sandbox {
  data: (handle gap-buffer)
  value: (handle stream byte)
  trace: (handle trace)
  cursor-in-trace?: boolean
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
  var cursor-in-sandbox?/ebx: boolean <- copy 0/false
  {
    var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
    compare *cursor-in-trace?, 0/false
    break-if-!=
    cursor-in-sandbox? <- copy 1/true
  }
  x, y <- render-gap-buffer-wrapping-right-then-down screen, data, x, y, 0x20/xmax, 0x20/ymax, x, y, cursor-in-sandbox?
  y <- increment
  # trace
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  y <- render-trace screen, trace, _x, y, 0x20/xmax, 0x20/ymax, *cursor-in-trace?
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
  # running code
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
  # arrow keys
  {
    compare g, 0x4/ctrl-d
    break-if-!=
    # ctrl-d: cursor down (into trace if it makes sense)
    var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
    # if cursor in input, check if we need to switch to trace
    {
      compare *cursor-in-trace?, 0/false
      break-if-!=
      var data-ah/eax: (addr handle gap-buffer) <- get self, data
      var data/eax: (addr gap-buffer) <- lookup *data-ah
      var at-bottom?/eax: boolean <- cursor-on-final-line? data
      compare at-bottom?, 0/false
      break-if-=
      var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
      copy-to *cursor-in-trace?, 1/true
      return
    }
    # if cursor in trace, send cursor to trace
    {
      compare cursor-in-trace?, 0/false
      break-if-=
      var trace-ah/eax: (addr handle trace) <- get self, trace
      var trace/eax: (addr trace) <- lookup *trace-ah
      edit-trace trace, g
      return
    }
    # otherwise send cursor to input
    var data-ah/eax: (addr handle gap-buffer) <- get self, data
    var data/eax: (addr gap-buffer) <- lookup *data-ah
    edit-gap-buffer data, g
    return
  }
  # default: insert character
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

fn test-run-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "1"
  edit-sandbox sandbox, 0x31/1
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  render-sandbox screen, sandbox, 0/x, 0/y
  check-screen-row screen, 0/y, "1    ", "F - test-run-integer/0"
  check-screen-row screen, 1/y, "...  ", "F - test-run-integer/1"
  check-screen-row screen, 2/y, "=> 1 ", "F - test-run-integer/2"
}

fn test-run-error-invalid-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "1a"
  edit-sandbox sandbox, 0x31/1
  edit-sandbox sandbox, 0x61/a
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10, 4
  #
  render-sandbox screen, sandbox, 0/x, 0/y
  check-screen-row screen, 0/y, "1a             ", "F - test-run-error-invalid-integer/0"
  check-screen-row screen, 1/y, "...            ", "F - test-run-error-invalid-integer/0"
  check-screen-row screen, 2/y, "invalid number ", "F - test-run-error-invalid-integer/2"
}

fn test-run-move-cursor-into-trace {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "12"
  edit-sandbox sandbox, 0x31/1
  edit-sandbox sandbox, 0x32/2
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10, 8
  #
  render-sandbox screen, sandbox, 0/x, 0/y
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/pre-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/pre-2/cursor"
  # move cursor down
  edit-sandbox sandbox, 4/ctrl-d
  #
  render-sandbox screen, sandbox, 0/x, 0/y
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-run-move-cursor-into-trace/0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||   ", "F - test-run-move-cursor-into-trace/1/cursor"
  check-screen-row screen,                                  2/y, "      ", "F - test-run-move-cursor-into-trace/2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/2/cursor"
}

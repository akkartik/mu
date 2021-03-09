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
  initialize-trace trace, 0x1000/lines, 0x80/visible-lines
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

##

fn render-sandbox screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int, xmax: int, ymax: int {
  clear-screen screen
  var self/esi: (addr sandbox) <- copy _self
  # data
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/edx: (addr gap-buffer) <- copy _data
  var x/eax: int <- copy xmin
  var y/ecx: int <- copy ymin
  var cursor-in-sandbox?/ebx: boolean <- copy 0/false
  {
    var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
    compare *cursor-in-trace?, 0/false
    break-if-!=
    cursor-in-sandbox? <- copy 1/true
  }
  x, y <- render-gap-buffer-wrapping-right-then-down screen, data, x, y, xmax, ymax, cursor-in-sandbox?
  y <- increment
  # trace
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  y <- render-trace screen, trace, xmin, y, xmax, ymax, *cursor-in-trace?
  # value
  $render-sandbox:value: {
    var value-ah/eax: (addr handle stream byte) <- get self, value
    var _value/eax: (addr stream byte) <- lookup *value-ah
    var value/esi: (addr stream byte) <- copy _value
    rewind-stream value
    var done?/eax: boolean <- stream-empty? value
    compare done?, 0/false
    break-if-!=
    var x/eax: int <- copy 0
    x, y <- draw-text-wrapping-right-then-down screen, "=> ", xmin, y, xmax, ymax, xmin, y, 7/fg, 0/bg
    var x2/edx: int <- copy x
    var dummy/eax: int <- draw-stream-rightward screen, value, x2, xmax, y, 7/fg=grey, 0/bg
  }
  # render menu
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  compare *cursor-in-trace?, 0/false
  {
    break-if-=
    render-trace-menu screen
    return
  }
  render-sandbox-menu screen
}

fn render-sandbox-menu screen: (addr screen) {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  var y/ecx: int <- copy height
  y <- decrement
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ctrl-s ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " tab ", width, 0/fg, 9/bg=blue
  draw-text-rightward-from-cursor screen, " move to trace  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-d ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " down  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-u ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " up  ", width, 7/fg, 0/bg
}

fn edit-sandbox _self: (addr sandbox), key: byte {
  var self/esi: (addr sandbox) <- copy _self
  var g/edx: grapheme <- copy key
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
  # tab
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  {
    compare g, 9/tab
    break-if-!=
    # if cursor in input, switch to trace
    {
      compare *cursor-in-trace?, 0/false
      break-if-!=
      copy-to *cursor-in-trace?, 1/true
      return
    }
    # if cursor in trace, switch to input
    copy-to *cursor-in-trace?, 0/false
    return
  }
  # if cursor in trace, send cursor to trace
  {
    compare *cursor-in-trace?, 0/false
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
  var nil-storage: (handle cell)
  var nil-ah/eax: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var eval-result-storage: (handle cell)
  var eval-result/edi: (addr handle cell) <- address eval-result-storage
  evaluate read-result, eval-result, *nil-ah, trace
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  clear-stream out
  print-cell eval-result, out, trace
  mark-lines-dirty trace
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
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height
  check-screen-row screen, 0/y, "1    ", "F - test-run-integer/0"
  check-screen-row screen, 1/y, "...  ", "F - test-run-integer/1"
  check-screen-row screen, 2/y, "=> 1 ", "F - test-run-integer/2"
}

fn test-run-with-spaces {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "1"
  edit-sandbox sandbox, 0x20/space
  edit-sandbox sandbox, 0x31/1
  edit-sandbox sandbox, 0x20/space
  edit-sandbox sandbox, 0xa/newline
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height
  check-screen-row screen, 0/y, " 1   ", "F - test-run-with-spaces/0"
  check-screen-row screen, 1/y, "     ", "F - test-run-with-spaces/1"
  check-screen-row screen, 2/y, "...  ", "F - test-run-with-spaces/2"
  check-screen-row screen, 3/y, "=> 1 ", "F - test-run-with-spaces/3"
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
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height
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
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/pre-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/pre-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 9/tab
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/trace-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-run-move-cursor-into-trace/trace-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/trace-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||   ", "F - test-run-move-cursor-into-trace/trace-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/trace-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/trace-2/cursor"
  # move cursor into input
  edit-sandbox sandbox, 9/tab
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/input-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/input-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/input-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/input-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/input-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/input-2/cursor"
}

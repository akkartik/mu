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

fn render-sandbox screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int, xmax: int, ymax: int, globals: (addr global-table) {
  clear-rect screen, xmin, ymin, xmax, ymax, 0/bg=black
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
  y <- maybe-render-screen screen, globals, xmin, y
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

fn maybe-render-screen screen: (addr screen), _globals: (addr global-table), xmin: int, ymin: int -> _/ecx: int {
  var globals/esi: (addr global-table) <- copy _globals
  var screen-literal-storage: (stream byte 8)
  var screen-literal/eax: (addr stream byte) <- address screen-literal-storage
  write screen-literal, "screen"
  var screen-obj-index/ecx: int <- find-symbol-in-globals globals, screen-literal
  compare screen-obj-index, -1/not-found
  {
    break-if-!=
    return ymin
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var screen-obj-offset/ecx: (offset global) <- compute-offset global-data, screen-obj-index
  var screen-global/eax: (addr global) <- index global-data, screen-obj-offset
  var screen-obj-cell-ah/eax: (addr handle cell) <- get screen-global, value
  var screen-obj-cell/eax: (addr cell) <- lookup *screen-obj-cell-ah
  var screen-obj-cell-type/ecx: (addr int) <- get screen-obj-cell, type
  compare *screen-obj-cell-type, 5/screen
  {
    break-if-=
    return ymin  # silently give up on rendering the screen
  }
  var screen-obj-ah/eax: (addr handle screen) <- get screen-obj-cell, screen-data
  var screen-obj/eax: (addr screen) <- lookup *screen-obj-ah
  {
    var screen-empty?/eax: boolean <- fake-screen-empty? screen-obj
    compare screen-empty?, 0/false
    break-if-=
    return ymin
  }
  var y/ecx: int <- copy ymin
  y <- add 2
  y <- render-screen screen, screen-obj, xmin, y
  return y
}

fn render-screen screen: (addr screen), _target-screen: (addr screen), xmin: int, ymin: int -> _/ecx: int {
  var target-screen/esi: (addr screen) <- copy _target-screen
  var height/edx: (addr int) <- get target-screen, height
  var y/ecx: int <- copy 0
  var screen-y/edi: int <- copy ymin
  {
    compare y, *height
    break-if->=
    set-cursor-position screen, xmin, screen-y
    draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x18/fg, 0/bg
    move-cursor-right screen
    var width/edx: (addr int) <- get target-screen, width
    var x/ebx: int <- copy 0
    {
      compare x, *width
      break-if->=
      print-screen-cell-of-fake-screen screen, target-screen, x, y
      move-cursor-right screen
      x <- increment
      loop
    }
    draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x18/fg, 0/bg
    y <- increment
    screen-y <- increment
    loop
  }
  return y
}

fn print-screen-cell-of-fake-screen screen: (addr screen), _target: (addr screen), x: int, y: int {
  var target/ecx: (addr screen) <- copy _target
  var data-ah/eax: (addr handle array screen-cell) <- get target, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var index/ecx: int <- screen-cell-index target, x, y
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var src-cell/esi: (addr screen-cell) <- index data, offset
  var src-grapheme/eax: (addr grapheme) <- get src-cell, data
  var src-color/ecx: (addr int) <- get src-cell, color
  var src-background-color/edx: (addr int) <- get src-cell, background-color
  draw-grapheme-at-cursor screen, *src-grapheme, *src-color, *src-background-color
}

fn render-sandbox-menu screen: (addr screen) {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  var y/ecx: int <- copy height
  y <- decrement
  var height/edx: int <- copy y
  height <- increment
  clear-rect screen, 0/x, y, width, height, 0/bg=black
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ctrl-s ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " tab ", width, 0/fg, 9/bg=blue
  draw-text-rightward-from-cursor screen, " move to trace  ", width, 7/fg, 0/bg
}

fn edit-sandbox _self: (addr sandbox), key: byte, globals: (addr global-table), real-screen: (addr screen), real-keyboard: (addr keyboard), data-disk: (addr disk) {
  var self/esi: (addr sandbox) <- copy _self
  var g/edx: grapheme <- copy key
  # ctrl-r
  {
    compare g, 0x12/ctrl-r
    break-if-!=
    # run function outside sandbox
    # required: fn (addr screen), (addr keyboard)
    # Mu will pass in the real screen and keyboard.
    return
  }
  # ctrl-s
  {
    compare g, 0x13/ctrl-s
    break-if-!=
    # save to disk
    var data-ah/eax: (addr handle gap-buffer) <- get self, data
    var _data/eax: (addr gap-buffer) <- lookup *data-ah
    var data/ecx: (addr gap-buffer) <- copy _data
    {
      compare data-disk, 0/no-disk
      break-if-=
      var stream-storage: (stream byte 0x200)
      var stream/esi: (addr stream byte) <- address stream-storage
      emit-gap-buffer data, stream
      store-sector data-disk, 0/lba, stream
    }
    # run sandbox
    var value-ah/eax: (addr handle stream byte) <- get self, value
    var _value/eax: (addr stream byte) <- lookup *value-ah
    var value/edx: (addr stream byte) <- copy _value
    var trace-ah/eax: (addr handle trace) <- get self, trace
    var trace/eax: (addr trace) <- lookup *trace-ah
    clear-trace trace
    run data, value, globals, trace
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

fn run in: (addr gap-buffer), out: (addr stream byte), globals: (addr global-table), trace: (addr trace) {
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
  evaluate read-result, eval-result, *nil-ah, globals, trace
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
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "1    ", "F - test-run-integer/0"
  check-screen-row screen, 1/y, "...  ", "F - test-run-integer/1"
  check-screen-row screen, 2/y, "=> 1 ", "F - test-run-integer/2"
}

fn test-run-with-spaces {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type input with whitespace before and after
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, " 1   ", "F - test-run-with-spaces/0"
  check-screen-row screen, 1/y, "     ", "F - test-run-with-spaces/1"
  check-screen-row screen, 2/y, "...  ", "F - test-run-with-spaces/2"
  check-screen-row screen, 3/y, "=> 1 ", "F - test-run-with-spaces/3"
}

fn test-run-quote {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "'a"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'a   ", "F - test-run-quote/0"
  check-screen-row screen, 1/y, "...  ", "F - test-run-quote/1"
  check-screen-row screen, 2/y, "=> a ", "F - test-run-quote/2"
}

fn test-run-error-invalid-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "1a"
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "1a             ", "F - test-run-error-invalid-integer/0"
  check-screen-row screen, 1/y, "...            ", "F - test-run-error-invalid-integer/0"
  check-screen-row screen, 2/y, "invalid number ", "F - test-run-error-invalid-integer/2"
}

fn test-run-move-cursor-into-trace {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox
  # type "12"
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x32/2, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/pre-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/pre-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 9/tab, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/trace-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-run-move-cursor-into-trace/trace-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/trace-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||   ", "F - test-run-move-cursor-into-trace/trace-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/trace-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/trace-2/cursor"
  # move cursor into input
  edit-sandbox sandbox, 9/tab, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/input-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/input-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/input-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/input-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/input-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/input-2/cursor"
}

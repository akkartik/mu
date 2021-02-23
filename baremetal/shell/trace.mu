# A trace records the evolution of a computation.
# An integral part of the Mu Shell is facilities for browsing traces.

type trace {
  curr-depth: int  # depth that will be assigned to next line appended
  data: (handle stream trace-line)
  cursor-y: int  # row index on screen
}

type trace-line {
  depth: int
  label: (handle array byte)
  data: (handle array byte)
}

fn initialize-trace _self: (addr trace), capacity: int {
  var self/eax: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle stream trace-line) <- get self, data
  populate-stream trace-ah, capacity
}

fn clear-trace _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle stream trace-line) <- get self, data
  var trace/eax: (addr stream trace-line) <- lookup *trace-ah
  clear-stream trace  # leaks memory
}

fn has-errors? _self: (addr trace) -> _/eax: boolean {
  var self/eax: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle stream trace-line) <- get self, data
  var _trace/eax: (addr stream trace-line) <- lookup *trace-ah
  var trace/esi: (addr stream trace-line) <- copy _trace
  rewind-stream trace
  {
    var done?/eax: boolean <- stream-empty? trace
    compare done?, 0/false
    break-if-!=
    var curr-storage: trace-line
    var curr/eax: (addr trace-line) <- address curr-storage
    read-from-stream trace, curr
    var curr-label-ah/eax: (addr handle array byte) <- get curr, label
    var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
    var is-error?/eax: boolean <- string-equal? curr-label, "error"
    compare is-error?, 0/false
    loop-if-=
    return 1/true
  }
  return 0/false
}

fn trace _self: (addr trace), label: (addr array byte), data: (addr stream byte) {
  var self/esi: (addr trace) <- copy _self
  var line-storage: trace-line
  var line/ecx: (addr trace-line) <- address line-storage
  var depth/eax: (addr int) <- get self, curr-depth
  initialize-trace-line *depth, label, data, line
  var dest-ah/eax: (addr handle stream trace-line) <- get self, data
  var dest/eax: (addr stream trace-line) <- lookup *dest-ah
  write-to-stream dest, line
}

fn trace-text self: (addr trace), label: (addr array byte), s: (addr array byte) {
  var data-storage: (stream byte 0x100)
  var data/eax: (addr stream byte) <- address data-storage
  write data, s
  trace self, label, data
}

fn error self: (addr trace), message: (addr array byte) {
  trace-text self, "error", message
}

fn initialize-trace-line depth: int, label: (addr array byte), data: (addr stream byte), _out: (addr trace-line) {
  var out/edi: (addr trace-line) <- copy _out
  # depth
  var src/eax: int <- copy depth
  var dest/ecx: (addr int) <- get out, depth
  copy-to *dest, src
  # label
  var dest/eax: (addr handle array byte) <- get out, label
  copy-array-object label, dest
  # data
  var dest/eax: (addr handle array byte) <- get out, data
  stream-to-array data, dest
}

fn trace-lower _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var depth/eax: (addr int) <- get self, curr-depth
  increment *depth
}

fn trace-higher _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var depth/eax: (addr int) <- get self, curr-depth
  decrement *depth
}

fn render-trace screen: (addr screen), _self: (addr trace), xmin: int, ymin: int, xmax: int, ymax: int, show-cursor?: boolean -> _/ecx: int {
  var already-hiding-lines?/ebx: boolean <- copy 0/false
  var y/ecx: int <- copy ymin
  var self/eax: (addr trace) <- copy _self
  # initialize cursor-y if necessary
  compare show-cursor?, 0/false
  {
    break-if-=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    compare *cursor-y, y
    break-if->=
    copy-to *cursor-y, y
  }
  var trace-ah/eax: (addr handle stream trace-line) <- get self, data
  var _trace/eax: (addr stream trace-line) <- lookup *trace-ah
  var trace/esi: (addr stream trace-line) <- copy _trace
  rewind-stream trace
  $render-trace:loop: {
    var done?/eax: boolean <- stream-empty? trace
    compare done?, 0/false
    break-if-!=
    var curr-storage: trace-line
    var curr/edx: (addr trace-line) <- address curr-storage
    read-from-stream trace, curr
    var curr-label-ah/eax: (addr handle array byte) <- get curr, label
    var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
    var bg/edi: int <- copy 0/black
    compare show-cursor?, 0/false
    {
      break-if-=
      var self/eax: (addr trace) <- copy _self
      var cursor-y/eax: (addr int) <- get self, cursor-y
      compare *cursor-y, y
      break-if-!=
      bg <- copy 7/grey
    }
    # always display errors
    var is-error?/eax: boolean <- string-equal? curr-label, "error"
    {
      compare is-error?, 0/false
      break-if-=
      var curr-data-ah/eax: (addr handle array byte) <- get curr, data
      var _curr-data/eax: (addr array byte) <- lookup *curr-data-ah
      var curr-data/edx: (addr array byte) <- copy _curr-data
      var x/eax: int <- copy xmin
      x, y <- draw-text-wrapping-right-then-down screen, curr-data, xmin, ymin, xmax, ymax, x, y, 0xc/fg=trace-error, bg
      y <- increment
      already-hiding-lines? <- copy 0/false
      loop $render-trace:loop
    }
    # otherwise ignore the rest
    compare already-hiding-lines?, 0/false
    {
      break-if-!=
      var x/eax: int <- copy xmin
      x, y <- draw-text-wrapping-right-then-down screen, "...", xmin, ymin, xmax, ymax, x, y, 9/fg=trace, bg
      y <- increment
      already-hiding-lines? <- copy 1/true
    }
    loop
  }
  # prevent cursor from going too far down
  {
    var self/eax: (addr trace) <- copy _self
    var cursor-y/eax: (addr int) <- get self, cursor-y
    compare *cursor-y, y
    break-if-<=
    copy-to *cursor-y, y
  }
  return y
}

fn test-render-trace-empty {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 5/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 0, "F - test-render-trace-empty/cursor"
  check-screen-row screen, 0/y, "    ", "F - test-render-trace-empty"
}

fn test-render-trace-collapsed-by-default {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 5/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 1, "F - test-render-trace-collapsed-by-default/cursor"
  check-screen-row screen, 0/y, "... ", "F - test-render-trace-collapsed-by-default"
}

fn test-render-trace-error {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  error t, "error"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 1, "F - test-render-trace-error/cursor"
  check-screen-row screen, 0/y, "error", "F - test-render-trace-error"
}

fn test-render-trace-error-at-start {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # line 1
  error t, "error"
  # line 2
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 2, "F - test-render-trace-error-at-start/cursor"
  check-screen-row screen, 0/y, "error", "F - test-render-trace-error-at-start/0"
  check-screen-row screen, 1/y, "...  ", "F - test-render-trace-error-at-start/1"
}

fn test-render-trace-error-at-end {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # line 1
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # line 2
  error t, "error"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 2, "F - test-render-trace-error-at-end/cursor"
  check-screen-row screen, 0/y, "...  ", "F - test-render-trace-error-at-end/0"
  check-screen-row screen, 1/y, "error", "F - test-render-trace-error-at-end/1"
}

fn test-render-trace-error-in-the-middle {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # line 1
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # line 2
  error t, "error"
  # line 3
  trace t, "l", contents
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 3, "F - test-render-trace-error-in-the-middle/cursor"
  check-screen-row screen, 0/y, "...  ", "F - test-render-trace-error-in-the-middle/0"
  check-screen-row screen, 1/y, "error", "F - test-render-trace-error-in-the-middle/1"
  check-screen-row screen, 2/y, "...  ", "F - test-render-trace-error-in-the-middle/2"
}

fn test-render-trace-cursor-in-single-line {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # line 1
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # line 2
  error t, "error"
  # line 3
  trace t, "l", contents
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...   ", "F - test-render-trace-cursor-in-single-line/0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||   ", "F - test-render-trace-cursor-in-single-line/0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-render-trace-cursor-in-single-line/1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-render-trace-cursor-in-single-line/1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-render-trace-cursor-in-single-line/2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-render-trace-cursor-in-single-line/2/cursor"
}

fn edit-trace _self: (addr trace), key: grapheme {
  var self/esi: (addr trace) <- copy _self
  # cursor down
  {
    compare key, 4/ctrl-d
    break-if-!=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    increment *cursor-y
    return
  }
  # cursor up
  {
    compare key, 0x15/ctrl-u
    break-if-!=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    decrement *cursor-y
    return
  }
}

fn test-cursor-down-and-up-within-trace {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # line 1
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # line 2
  error t, "error"
  # line 3
  trace t, "l", contents
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-and-up-within-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||   ", "F - test-cursor-down-and-up-within-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-and-up-within-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-cursor-down-and-up-within-trace/pre-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-and-up-within-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-cursor-down-and-up-within-trace/pre-2/cursor"
  # cursor down
  edit-trace t, 4/ctrl-d
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-and-up-within-trace/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-cursor-down-and-up-within-trace/down-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-and-up-within-trace/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "||||| ", "F - test-cursor-down-and-up-within-trace/down-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-and-up-within-trace/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-cursor-down-and-up-within-trace/down-2/cursor"
  # cursor up
  edit-trace t, 0x15/ctrl-u
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-and-up-within-trace/up-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||   ", "F - test-cursor-down-and-up-within-trace/up-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-and-up-within-trace/up-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-cursor-down-and-up-within-trace/up-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-and-up-within-trace/up-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-cursor-down-and-up-within-trace/up-2/cursor"
}

fn test-cursor-down-past-bottom-of-trace {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10
  # line 1
  var contents-storage: (stream byte 0x10)
  var contents/ecx: (addr stream byte) <- address contents-storage
  write contents, "data"
  trace t, "l", contents
  # line 2
  error t, "error"
  # line 3
  trace t, "l", contents
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa, 4
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||   ", "F - test-cursor-down-past-bottom-of-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-past-bottom-of-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-cursor-down-past-bottom-of-trace/pre-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-cursor-down-past-bottom-of-trace/pre-2/cursor"
  # cursor down several times
  edit-trace t, 4/ctrl-d
  edit-trace t, 4/ctrl-d
  edit-trace t, 4/ctrl-d
  edit-trace t, 4/ctrl-d
  edit-trace t, 4/ctrl-d
  # hack: we do need to render to make this test pass; a sign that we're mixing state management with rendering
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  # cursor disappears past bottom
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-cursor-down-past-bottom-of-trace/down-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-past-bottom-of-trace/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-cursor-down-past-bottom-of-trace/down-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-cursor-down-past-bottom-of-trace/down-2/cursor"
  # then cursor up
  edit-trace t, 0x15/ctrl-u
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  # we still display cursor at bottom
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/up-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-cursor-down-past-bottom-of-trace/up-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-past-bottom-of-trace/up-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-cursor-down-past-bottom-of-trace/up-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/up-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|||   ", "F - test-cursor-down-past-bottom-of-trace/up-2/cursor"
}

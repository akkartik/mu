# A trace records the evolution of a computation.
# An integral part of the Mu Shell is facilities for browsing traces.

type trace {
  # steady-state life cycle of a trace:
  #   reload loop:
  #     there are already some visible lines
  #     append a bunch of new trace lines to the trace
  #     render loop:
  #       rendering displays trace lines that match visible lines
  #       rendering computes cursor-line based on the cursor-y coordinate
  #       edit-trace updates cursor-y coordinate
  #       edit-trace might add/remove lines to visible
  curr-depth: int  # depth that will be assigned to next line appended
  data: (handle array trace-line)
  first-free: int
  visible: (handle array trace-line)
  recompute-visible?: boolean
  top-line-index: int  # index into data
  cursor-y: int  # row index on screen
  cursor-line-index: int  # index into data
}

type trace-line {
  depth: int
  label: (handle array byte)
  data: (handle array byte)
  visible?: boolean
}

fn initialize-trace _self: (addr trace), capacity: int, visible-capacity: int {
  var self/esi: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  populate trace-ah, capacity
  var visible-ah/eax: (addr handle array trace-line) <- get self, visible
  populate visible-ah, visible-capacity
}

fn clear-trace _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  var len/edx: (addr int) <- get self, first-free
  copy-to *len, 0
  # might leak memory; existing elements won't be used anymore
}

fn mark-lines-dirty _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  var dest/edx: (addr boolean) <- get self, recompute-visible?
  copy-to *dest, 1/true
}

fn mark-lines-clean _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  var dest/edx: (addr boolean) <- get self, recompute-visible?
  copy-to *dest, 0/false
}

fn has-errors? _self: (addr trace) -> _/eax: boolean {
  var self/eax: (addr trace) <- copy _self
  var max/edx: (addr int) <- get self, first-free
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/esi: (addr array trace-line) <- copy _trace
  var i/ecx: int <- copy 0
  {
    compare i, *max
    break-if->=
    var offset/eax: (offset trace-line) <- compute-offset trace, i
    var curr/eax: (addr trace-line) <- index trace, offset
    var curr-label-ah/eax: (addr handle array byte) <- get curr, label
    var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
    var is-error?/eax: boolean <- string-equal? curr-label, "error"
    compare is-error?, 0/false
    {
      break-if-=
      return 1/true
    }
    i <- increment
    loop
  }
  return 0/false
}

fn trace _self: (addr trace), label: (addr array byte), message: (addr stream byte) {
  var self/esi: (addr trace) <- copy _self
  var data-ah/eax: (addr handle array trace-line) <- get self, data
  var data/eax: (addr array trace-line) <- lookup *data-ah
  var index-addr/edi: (addr int) <- get self, first-free
  var index/ecx: int <- copy *index-addr
  var offset/ecx: (offset trace-line) <- compute-offset data, index
  var dest/eax: (addr trace-line) <- index data, offset
  var depth/ecx: (addr int) <- get self, curr-depth
  initialize-trace-line *depth, label, message, dest
  increment *index-addr
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
  var already-hiding-lines?: boolean
  var y/ecx: int <- copy ymin
  var self/esi: (addr trace) <- copy _self
  clamp-cursor-to-top self, y
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var i/edx: int <- copy 0
  var max-addr/ebx: (addr int) <- get self, first-free
  var max/ebx: int <- copy *max-addr
  $render-trace:loop: {
    compare i, max
    break-if->=
    $render-trace:iter: {
      var offset/ebx: (offset trace-line) <- compute-offset trace, i
      var curr/ebx: (addr trace-line) <- index trace, offset
      var curr-label-ah/eax: (addr handle array byte) <- get curr, label
      var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
      var bg/edi: int <- copy 0/black
      compare show-cursor?, 0/false
      {
        break-if-=
        var cursor-y/eax: (addr int) <- get self, cursor-y
        compare *cursor-y, y
        break-if-!=
        bg <- copy 7/grey
        var cursor-line-index/eax: (addr int) <- get self, cursor-line-index
        copy-to *cursor-line-index, i
      }
      # always display errors
      var is-error?/eax: boolean <- string-equal? curr-label, "error"
      {
        compare is-error?, 0/false
        break-if-=
        y <- render-trace-line screen, curr, xmin, y, xmax, ymax, 0xc/fg=trace-error, bg
        copy-to already-hiding-lines?, 0/false
        break $render-trace:iter
      }
      # display expanded lines
      var display?/eax: boolean <- should-render? self, curr
      {
        compare display?, 0/false
        break-if-=
        y <- render-trace-line screen, curr, xmin, y, xmax, ymax, 9/fg=blue, bg
        copy-to already-hiding-lines?, 0/false
        break $render-trace:iter
      }
      # ignore the rest
      compare already-hiding-lines?, 0/false
      {
        break-if-!=
        var x/eax: int <- copy xmin
        x, y <- draw-text-wrapping-right-then-down screen, "...", xmin, ymin, xmax, ymax, x, y, 9/fg=trace, bg
        y <- increment
        copy-to already-hiding-lines?, 1/true
      }
    }
    i <- increment
    loop
  }
  # prevent cursor from going too far down
  clamp-cursor-to-bottom self, y
  mark-lines-clean self
  return y
}

fn render-trace-line screen: (addr screen), _self: (addr trace-line), xmin: int, ymin: int, xmax: int, ymax: int, fg: int, bg: int -> _/ecx: int {
  var self/esi: (addr trace-line) <- copy _self
  var xsave/edx: int <- copy xmin
  var y/ecx: int <- copy ymin
  var label-ah/eax: (addr handle array byte) <- get self, label
  var _label/eax: (addr array byte) <- lookup *label-ah
  var label/ebx: (addr array byte) <- copy _label
  var is-error?/eax: boolean <- string-equal? label, "error"
  compare is-error?, 0/false
  {
    break-if-!=
    var x/eax: int <- copy xsave
    {
      var depth/edx: (addr int) <- get self, depth
      x, y <- draw-int32-decimal-wrapping-right-then-down screen, *depth, xmin, ymin, xmax, ymax, x, y, fg, bg
      x, y <- draw-text-wrapping-right-then-down screen, " ", xmin, ymin, xmax, ymax, x, y, fg, bg
      x, y <- draw-text-wrapping-right-then-down screen, label, xmin, ymin, xmax, ymax, x, y, fg, bg
      x, y <- draw-text-wrapping-right-then-down screen, ": ", xmin, ymin, xmax, ymax, x, y, fg, bg
    }
    xsave <- copy x
  }
  var data-ah/eax: (addr handle array byte) <- get self, data
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data/ebx: (addr array byte) <- copy _data
  var x/eax: int <- copy xsave
  x, y <- draw-text-wrapping-right-then-down screen, data, xmin, ymin, xmax, ymax, x, y, fg, bg
  y <- increment
  return y
}

fn should-render? _self: (addr trace), _line: (addr trace-line) -> _/eax: boolean {
  var self/esi: (addr trace) <- copy _self
  # if visible? is already cached, just return it
  var dest/edx: (addr boolean) <- get self, recompute-visible?
  compare *dest, 0/false
  {
    break-if-!=
    var line/eax: (addr trace-line) <- copy _line
    var result/eax: (addr boolean) <- get line, visible?
    return *result
  }
  # recompute
  var candidates-ah/eax: (addr handle array trace-line) <- get self, visible
  var candidates/eax: (addr array trace-line) <- lookup *candidates-ah
  var i/ecx: int <- copy 0
  var len/edx: int <- length candidates
  {
    compare i, len
    break-if->=
    {
      var curr-offset/ecx: (offset trace-line) <- compute-offset candidates, i
      var curr/ecx: (addr trace-line) <- index candidates, curr-offset
      var match?/eax: boolean <- trace-lines-equal? curr, _line
      compare match?, 0/false
      break-if-=
      var line/eax: (addr trace-line) <- copy _line
      var dest/eax: (addr boolean) <- get line, visible?
      copy-to *dest, 1/true
      return 1/true
    }
    i <- increment
    loop
  }
  var line/eax: (addr trace-line) <- copy _line
  var dest/eax: (addr boolean) <- get line, visible?
  copy-to *dest, 0/false
  return 0/false
}

# this is probably super-inefficient, string comparing every trace line
# against every visible line on every render
fn trace-lines-equal? _a: (addr trace-line), _b: (addr trace-line) -> _/eax: boolean {
  var a/esi: (addr trace-line) <- copy _a
  var b/edi: (addr trace-line) <- copy _b
  var a-depth/ecx: (addr int) <- get a, depth
  var b-depth/edx: (addr int) <- get b, depth
  var benchmark/eax: int <- copy *b-depth
  compare *a-depth, benchmark
  {
    break-if-=
    return 0/false
  }
  var a-label-ah/eax: (addr handle array byte) <- get a, label
  var _a-label/eax: (addr array byte) <- lookup *a-label-ah
  var a-label/ecx: (addr array byte) <- copy _a-label
  var b-label-ah/ebx: (addr handle array byte) <- get b, label
  var b-label/eax: (addr array byte) <- lookup *b-label-ah
  var label-match?/eax: boolean <- string-equal? a-label, b-label
  {
    compare label-match?, 0/false
    break-if-!=
    return 0/false
  }
  var a-data-ah/eax: (addr handle array byte) <- get a, data
  var _a-data/eax: (addr array byte) <- lookup *a-data-ah
  var a-data/ecx: (addr array byte) <- copy _a-data
  var b-data-ah/ebx: (addr handle array byte) <- get b, data
  var b-data/eax: (addr array byte) <- lookup *b-data-ah
  var data-match?/eax: boolean <- string-equal? a-data, b-data
  return data-match?
}

fn clamp-cursor-to-top _self: (addr trace), _y: int {
  var y/ecx: int <- copy _y
  var self/esi: (addr trace) <- copy _self
  var cursor-y/eax: (addr int) <- get self, cursor-y
  compare *cursor-y, y
  break-if->=
  copy-to *cursor-y, y
}

fn clamp-cursor-to-bottom _self: (addr trace), _y: int {
  var y/ecx: int <- copy _y
  var self/esi: (addr trace) <- copy _self
  var cursor-y/eax: (addr int) <- get self, cursor-y
  compare *cursor-y, y
  break-if-<=
  copy-to *cursor-y, y
}

fn test-render-trace-empty {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 5/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 0, "F - test-render-trace-empty/cursor"
  check-screen-row screen, 0/y, "    ", "F - test-render-trace-empty"
}

fn test-render-trace-collapsed-by-default {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  trace-text t, "l", "data"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 5/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 1, "F - test-render-trace-collapsed-by-default/cursor"
  check-screen-row screen, 0/y, "... ", "F - test-render-trace-collapsed-by-default"
}

fn test-render-trace-error {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  error t, "error"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 1, "F - test-render-trace-error/cursor"
  check-screen-row screen, 0/y, "error", "F - test-render-trace-error"
}

fn test-render-trace-error-at-start {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  error t, "error"
  trace-text t, "l", "data"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
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
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "data"
  error t, "error"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
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
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
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
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
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

fn render-trace-menu screen: (addr screen) {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  var y/ecx: int <- copy height
  y <- decrement
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ctrl-s ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-d ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " cursor down  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-u ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " cursor up  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " tab ", width, 0/fg, 3/bg=cyan
  draw-text-rightward-from-cursor screen, " move to sandbox  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " enter ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " expand  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " backspace ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " collapse  ", width, 7/fg, 0/bg
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
  # enter
  {
    compare key, 0xa/newline
    break-if-!=
    expand self
    return
  }
}

fn expand _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var cursor-line-index-addr/ecx: (addr int) <- get self, cursor-line-index
  var cursor-line-index/ecx: int <- copy *cursor-line-index-addr
  var cursor-line-offset/eax: (offset trace-line) <- compute-offset trace, cursor-line-index
  var cursor-line/edx: (addr trace-line) <- index trace, cursor-line-offset
  var cursor-line-visible?/eax: (addr boolean) <- get cursor-line, visible?
  compare *cursor-line-visible?, 0/false
  var cursor-line-depth/ebx: (addr int) <- get cursor-line, depth
  var target-depth/ebx: int <- copy *cursor-line-depth
  # if cursor-line is already visible, increment target-depth
  compare *cursor-line-visible?, 0/false
  {
    break-if-=
    target-depth <- increment
  }
  # reveal the run of lines starting at cursor-line-index with depth target-depth
  var i/ecx: int <- copy cursor-line-index
  var max/edx: (addr int) <- get self, first-free
  {
    compare i, *max
    break-if->=
    var curr-line-offset/eax: (offset trace-line) <- compute-offset trace, i
    var curr-line/edx: (addr trace-line) <- index trace, curr-line-offset
    var curr-line-depth/eax: (addr int) <- get curr-line, depth
    compare *curr-line-depth, target-depth
    break-if-<
    {
      break-if-!=
      var curr-line-visible?/eax: (addr boolean) <- get curr-line, visible?
      copy-to *curr-line-visible?, 1/true
      reveal-trace-line self, curr-line
    }
    i <- increment
    loop
  }
}

# the 'visible' array is not required to be in order
# elements can also be deleted out of order
# so it can have holes
# however, lines in it always have visible? set
# we'll use visible? being unset as a sign of emptiness
fn reveal-trace-line _self: (addr trace), line: (addr trace-line) {
  var self/esi: (addr trace) <- copy _self
  var visible-ah/eax: (addr handle array trace-line) <- get self, visible
  var visible/eax: (addr array trace-line) <- lookup *visible-ah
  var i/ecx: int <- copy 0
  var len/edx: int <- length visible
  {
    compare i, len
    break-if->=
    var curr-offset/edx: (offset trace-line) <- compute-offset visible, i
    var curr/edx: (addr trace-line) <- index visible, curr-offset
    var curr-visible?/eax: (addr boolean) <- get curr, visible?
    compare *curr-visible?, 0/false
    {
      break-if-!=
      # empty slot found
      copy-object line, curr
      return
    }
    i <- increment
    loop
  }
  abort "too many visible lines; increase size of array trace.visible"
}

fn test-cursor-down-and-up-within-trace {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
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
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height
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
  # hack: we do need to render to make this test pass; we're mixing state management with rendering
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

fn test-cursor-expand-within-trace {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...         ", "F - test-cursor-expand-within-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||         ", "F - test-cursor-expand-within-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "            ", "F - test-cursor-expand-within-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "            ", "F - test-cursor-expand-within-trace/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1 ", "F - test-cursor-expand-within-trace/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||||| ", "F - test-cursor-expand-within-trace/expand-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 2 ", "F - test-cursor-expand-within-trace/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "            ", "F - test-cursor-expand-within-trace/expand-1/cursor"
  check-screen-row screen,                                  2/y, "            ", "F - test-cursor-expand-within-trace/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "            ", "F - test-cursor-expand-within-trace/expand-2/cursor"
}

fn test-cursor-expand-skips-lower-depth {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...         ", "F - test-cursor-expand-skips-lower-depth/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||         ", "F - test-cursor-expand-skips-lower-depth/pre-0/cursor"
  check-screen-row screen,                                  1/y, "            ", "F - test-cursor-expand-skips-lower-depth/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "            ", "F - test-cursor-expand-skips-lower-depth/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1 ", "F - test-cursor-expand-skips-lower-depth/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||||| ", "F - test-cursor-expand-skips-lower-depth/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...         ", "F - test-cursor-expand-skips-lower-depth/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "            ", "F - test-cursor-expand-skips-lower-depth/expand-1/cursor"
  check-screen-row screen,                                  2/y, "            ", "F - test-cursor-expand-skips-lower-depth/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "            ", "F - test-cursor-expand-skips-lower-depth/expand-2/cursor"
}

fn test-cursor-expand-continues-past-lower-depth {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...         ", "F - test-cursor-expand-continues-past-lower-depth/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||         ", "F - test-cursor-expand-continues-past-lower-depth/pre-0/cursor"
  check-screen-row screen,                                  1/y, "            ", "F - test-cursor-expand-continues-past-lower-depth/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "            ", "F - test-cursor-expand-continues-past-lower-depth/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1 ", "F - test-cursor-expand-continues-past-lower-depth/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||||| ", "F - test-cursor-expand-continues-past-lower-depth/expand-0/cursor"
  # TODO: might be too wasteful to show every place where lines are hidden
  check-screen-row screen,                                  1/y, "...         ", "F - test-cursor-expand-continues-past-lower-depth/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "            ", "F - test-cursor-expand-continues-past-lower-depth/expand-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 2 ", "F - test-cursor-expand-continues-past-lower-depth/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "            ", "F - test-cursor-expand-continues-past-lower-depth/expand-2/cursor"
}

fn test-cursor-expand-stops-at-higher-depth {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1.1"
  trace-lower t
  trace-text t, "l", "line 1.1.1"
  trace-higher t
  trace-text t, "l", "line 1.2"
  trace-higher t
  trace-text t, "l", "line 2"
  trace-lower t
  trace-text t, "l", "line 2.1"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 8/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...           ", "F - test-cursor-expand-continues-past-lower-depth/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||           ", "F - test-cursor-expand-continues-past-lower-depth/pre-0/cursor"
  check-screen-row screen,                                  1/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1.1 ", "F - test-cursor-expand-continues-past-lower-depth/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||||||| ", "F - test-cursor-expand-continues-past-lower-depth/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...           ", "F - test-cursor-expand-continues-past-lower-depth/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/expand-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 1.2 ", "F - test-cursor-expand-continues-past-lower-depth/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/expand-2/cursor"
  check-screen-row screen,                                  3/y, "...           ", "F - test-cursor-expand-continues-past-lower-depth/expand-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/expand-3/cursor"
  check-screen-row screen,                                  4/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/expand-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "              ", "F - test-cursor-expand-continues-past-lower-depth/expand-4/cursor"
}

fn test-cursor-expand-twice {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...           ", "F - test-cursor-expand-twice/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||           ", "F - test-cursor-expand-twice/pre-0/cursor"
  check-screen-row screen,                                  1/y, "              ", "F - test-cursor-expand-twice/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-expand-twice/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-expand-twice/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||||||   ", "F - test-cursor-expand-twice/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...           ", "F - test-cursor-expand-twice/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-expand-twice/expand-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 2   ", "F - test-cursor-expand-twice/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-cursor-expand-twice/expand-2/cursor"
  # cursor down
  edit-trace t, 4/ctrl-d
  # hack: we need to render here to make this test pass; we're mixing state management with rendering
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-expand-twice/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "              ", "F - test-cursor-expand-twice/down-0/cursor"
  check-screen-row screen,                                  1/y, "...           ", "F - test-cursor-expand-twice/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||           ", "F - test-cursor-expand-twice/down-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 2   ", "F - test-cursor-expand-twice/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-cursor-expand-twice/down-2/cursor"
  # expand again
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-expand-twice/expand2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "              ", "F - test-cursor-expand-twice/expand2-0/cursor"
  check-screen-row screen,                                  1/y, "1 l: line 1.1 ", "F - test-cursor-expand-twice/expand2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "||||||||||||| ", "F - test-cursor-expand-twice/expand2-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 2   ", "F - test-cursor-expand-twice/expand2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-cursor-expand-twice/expand2-2/cursor"
}

fn test-cursor-refresh-cursor {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...           ", "F - test-cursor-refresh-cursor/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||           ", "F - test-cursor-refresh-cursor/pre-0/cursor"
  check-screen-row screen,                                  1/y, "              ", "F - test-cursor-refresh-cursor/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-refresh-cursor/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-refresh-cursor/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||||||   ", "F - test-cursor-refresh-cursor/expand-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 2   ", "F - test-cursor-refresh-cursor/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-refresh-cursor/expand-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 3   ", "F - test-cursor-refresh-cursor/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-cursor-refresh-cursor/expand-2/cursor"
  # cursor down
  edit-trace t, 4/ctrl-d
  edit-trace t, 4/ctrl-d
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-refresh-cursor/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "              ", "F - test-cursor-refresh-cursor/down-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 2   ", "F - test-cursor-refresh-cursor/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-refresh-cursor/down-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 3   ", "F - test-cursor-refresh-cursor/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|||||||||||   ", "F - test-cursor-refresh-cursor/down-2/cursor"
  # recreate trace
  clear-trace t
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # cursor remains unchanged
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-refresh-cursor/refresh-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "              ", "F - test-cursor-refresh-cursor/refresh-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 2   ", "F - test-cursor-refresh-cursor/refresh-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-refresh-cursor/refresh-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 3   ", "F - test-cursor-refresh-cursor/refresh-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|||||||||||   ", "F - test-cursor-refresh-cursor/refresh-2/cursor"
}

fn test-cursor-preserve-cursor-on-edit-in-other-line {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...           ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||           ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/pre-0/cursor"
  check-screen-row screen,                                  1/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||||||   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/expand-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 2   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/expand-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 3   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/expand-2/cursor"
  # cursor down
  edit-trace t, 4/ctrl-d
  edit-trace t, 4/ctrl-d
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "0 l: line 1   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/down-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 2   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/down-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 3   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|||||||||||   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/down-2/cursor"
  # recreate trace with slightly different lines
  clear-trace t
  trace-text t, "l", "line 4"
  trace-text t, "l", "line 5"
  trace-text t, "l", "line 3"  # cursor line is unchanged
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # cursor remains unchanged
  check-screen-row screen,                                  0/y, "0 l: line 4   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/refresh-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/refresh-0/cursor"
  check-screen-row screen,                                  1/y, "0 l: line 5   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/refresh-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "              ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/refresh-1/cursor"
  check-screen-row screen,                                  2/y, "0 l: line 3   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/refresh-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|||||||||||   ", "F - test-cursor-preserve-cursor-on-edit-in-other-line/refresh-2/cursor"
}

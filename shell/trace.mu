# A trace records the evolution of a computation.
# Traces are useful for:
#   error-handling
#   testing
#   auditing
#   debugging
#   learning
#
# An integral part of the Mu computer is facilities for browsing traces.

type trace {
  max-depth: int
  curr-depth: int  # depth that will be assigned to next line appended
  data: (handle array trace-line)
  first-free: int
  first-full: int  # used only by check-trace-scan

  # steady-state life cycle of a trace:
  #   reload loop:
  #     there are already some visible lines
  #     append a bunch of new trace lines to the trace
  #     recreate trace caches
  #     render loop:
  #       rendering displays trace lines that match visible lines
  #         (caching in each line)
  #         (caching top-line)
  #       rendering computes cursor-line based on the cursor-y coordinate
  #       edit-trace updates cursor-y coordinate
  #       edit-trace might add/remove lines to visible
  #       edit-trace might update top-line
  visible: (handle array trace-line)
  recreate-caches?: boolean
  cursor-line-index: int  # index into data
  cursor-y: int  # row index on screen
  unclip-cursor-line?: boolean  # extremely short-lived; reset any time cursor moves
  top-line-index: int  # start rendering trace past this index into data (updated on re-evaluation)
  top-line-y: int  # trace starts rendering at this row index on screen (updated on re-evaluation)
  screen-height: int  # initialized during render-trace
}

type trace-line {
  depth: int
  label: (handle array byte)
  data: (handle array byte)
  visible?: boolean
}

# when we recreate the trace this data structure will help stabilize our view into it
# we can shallowly copy handles because lines are not reused across reruns
type trace-index-stash {
  cursor-line-depth: int
  cursor-line-label: (handle array byte)
  cursor-line-data: (handle array byte)
  top-line-depth: int
  top-line-label: (handle array byte)
  top-line-data: (handle array byte)
}

## generating traces

fn initialize-trace _self: (addr trace), max-depth: int, capacity: int, visible-capacity: int {
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var src/ecx: int <- copy max-depth
  var dest/eax: (addr int) <- get self, max-depth
  copy-to *dest, src
  dest <- get self, curr-depth
  copy-to *dest, 1  # 0 is the error depth
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  populate trace-ah, capacity
  var visible-ah/eax: (addr handle array trace-line) <- get self, visible
  populate visible-ah, visible-capacity
  mark-lines-dirty self
}

fn clear-trace _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var curr-depth-addr/ecx: (addr int) <- get self, curr-depth
  copy-to *curr-depth-addr, 1
  var len/edx: (addr int) <- get self, first-free
  copy-to *len, 0
  # leak: nested handles within trace-lines
}

fn has-errors? _self: (addr trace) -> _/eax: boolean {
  var self/eax: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
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
    var curr-depth-a/eax: (addr int) <- get curr, depth
    compare *curr-depth-a, 0/error
    {
      break-if-!=
      return 1/true
    }
    i <- increment
    loop
  }
  return 0/false
}

fn should-trace? _self: (addr trace) -> _/eax: boolean {
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var depth-a/ecx: (addr int) <- get self, curr-depth
  var depth/ecx: int <- copy *depth-a
  var max-depth-a/eax: (addr int) <- get self, max-depth
  compare depth, *max-depth-a
  {
    break-if->=
    return 1/true
  }
  return 0/false
}

fn trace _self: (addr trace), label: (addr array byte), message: (addr stream byte) {
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var should-trace?/eax: boolean <- should-trace? self
  compare should-trace?, 0/false
  {
    break-if-!=
    return
  }
  var data-ah/eax: (addr handle array trace-line) <- get self, data
  var data/eax: (addr array trace-line) <- lookup *data-ah
  var index-addr/edi: (addr int) <- get self, first-free
  {
    compare *index-addr, 0x8000/lines
    break-if-<
    return
  }
  var index/ecx: int <- copy *index-addr
  var offset/ecx: (offset trace-line) <- compute-offset data, index
  var dest/eax: (addr trace-line) <- index data, offset
  var depth/ecx: (addr int) <- get self, curr-depth
  rewind-stream message
  {
    compare *index-addr, 0x7fff/lines
    break-if-<
    clear-stream message
    write message, "No space left in trace\n"
    write message, "Please either:\n"
    write message, "  - find a smaller sub-computation to test,\n"
    write message, "  - allocate more space to the trace in initialize-sandbox\n"
    write message, "    (shell/sandbox.mu), or\n"
    write message, "  - move the computation to 'main' and run it using ctrl-r"
    initialize-trace-line 0/depth, "error", message, dest
    increment *index-addr
    return
  }
  initialize-trace-line *depth, label, message, dest
  increment *index-addr
}

fn trace-text self: (addr trace), label: (addr array byte), s: (addr array byte) {
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var data-storage: (stream byte 0x100)
  var data/eax: (addr stream byte) <- address data-storage
  write data, s
  trace self, label, data
}

fn error _self: (addr trace), message: (addr array byte) {
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var curr-depth-a/eax: (addr int) <- get self, curr-depth
  var save-depth/ecx: int <- copy *curr-depth-a
  copy-to *curr-depth-a, 0/error
  trace-text self, "error", message
  copy-to *curr-depth-a, save-depth
}

fn error-stream _self: (addr trace), message: (addr stream byte) {
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var curr-depth-a/eax: (addr int) <- get self, curr-depth
  var save-depth/ecx: int <- copy *curr-depth-a
  copy-to *curr-depth-a, 0/error
  trace self, "error", message
  copy-to *curr-depth-a, save-depth
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
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var depth/eax: (addr int) <- get self, curr-depth
  increment *depth
}

fn trace-higher _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var depth/eax: (addr int) <- get self, curr-depth
  decrement *depth
}

## checking traces

fn check-trace-scans-to self: (addr trace), label: (addr array byte), data: (addr array byte), message: (addr array byte) {
  var tmp/eax: boolean <- trace-scans-to? self, label, data
  check tmp, message
}

fn trace-scans-to? _self: (addr trace), label: (addr array byte), data: (addr array byte) -> _/eax: boolean {
  var self/esi: (addr trace) <- copy _self
  var start/eax: (addr int) <- get self, first-full
  var result/eax: boolean <- trace-contains? self, label, data, *start
  return result
}

fn test-trace-scans-to {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10/capacity, 0/visible  # we don't use trace UI
  #
  trace-text t, "label", "line 1"
  trace-text t, "label", "line 2"
  check-trace-scans-to t, "label", "line 1", "F - test-trace-scans-to/0"
  check-trace-scans-to t, "label", "line 2", "F - test-trace-scans-to/1"
  var tmp/eax: boolean <- trace-scans-to? t, "label", "line 1"
  check-not tmp, "F - test-trace-scans-to: fail on previously encountered lines"
  var tmp/eax: boolean <- trace-scans-to? t, "label", "line 3"
  check-not tmp, "F - test-trace-scans-to: fail on missing"
}

# scan trace from start
# resets previous scans
fn check-trace-contains self: (addr trace), label: (addr array byte), data: (addr array byte), message: (addr array byte) {
  var tmp/eax: boolean <- trace-contains? self, label, data, 0
  check tmp, message
}

fn test-trace-contains {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10/capacity, 0/visible  # we don't use trace UI
  #
  trace-text t, "label", "line 1"
  trace-text t, "label", "line 2"
  check-trace-contains t, "label", "line 1", "F - test-trace-contains/0"
  check-trace-contains t, "label", "line 2", "F - test-trace-contains/1"
  check-trace-contains t, "label", "line 1", "F - test-trace-contains: find previously encountered lines"
  var tmp/eax: boolean <- trace-contains? t, "label", "line 3", 0/start
  check-not tmp, "F - test-trace-contains: fail on missing"
}

# this is super-inefficient, string comparing every trace line
fn trace-contains? _self: (addr trace), label: (addr array byte), data: (addr array byte), start: int -> _/eax: boolean {
  var self/esi: (addr trace) <- copy _self
  var candidates-ah/eax: (addr handle array trace-line) <- get self, data
  var candidates/eax: (addr array trace-line) <- lookup *candidates-ah
  var i/ecx: int <- copy start
  var max/edx: (addr int) <- get self, first-free
  {
    compare i, *max
    break-if->=
    {
      var read-until-index/eax: (addr int) <- get self, first-full
      copy-to *read-until-index, i
    }
    {
      var curr-offset/ecx: (offset trace-line) <- compute-offset candidates, i
      var curr/ecx: (addr trace-line) <- index candidates, curr-offset
      # if curr->label does not match, return false
      var curr-label-ah/eax: (addr handle array byte) <- get curr, label
      var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
      var match?/eax: boolean <- string-equal? curr-label, label
      compare match?, 0/false
      break-if-=
      # if curr->data does not match, return false
      var curr-data-ah/eax: (addr handle array byte) <- get curr, data
      var curr-data/eax: (addr array byte) <- lookup *curr-data-ah
      var match?/eax: boolean <- string-equal? curr-data, data
      compare match?, 0/false
      break-if-=
      return 1/true
    }
    i <- increment
    loop
  }
  return 0/false
}

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

fn dump-trace _self: (addr trace) {
  var y/ecx: int <- copy 0
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var i/edx: int <- copy 0
  var max-addr/ebx: (addr int) <- get self, first-free
  var max/ebx: int <- copy *max-addr
  $dump-trace:loop: {
    compare i, max
    break-if->=
    $dump-trace:iter: {
      var offset/ebx: (offset trace-line) <- compute-offset trace, i
      var curr/ebx: (addr trace-line) <- index trace, offset
      y <- render-trace-line 0/screen, curr, 0, y, 0x80/width, 0x30/height, 7/fg, 0/bg, 0/clip
    }
    i <- increment
    loop
  }
}

fn dump-trace-with-label _self: (addr trace), label: (addr array byte) {
  var y/ecx: int <- copy 0
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var i/edx: int <- copy 0
  var max-addr/ebx: (addr int) <- get self, first-free
  var max/ebx: int <- copy *max-addr
  $dump-trace:loop: {
    compare i, max
    break-if->=
    $dump-trace:iter: {
      var offset/ebx: (offset trace-line) <- compute-offset trace, i
      var curr/ebx: (addr trace-line) <- index trace, offset
      var curr-label-ah/eax: (addr handle array byte) <- get curr, label
      var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
      var show?/eax: boolean <- string-equal? curr-label, label
      compare show?, 0/false
      break-if-=
      y <- render-trace-line 0/screen, curr, 0, y, 0x80/width, 0x30/height, 7/fg, 0/bg, 0/clip
    }
    i <- increment
    loop
  }
}

## UI stuff

fn mark-lines-dirty _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  var dest/edx: (addr boolean) <- get self, recreate-caches?
  copy-to *dest, 1/true
}

fn mark-lines-clean _self: (addr trace) {
  var self/eax: (addr trace) <- copy _self
  var dest/edx: (addr boolean) <- get self, recreate-caches?
  copy-to *dest, 0/false
}

fn render-trace screen: (addr screen), _self: (addr trace), xmin: int, ymin: int, xmax: int, ymax: int, show-cursor?: boolean -> _/ecx: int {
  var already-hiding-lines?: boolean
  var self/esi: (addr trace) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "null trace"
  }
  var y/ecx: int <- copy ymin
  # recreate caches if necessary
  var recreate-caches?/eax: (addr boolean) <- get self, recreate-caches?
  compare *recreate-caches?, 0/false
  {
    break-if-=
    # cache ymin
    var dest/eax: (addr int) <- get self, top-line-y
    copy-to *dest, y
    # cache ymax
    var ymax/ecx: int <- copy ymax
    dest <- get self, screen-height
    copy-to *dest, ymax
    #
    recompute-all-visible-lines self
    mark-lines-clean self
  }
  clamp-cursor-to-top self, y
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var max-addr/ebx: (addr int) <- get self, first-free
  var max/ebx: int <- copy *max-addr
  # display trace depth (not in tests)
  $render-trace:render-depth: {
    compare max, 0
    break-if-<=
    var max-depth/edx: (addr int) <- get self, max-depth
    {
      var width/eax: int <- copy 0
      var height/ecx: int <- copy 0
      width, height <- screen-size screen
      compare width, 0x80
      break-if-< $render-trace:render-depth
    }
    set-cursor-position screen, 0x70/x, y
    draw-text-rightward-from-cursor-over-full-screen screen, "trace depth: ", 0x17/fg, 0xc5/bg=blue-bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, *max-depth, 0x7/fg, 0xc5/bg=blue-bg
  }
  var top-line-addr/edx: (addr int) <- get self, top-line-index
  var i/edx: int <- copy *top-line-addr
  $render-trace:loop: {
    compare i, max
    break-if->=
    compare y, ymax
    break-if->=
    $render-trace:iter: {
      var offset/ebx: (offset trace-line) <- compute-offset trace, i
      var curr/ebx: (addr trace-line) <- index trace, offset
      var curr-label-ah/eax: (addr handle array byte) <- get curr, label
      var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
      var bg: int
      copy-to bg, 0xc5/bg=blue-bg
      var fg: int
      copy-to fg, 0x38/fg=trace
      compare show-cursor?, 0/false
      {
        break-if-=
        var cursor-y/eax: (addr int) <- get self, cursor-y
        compare *cursor-y, y
        break-if-!=
        copy-to bg, 7/trace-cursor-line-bg
        copy-to fg, 0x68/cursor-line-fg=sober-blue
        var cursor-line-index/eax: (addr int) <- get self, cursor-line-index
        copy-to *cursor-line-index, i
      }
      # always display errors
      {
        var curr-depth/eax: (addr int) <- get curr, depth
        compare *curr-depth, 0/error
        break-if-!=
        y <- render-trace-line screen, curr, xmin, y, xmax, ymax, 0xc/fg=trace-error, bg, 0/clip
        copy-to already-hiding-lines?, 0/false
        break $render-trace:iter
      }
      # display expanded lines
      var display?/eax: boolean <- should-render? curr
      {
        compare display?, 0/false
        break-if-=
        var unclip-cursor-line?/eax: boolean <- unclip-cursor-line? self, i
        y <- render-trace-line screen, curr, xmin, y, xmax, ymax, fg, bg, unclip-cursor-line?
        copy-to already-hiding-lines?, 0/false
        break $render-trace:iter
      }
      # ignore the rest
      compare already-hiding-lines?, 0/false
      {
        break-if-!=
        var x/eax: int <- copy xmin
        x, y <- draw-text-wrapping-right-then-down screen, "...", xmin, ymin, xmax, ymax, x, y, fg, bg
        y <- increment
        copy-to already-hiding-lines?, 1/true
      }
    }
    i <- increment
    loop
  }
  # prevent cursor from going too far down
  clamp-cursor-to-bottom self, y, screen, xmin, ymin, xmax, ymax
  return y
}

fn unclip-cursor-line? _self: (addr trace), _i: int -> _/eax: boolean {
  # if unclip? and i == *cursor-line-index, render unclipped
  var self/esi: (addr trace) <- copy _self
  var unclip-cursor-line?/eax: (addr boolean) <- get self, unclip-cursor-line?
  compare *unclip-cursor-line?, 0/false
  {
    break-if-!=
    return 0/false
  }
  var cursor-line-index/eax: (addr int) <- get self, cursor-line-index
  var i/ecx: int <- copy _i
  compare i, *cursor-line-index
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn render-trace-line screen: (addr screen), _self: (addr trace-line), xmin: int, ymin: int, xmax: int, ymax: int, fg: int, bg: int, unclip?: boolean -> _/ecx: int {
  var self/esi: (addr trace-line) <- copy _self
  var xsave/edx: int <- copy xmin
  var y/ecx: int <- copy ymin
  # show depth for non-errors
  var depth-a/ebx: (addr int) <- get self, depth
  compare *depth-a, 0/error
  {
    break-if-=
    var x/eax: int <- copy xsave
    {
      x, y <- draw-int32-decimal-wrapping-right-then-down screen, *depth-a, xmin, ymin, xmax, ymax, x, y, fg, bg
      x, y <- draw-text-wrapping-right-then-down screen, " ", xmin, ymin, xmax, ymax, x, y, fg, bg
      # don't show label in UI; it's just for tests
    }
    xsave <- copy x
  }
  var data-ah/eax: (addr handle array byte) <- get self, data
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data/ebx: (addr array byte) <- copy _data
  var x/eax: int <- copy xsave
  compare unclip?, 0/false
  {
    break-if-=
    x, y <- draw-text-wrapping-right-then-down screen, data, xmin, ymin, xmax, ymax, x, y, fg, bg
  }
  compare unclip?, 0/false
  {
    break-if-!=
    x <- draw-text-rightward screen, data, x, xmax, y, fg, bg
  }
  y <- increment
  return y
}

fn should-render? _line: (addr trace-line) -> _/eax: boolean {
  var line/eax: (addr trace-line) <- copy _line
  var result/eax: (addr boolean) <- get line, visible?
  return *result
}

# This is super-inefficient, string-comparing every trace line
# against every visible line.
fn recompute-all-visible-lines _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var max-addr/edx: (addr int) <- get self, first-free
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/esi: (addr array trace-line) <- copy _trace
  var i/ecx: int <- copy 0
  {
    compare i, *max-addr
    break-if->=
    var offset/ebx: (offset trace-line) <- compute-offset trace, i
    var curr/ebx: (addr trace-line) <- index trace, offset
    recompute-visibility _self, curr
    i <- increment
    loop
  }
}

fn recompute-visibility _self: (addr trace), _line: (addr trace-line) {
  var self/esi: (addr trace) <- copy _self
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
      return
    }
    i <- increment
    loop
  }
  var line/eax: (addr trace-line) <- copy _line
  var dest/eax: (addr boolean) <- get line, visible?
  copy-to *dest, 0/false
}

fn clamp-cursor-to-top _self: (addr trace), _y: int {
  var y/ecx: int <- copy _y
  var self/esi: (addr trace) <- copy _self
  var cursor-y/eax: (addr int) <- get self, cursor-y
  compare *cursor-y, y
  break-if->=
  copy-to *cursor-y, y
}

# extremely hacky; consider deleting test-render-trace-empty-3 when you clean this up
# TODO: duplicates logic for rendering a line
fn clamp-cursor-to-bottom _self: (addr trace), _y: int, screen: (addr screen), xmin: int, ymin: int, xmax: int, ymax: int {
  var y/ebx: int <- copy _y
  compare y, ymin
  {
    break-if->
    return
  }
  y <- decrement
  var self/esi: (addr trace) <- copy _self
  var cursor-y/eax: (addr int) <- get self, cursor-y
  compare *cursor-y, y
  break-if-<=
  copy-to *cursor-y, y
  # redraw cursor-line
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var trace/eax: (addr array trace-line) <- lookup *trace-ah
  var cursor-line-index-addr/ecx: (addr int) <- get self, cursor-line-index
  var cursor-line-index/ecx: int <- copy *cursor-line-index-addr
  var first-free/edx: (addr int) <- get self, first-free
  compare cursor-line-index, *first-free
  {
    break-if-<
    return
  }
  var cursor-offset/ecx: (offset trace-line) <- compute-offset trace, cursor-line-index
  var cursor-line/ecx: (addr trace-line) <- index trace, cursor-offset
  var display?/eax: boolean <- should-render? cursor-line
  {
    compare display?, 0/false
    break-if-=
    var dummy/ecx: int <- render-trace-line screen, cursor-line, xmin, y, xmax, ymax, 0x38/fg=trace, 7/cursor-line-bg, 0/clip
    return
  }
  var dummy1/eax: int <- copy 0
  var dummy2/ecx: int <- copy 0
  dummy1, dummy2 <- draw-text-wrapping-right-then-down screen, "...", xmin, ymin, xmax, ymax, xmin, y, 9/fg=trace, 7/cursor-line-bg
}

fn test-render-trace-empty {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 5/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 0, "F - test-render-trace-empty/cursor"
  check-screen-row screen,                                  0/y, "    ", "F - test-render-trace-empty"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "    ", "F - test-render-trace-empty/bg"
}

fn test-render-trace-empty-2 {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 2/ymin, 5/xmax, 4/ymax, 0/no-cursor  # cursor below top row
  #
  check-ints-equal y, 2, "F - test-render-trace-empty-2/cursor"
  check-screen-row screen,                                  2/y, "    ", "F - test-render-trace-empty-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "    ", "F - test-render-trace-empty-2/bg"
}

fn test-render-trace-empty-3 {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 2/ymin, 5/xmax, 4/ymax, 1/show-cursor  # try show cursor
  # still no cursor to show
  check-ints-equal y, 2, "F - test-render-trace-empty-3/cursor"
  check-screen-row screen,                                  1/y, "    ", "F - test-render-trace-empty-3/line-above-cursor"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "    ", "F - test-render-trace-empty-3/bg-for-line-above-cursor"
  check-screen-row screen,                                  2/y, "    ", "F - test-render-trace-empty-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "    ", "F - test-render-trace-empty-3/bg"
}

fn test-render-trace-collapsed-by-default {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  trace-text t, "l", "data"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 5/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 5/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 1, "F - test-render-trace-collapsed-by-default/cursor"
  check-screen-row screen, 0/y, "... ", "F - test-render-trace-collapsed-by-default"
}

fn test-render-trace-error {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  error t, "error"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 0/no-cursor
  #
  check-ints-equal y, 1, "F - test-render-trace-error/cursor"
  check-screen-row screen, 0/y, "error", "F - test-render-trace-error"
}

fn test-render-trace-error-at-start {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  error t, "error"
  trace-text t, "l", "data"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
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
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "data"
  error t, "error"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
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
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
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
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
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
  var height/edx: int <- copy y
  height <- increment
  clear-rect screen, 0/x, y, width, height, 0xc5/bg=blue-bg
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ^r ", width, 0/fg, 0x5c/bg=black
  draw-text-rightward-from-cursor screen, " run main  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^m ", width, 0/fg, 3/bg=keyboard
  draw-text-rightward-from-cursor screen, " to keyboard  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " enter/bksp ", width, 0/fg, 0x5c/bg=black
  draw-text-rightward-from-cursor screen, " expand/collapse  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^s ", width, 0/fg, 0x5c/bg=black
  draw-text-rightward-from-cursor screen, " show whole line  ", width, 7/fg, 0xc5/bg=blue-bg
}

fn edit-trace _self: (addr trace), key: grapheme {
  var self/esi: (addr trace) <- copy _self
  # cursor down
  {
    compare key, 0x6a/j
    break-if-!=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    increment *cursor-y
    var unclip-cursor-line?/eax: (addr boolean) <- get self, unclip-cursor-line?
    copy-to *unclip-cursor-line?, 0/false
    return
  }
  {
    compare key, 0x81/down-arrow
    break-if-!=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    increment *cursor-y
    var unclip-cursor-line?/eax: (addr boolean) <- get self, unclip-cursor-line?
    copy-to *unclip-cursor-line?, 0/false
    return
  }
  # cursor up
  {
    compare key, 0x6b/k
    break-if-!=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    decrement *cursor-y
    var unclip-cursor-line?/eax: (addr boolean) <- get self, unclip-cursor-line?
    copy-to *unclip-cursor-line?, 0/false
    return
  }
  {
    compare key, 0x82/up-arrow
    break-if-!=
    var cursor-y/eax: (addr int) <- get self, cursor-y
    decrement *cursor-y
    var unclip-cursor-line?/eax: (addr boolean) <- get self, unclip-cursor-line?
    copy-to *unclip-cursor-line?, 0/false
    return
  }
  # enter = expand
  {
    compare key, 0xa/newline
    break-if-!=
    expand self
    return
  }
  # backspace = collapse
  {
    compare key, 8/backspace
    break-if-!=
    collapse self
    return
  }
  # ctrl-s: temporarily unclip current line
  {
    compare key, 0x13/ctrl-s
    break-if-!=
    var unclip-cursor-line?/eax: (addr boolean) <- get self, unclip-cursor-line?
    copy-to *unclip-cursor-line?, 1/true
    return
  }
  # ctrl-f: scroll down
  {
    compare key, 6/ctrl-f
    break-if-!=
    scroll-down self
    return
  }
  # ctrl-b: scroll up
  {
    compare key, 2/ctrl-b
    break-if-!=
    scroll-up self
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
  var cursor-line-depth/ebx: (addr int) <- get cursor-line, depth
  var target-depth/ebx: int <- copy *cursor-line-depth
  # if cursor-line is already visible, do nothing
  compare *cursor-line-visible?, 0/false
  {
    break-if-=
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "visible", 7/fg 0/bg
    return
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

fn collapse _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var cursor-line-index-addr/ecx: (addr int) <- get self, cursor-line-index
  var cursor-line-index/ecx: int <- copy *cursor-line-index-addr
  var cursor-line-offset/eax: (offset trace-line) <- compute-offset trace, cursor-line-index
  var cursor-line/edx: (addr trace-line) <- index trace, cursor-line-offset
  var cursor-line-visible?/eax: (addr boolean) <- get cursor-line, visible?
  # if cursor-line is not visible, do nothing
  compare *cursor-line-visible?, 0/false
  {
    break-if-!=
    return
  }
  # hide all lines between previous and next line with a lower depth
  var cursor-line-depth/ebx: (addr int) <- get cursor-line, depth
  var cursor-y/edx: (addr int) <- get self, cursor-y
  var target-depth/ebx: int <- copy *cursor-line-depth
  var i/ecx: int <- copy cursor-line-index
  $collapse:loop1: {
    compare i, 0
    break-if-<
    var curr-line-offset/eax: (offset trace-line) <- compute-offset trace, i
    var curr-line/eax: (addr trace-line) <- index trace, curr-line-offset
    {
      var curr-line-depth/eax: (addr int) <- get curr-line, depth
      compare *curr-line-depth, target-depth
      break-if-< $collapse:loop1
    }
    # if cursor-line is visible, decrement cursor-y
    {
      var curr-line-visible?/eax: (addr boolean) <- get curr-line, visible?
      compare *curr-line-visible?, 0/false
      break-if-=
      decrement *cursor-y
    }
    i <- decrement
    loop
  }
  i <- increment
  var max/edx: (addr int) <- get self, first-free
  $collapse:loop2: {
    compare i, *max
    break-if->=
    var curr-line-offset/eax: (offset trace-line) <- compute-offset trace, i
    var curr-line/edx: (addr trace-line) <- index trace, curr-line-offset
    var curr-line-depth/eax: (addr int) <- get curr-line, depth
    compare *curr-line-depth, target-depth
    break-if-<
    {
      hide-trace-line self, curr-line
      var curr-line-visible?/eax: (addr boolean) <- get curr-line, visible?
      copy-to *curr-line-visible?, 0/false
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

fn hide-trace-line _self: (addr trace), line: (addr trace-line) {
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
    var found?/eax: boolean <- trace-lines-equal? curr, line
    compare found?, 0/false
    {
      break-if-=
      clear-object curr
    }
    i <- increment
    loop
  }
}

fn cursor-too-deep? _self: (addr trace) -> _/eax: boolean {
  var self/esi: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var _trace/eax: (addr array trace-line) <- lookup *trace-ah
  var trace/edi: (addr array trace-line) <- copy _trace
  var cursor-line-index-addr/ecx: (addr int) <- get self, cursor-line-index
  var cursor-line-index/ecx: int <- copy *cursor-line-index-addr
  var cursor-line-offset/eax: (offset trace-line) <- compute-offset trace, cursor-line-index
  var cursor-line/edx: (addr trace-line) <- index trace, cursor-line-offset
  var cursor-line-visible?/eax: (addr boolean) <- get cursor-line, visible?
  var cursor-line-depth/ebx: (addr int) <- get cursor-line, depth
  var target-depth/ebx: int <- copy *cursor-line-depth
  # if cursor-line is visible, return false
  compare *cursor-line-visible?, 0/false
  {
    break-if-=
    return 0/false
  }
  # return cursor-line-depth >= max-depth-1
  target-depth <- increment
  var max-depth-addr/eax: (addr int) <- get self, max-depth
  compare target-depth, *max-depth-addr
  {
    break-if-<
    return 1/true
  }
  return 0/false
}

fn test-cursor-down-and-up-within-trace {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
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
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-and-up-within-trace/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-cursor-down-and-up-within-trace/down-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-and-up-within-trace/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "||||| ", "F - test-cursor-down-and-up-within-trace/down-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-and-up-within-trace/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-cursor-down-and-up-within-trace/down-2/cursor"
  # cursor up
  edit-trace t, 0x6b/k
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
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  error t, "error"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0xa/width, 4/height, 0/no-pixel-graphics
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
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  # hack: we do need to render to make this test pass; we're mixing state management with rendering
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0xa/xmax, 4/ymax, 1/show-cursor
  # cursor clamps at bottom
  check-screen-row screen,                                  0/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-cursor-down-past-bottom-of-trace/down-0/cursor"
  check-screen-row screen,                                  1/y, "error ", "F - test-cursor-down-past-bottom-of-trace/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-cursor-down-past-bottom-of-trace/down-1/cursor"
  check-screen-row screen,                                  2/y, "...   ", "F - test-cursor-down-past-bottom-of-trace/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "|||   ", "F - test-cursor-down-past-bottom-of-trace/down-2/cursor"
}

fn test-expand-within-trace {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...      ", "F - test-expand-within-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||      ", "F - test-expand-within-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "         ", "F - test-expand-within-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "         ", "F - test-expand-within-trace/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1 ", "F - test-expand-within-trace/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||| ", "F - test-expand-within-trace/expand-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2 ", "F - test-expand-within-trace/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "         ", "F - test-expand-within-trace/expand-1/cursor"
  check-screen-row screen,                                  2/y, "         ", "F - test-expand-within-trace/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "         ", "F - test-expand-within-trace/expand-2/cursor"
}

fn test-trace-expand-skips-lower-depth {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...      ", "F - test-trace-expand-skips-lower-depth/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||      ", "F - test-trace-expand-skips-lower-depth/pre-0/cursor"
  check-screen-row screen,                                  1/y, "         ", "F - test-trace-expand-skips-lower-depth/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "         ", "F - test-trace-expand-skips-lower-depth/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1 ", "F - test-trace-expand-skips-lower-depth/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||| ", "F - test-trace-expand-skips-lower-depth/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...      ", "F - test-trace-expand-skips-lower-depth/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "         ", "F - test-trace-expand-skips-lower-depth/expand-1/cursor"
  check-screen-row screen,                                  2/y, "         ", "F - test-trace-expand-skips-lower-depth/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "         ", "F - test-trace-expand-skips-lower-depth/expand-2/cursor"
}

fn test-trace-expand-continues-past-lower-depth {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...      ", "F - test-trace-expand-continues-past-lower-depth/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||      ", "F - test-trace-expand-continues-past-lower-depth/pre-0/cursor"
  check-screen-row screen,                                  1/y, "         ", "F - test-trace-expand-continues-past-lower-depth/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "         ", "F - test-trace-expand-continues-past-lower-depth/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1 ", "F - test-trace-expand-continues-past-lower-depth/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||| ", "F - test-trace-expand-continues-past-lower-depth/expand-0/cursor"
  # TODO: might be too wasteful to show every place where lines are hidden
  check-screen-row screen,                                  1/y, "...      ", "F - test-trace-expand-continues-past-lower-depth/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "         ", "F - test-trace-expand-continues-past-lower-depth/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2 ", "F - test-trace-expand-continues-past-lower-depth/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "         ", "F - test-trace-expand-continues-past-lower-depth/expand-2/cursor"
}

fn test-trace-expand-stops-at-higher-depth {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-lower t
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
  initialize-screen screen, 0x10/width, 8/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-expand-stops-at-higher-depth/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-expand-stops-at-higher-depth/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-expand-stops-at-higher-depth/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-expand-stops-at-higher-depth/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "2 line 1.1 ", "F - test-trace-expand-stops-at-higher-depth/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||||||||| ", "F - test-trace-expand-stops-at-higher-depth/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-expand-stops-at-higher-depth/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-expand-stops-at-higher-depth/expand-1/cursor"
  check-screen-row screen,                                  2/y, "2 line 1.2 ", "F - test-trace-expand-stops-at-higher-depth/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-expand-stops-at-higher-depth/expand-2/cursor"
  check-screen-row screen,                                  3/y, "...        ", "F - test-trace-expand-stops-at-higher-depth/expand-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-expand-stops-at-higher-depth/expand-3/cursor"
  check-screen-row screen,                                  4/y, "           ", "F - test-trace-expand-stops-at-higher-depth/expand-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "           ", "F - test-trace-expand-stops-at-higher-depth/expand-4/cursor"
}

fn test-trace-expand-twice {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-expand-twice/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-expand-twice/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-expand-twice/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-expand-twice/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-expand-twice/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-expand-twice/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-expand-twice/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-expand-twice/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-expand-twice/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-expand-twice/expand-2/cursor"
  # cursor down
  edit-trace t, 0x6a/j
  # hack: we need to render here to make this test pass; we're mixing state management with rendering
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-expand-twice/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-expand-twice/down-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-expand-twice/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||        ", "F - test-trace-expand-twice/down-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-expand-twice/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-expand-twice/down-2/cursor"
  # expand again
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-expand-twice/expand2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-expand-twice/expand2-0/cursor"
  check-screen-row screen,                                  1/y, "2 line 1.1 ", "F - test-trace-expand-twice/expand2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||||||||| ", "F - test-trace-expand-twice/expand2-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-expand-twice/expand2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-expand-twice/expand2-2/cursor"
}

fn test-trace-refresh-cursor {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-refresh-cursor/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-refresh-cursor/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-refresh-cursor/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-refresh-cursor/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-refresh-cursor/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-refresh-cursor/expand-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-refresh-cursor/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-refresh-cursor/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-refresh-cursor/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-refresh-cursor/expand-2/cursor"
  # cursor down
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-refresh-cursor/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-refresh-cursor/down-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-refresh-cursor/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-refresh-cursor/down-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-refresh-cursor/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "||||||||   ", "F - test-trace-refresh-cursor/down-2/cursor"
  # recreate trace
  clear-trace t
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # cursor remains unchanged
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-refresh-cursor/refresh-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-refresh-cursor/refresh-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-refresh-cursor/refresh-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-refresh-cursor/refresh-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-refresh-cursor/refresh-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "||||||||   ", "F - test-trace-refresh-cursor/refresh-2/cursor"
}

fn test-trace-preserve-cursor-on-refresh {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-preserve-cursor-on-refresh/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-preserve-cursor-on-refresh/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-preserve-cursor-on-refresh/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-preserve-cursor-on-refresh/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-preserve-cursor-on-refresh/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-preserve-cursor-on-refresh/expand-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-preserve-cursor-on-refresh/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-preserve-cursor-on-refresh/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-preserve-cursor-on-refresh/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-trace-preserve-cursor-on-refresh/expand-2/cursor"
  # cursor down
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-preserve-cursor-on-refresh/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-preserve-cursor-on-refresh/down-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-preserve-cursor-on-refresh/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-preserve-cursor-on-refresh/down-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-preserve-cursor-on-refresh/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "||||||||   ", "F - test-trace-preserve-cursor-on-refresh/down-2/cursor"
  # recreate trace with slightly different lines
  clear-trace t
  trace-text t, "l", "line 4"
  trace-text t, "l", "line 5"
  trace-text t, "l", "line 3"  # cursor line is unchanged
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # cursor remains unchanged
  check-screen-row screen,                                  0/y, "1 line 4   ", "F - test-trace-preserve-cursor-on-refresh/refresh-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-preserve-cursor-on-refresh/refresh-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 5   ", "F - test-trace-preserve-cursor-on-refresh/refresh-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-preserve-cursor-on-refresh/refresh-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-preserve-cursor-on-refresh/refresh-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "||||||||   ", "F - test-trace-preserve-cursor-on-refresh/refresh-2/cursor"
}

fn test-trace-keep-cursor-visible-on-refresh {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-keep-cursor-visible-on-refresh/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-keep-cursor-visible-on-refresh/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-keep-cursor-visible-on-refresh/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-keep-cursor-visible-on-refresh/expand-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-keep-cursor-visible-on-refresh/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-keep-cursor-visible-on-refresh/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "              ", "F - test-trace-keep-cursor-visible-on-refresh/expand-2/cursor"
  # cursor down
  edit-trace t, 0x6a/j
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-keep-cursor-visible-on-refresh/down-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/down-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-keep-cursor-visible-on-refresh/down-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/down-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 3   ", "F - test-trace-keep-cursor-visible-on-refresh/down-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "||||||||   ", "F - test-trace-keep-cursor-visible-on-refresh/down-2/cursor"
  # recreate trace with entirely different lines
  clear-trace t
  trace-text t, "l", "line 4"
  trace-text t, "l", "line 5"
  trace-text t, "l", "line 6"
  mark-lines-dirty t
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # trace collapses, and cursor bumps up
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-keep-cursor-visible-on-refresh/refresh-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-keep-cursor-visible-on-refresh/refresh-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/refresh-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/refresh-1/cursor"
  check-screen-row screen,                                  2/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/refresh-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-keep-cursor-visible-on-refresh/refresh-2/cursor"
}

fn test-trace-collapse-at-top {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-at-top/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-at-top/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-at-top/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-at-top/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-at-top/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-collapse-at-top/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-collapse-at-top/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-at-top/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-at-top/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-collapse-at-top/expand-2/cursor"
  # collapse
  edit-trace t, 8/backspace
  # hack: we need to render here to make this test pass; we're mixing state management with rendering
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-ints-equal y, 1, "F - test-trace-collapse-at-top/post-0/y"
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-at-top/post-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-at-top/post-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-at-top/post-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-at-top/post-1/cursor"
}

fn test-trace-collapse {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-collapse/expand-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 2   ", "F - test-trace-collapse/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse/expand-1/cursor"
  # cursor down
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # collapse
  edit-trace t, 8/backspace
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-ints-equal y, 1, "F - test-trace-collapse/post-0/y"
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse/post-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse/post-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse/post-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse/post-1/cursor"
}

fn test-trace-collapse-skips-invisible-lines {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-skips-invisible-lines/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-skips-invisible-lines/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-skips-invisible-lines/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-skips-invisible-lines/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # two visible lines with an invisible line in between
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-skips-invisible-lines/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-collapse-skips-invisible-lines/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-collapse-skips-invisible-lines/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-skips-invisible-lines/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-skips-invisible-lines/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-collapse-skips-invisible-lines/expand-2/cursor"
  # cursor down to second visible line
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # collapse
  edit-trace t, 8/backspace
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-ints-equal y, 1, "F - test-trace-collapse-skips-invisible-lines/post-0/y"
  var cursor-y/eax: (addr int) <- get t, cursor-y
  check-ints-equal *cursor-y, 0, "F - test-trace-collapse-skips-invisible-lines/post-0/cursor-y"
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-skips-invisible-lines/post-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-skips-invisible-lines/post-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-skips-invisible-lines/post-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-skips-invisible-lines/post-1/cursor"
}

fn test-trace-collapse-two-levels {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-two-levels/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-two-levels/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-two-levels/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-two-levels/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # two visible lines with an invisible line in between
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-two-levels/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-collapse-two-levels/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-collapse-two-levels/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-two-levels/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-two-levels/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-collapse-two-levels/expand-2/cursor"
  # cursor down to ellipses
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # two visible lines with an invisible line in between
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-two-levels/expand2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-collapse-two-levels/expand2-0/cursor"
  check-screen-row screen,                                  1/y, "2 line 1.1 ", "F - test-trace-collapse-two-levels/expand2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||||||||| ", "F - test-trace-collapse-two-levels/expand2-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-two-levels/expand2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-collapse-two-levels/expand2-2/cursor"
  # cursor down to second visible line
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # collapse
  edit-trace t, 8/backspace
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-ints-equal y, 1, "F - test-trace-collapse-two-levels/post-0/y"
  var cursor-y/eax: (addr int) <- get t, cursor-y
  check-ints-equal *cursor-y, 0, "F - test-trace-collapse-two-levels/post-0/cursor-y"
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-two-levels/post-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-two-levels/post-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-two-levels/post-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-two-levels/post-1/cursor"
}

fn test-trace-collapse-nested-level {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 1"
  trace-lower t
  trace-text t, "l", "line 1.1"
  trace-higher t
  trace-text t, "l", "line 2"
  trace-lower t
  trace-text t, "l", "line 2.1"
  trace-text t, "l", "line 2.2"
  trace-higher t
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 8/height, 0/no-pixel-graphics
  #
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-collapse-nested-level/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-collapse-nested-level/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-collapse-nested-level/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-nested-level/pre-1/cursor"
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  # two visible lines with an invisible line in between
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-nested-level/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-collapse-nested-level/expand-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-collapse-nested-level/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-nested-level/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-nested-level/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-collapse-nested-level/expand-2/cursor"
  check-screen-row screen,                                  3/y, "...        ", "F - test-trace-collapse-nested-level/expand-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-collapse-nested-level/expand-3/cursor"
  # cursor down to bottom
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  edit-trace t, 0x6a/j
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  # expand
  edit-trace t, 0xa/enter
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  # two visible lines with an invisible line in between
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-nested-level/expand2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-collapse-nested-level/expand2-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-collapse-nested-level/expand2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-nested-level/expand2-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-nested-level/expand2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-collapse-nested-level/expand2-2/cursor"
  check-screen-row screen,                                  3/y, "2 line 2.1 ", "F - test-trace-collapse-nested-level/expand2-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "|||||||||| ", "F - test-trace-collapse-nested-level/expand2-3/cursor"
  check-screen-row screen,                                  4/y, "2 line 2.2 ", "F - test-trace-collapse-nested-level/expand2-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "           ", "F - test-trace-collapse-nested-level/expand2-4/cursor"
  # collapse
  edit-trace t, 8/backspace
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 8/ymax, 1/show-cursor
  #
  check-ints-equal y, 4, "F - test-trace-collapse-nested-level/post-0/y"
  var cursor-y/eax: (addr int) <- get t, cursor-y
  check-ints-equal *cursor-y, 2, "F - test-trace-collapse-nested-level/post-0/cursor-y"
  check-screen-row screen,                                  0/y, "1 line 1   ", "F - test-trace-collapse-nested-level/post-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "           ", "F - test-trace-collapse-nested-level/post-0/cursor"
  check-screen-row screen,                                  1/y, "...        ", "F - test-trace-collapse-nested-level/post-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-collapse-nested-level/post-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-collapse-nested-level/post-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "||||||||   ", "F - test-trace-collapse-nested-level/post-2/cursor"
  check-screen-row screen,                                  3/y, "...        ", "F - test-trace-collapse-nested-level/post-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-collapse-nested-level/post-3/cursor"
}

fn scroll-down _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var screen-height-addr/ebx: (addr int) <- get self, screen-height  # only available after first render
  var lines-to-skip/ebx: int <- copy *screen-height-addr
  var top-line-y-addr/eax: (addr int) <- get self, top-line-y
  lines-to-skip <- subtract *top-line-y-addr
  var already-hiding-lines-storage: boolean
  var already-hiding-lines/edx: (addr boolean) <- address already-hiding-lines-storage
  var top-line-addr/edi: (addr int) <- get self, top-line-index
  var i/eax: int <- copy *top-line-addr
  var max-addr/ecx: (addr int) <- get self, first-free
  {
    # if we run out of trace, return without changing anything
    compare i, *max-addr
    {
      break-if-<
      return
    }
    # if we've skipped enough, break
    compare lines-to-skip, 0
    break-if-<=
    #
    {
      var display?/eax: boolean <- count-line? self, i, already-hiding-lines
      compare display?, 0/false
      break-if-=
      lines-to-skip <- decrement
    }
    i <- increment
    loop
  }
  # update top-line
  copy-to *top-line-addr, i
}

fn scroll-up _self: (addr trace) {
  var self/esi: (addr trace) <- copy _self
  var screen-height-addr/ebx: (addr int) <- get self, screen-height  # only available after first render
  var lines-to-skip/ebx: int <- copy *screen-height-addr
  var top-line-y-addr/eax: (addr int) <- get self, top-line-y
  lines-to-skip <- subtract *top-line-y-addr
  var already-hiding-lines-storage: boolean
  var already-hiding-lines/edx: (addr boolean) <- address already-hiding-lines-storage
  var top-line-addr/ecx: (addr int) <- get self, top-line-index
  $scroll-up:loop: {
    # if we run out of trace, break
    compare *top-line-addr, 0
    break-if-<=
    # if we've skipped enough, break
    compare lines-to-skip, 0
    break-if-<=
    #
    var display?/eax: boolean <- count-line? self, *top-line-addr, already-hiding-lines
    compare display?, 0/false
    {
      break-if-=
      lines-to-skip <- decrement
    }
    decrement *top-line-addr
    loop
  }
}

# TODO: duplicates logic for counting lines rendered
fn count-line? _self: (addr trace), index: int, _already-hiding-lines?: (addr boolean) -> _/eax: boolean {
  var self/esi: (addr trace) <- copy _self
  var trace-ah/eax: (addr handle array trace-line) <- get self, data
  var trace/eax: (addr array trace-line) <- lookup *trace-ah
  var offset/ecx: (offset trace-line) <- compute-offset trace, index
  var curr/eax: (addr trace-line) <- index trace, offset
  var already-hiding-lines?/ecx: (addr boolean) <- copy _already-hiding-lines?
  # count errors
  {
    var curr-depth/eax: (addr int) <- get curr, depth
    compare *curr-depth, 0/error
    break-if-!=
    copy-to *already-hiding-lines?, 0/false
    return 1/true
  }
  # count visible lines
  {
    var display?/eax: boolean <- should-render? curr
    compare display?, 0/false
    break-if-=
    copy-to *already-hiding-lines?, 0/false
    return 1/true
  }
  # count first undisplayed line after line to display
  compare *already-hiding-lines?, 0/false
  {
    break-if-!=
    copy-to *already-hiding-lines?, 1/true
    return 1/true
  }
  return 0/false
}

fn test-trace-scroll {
  var t-storage: trace
  var t/esi: (addr trace) <- address t-storage
  initialize-trace t, 0x100/max-depth, 0x10, 0x10
  #
  trace-text t, "l", "line 0"
  trace-text t, "l", "line 1"
  trace-text t, "l", "line 2"
  trace-text t, "l", "line 3"
  trace-text t, "l", "line 4"
  trace-text t, "l", "line 5"
  trace-text t, "l", "line 6"
  trace-text t, "l", "line 7"
  trace-text t, "l", "line 8"
  trace-text t, "l", "line 9"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x10/width, 4/height, 0/no-pixel-graphics
  # pre-render
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "...        ", "F - test-trace-scroll/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "|||        ", "F - test-trace-scroll/pre-0/cursor"
  check-screen-row screen,                                  1/y, "           ", "F - test-trace-scroll/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/pre-1/cursor"
  check-screen-row screen,                                  2/y, "           ", "F - test-trace-scroll/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/pre-2/cursor"
  check-screen-row screen,                                  3/y, "           ", "F - test-trace-scroll/pre-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/pre-3/cursor"
  # expand
  edit-trace t, 0xa/enter
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  #
  check-screen-row screen,                                  0/y, "1 line 0   ", "F - test-trace-scroll/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/expand-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 1   ", "F - test-trace-scroll/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/expand-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-scroll/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/expand-2/cursor"
  check-screen-row screen,                                  3/y, "1 line 3   ", "F - test-trace-scroll/expand-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/expand-3/cursor"
  # scroll up
  # hack: we must have rendered before this point; we're mixing state management with rendering
  edit-trace t, 2/ctrl-b
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # no change since we're already at the top
  check-screen-row screen,                                  0/y, "1 line 0   ", "F - test-trace-scroll/up0-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/up0-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 1   ", "F - test-trace-scroll/up0-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/up0-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-scroll/up0-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/up0-2/cursor"
  check-screen-row screen,                                  3/y, "1 line 3   ", "F - test-trace-scroll/up0-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/up0-3/cursor"
  # scroll down
  edit-trace t, 6/ctrl-f
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  check-screen-row screen,                                  0/y, "1 line 4   ", "F - test-trace-scroll/down1-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/down1-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 5   ", "F - test-trace-scroll/down1-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/down1-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 6   ", "F - test-trace-scroll/down1-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/down1-2/cursor"
  check-screen-row screen,                                  3/y, "1 line 7   ", "F - test-trace-scroll/down1-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/down1-3/cursor"
  # scroll down
  edit-trace t, 6/ctrl-f
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  check-screen-row screen,                                  0/y, "1 line 8   ", "F - test-trace-scroll/down2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/down2-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 9   ", "F - test-trace-scroll/down2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/down2-1/cursor"
  check-screen-row screen,                                  2/y, "           ", "F - test-trace-scroll/down2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/down2-2/cursor"
  check-screen-row screen,                                  3/y, "           ", "F - test-trace-scroll/down2-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/down2-3/cursor"
  # scroll down
  edit-trace t, 6/ctrl-f
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  # no change since we're already at the bottom
  check-screen-row screen,                                  0/y, "1 line 8   ", "F - test-trace-scroll/down3-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/down3-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 9   ", "F - test-trace-scroll/down3-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/down3-1/cursor"
  check-screen-row screen,                                  2/y, "           ", "F - test-trace-scroll/down3-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/down3-2/cursor"
  check-screen-row screen,                                  3/y, "           ", "F - test-trace-scroll/down3-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/down3-3/cursor"
  # scroll up
  edit-trace t, 2/ctrl-b
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  check-screen-row screen,                                  0/y, "1 line 4   ", "F - test-trace-scroll/up1-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/up1-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 5   ", "F - test-trace-scroll/up1-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/up1-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 6   ", "F - test-trace-scroll/up1-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/up1-2/cursor"
  check-screen-row screen,                                  3/y, "1 line 7   ", "F - test-trace-scroll/up1-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/up1-3/cursor"
  # scroll up
  edit-trace t, 2/ctrl-b
  clear-screen screen
  var y/ecx: int <- render-trace screen, t, 0/xmin, 0/ymin, 0x10/xmax, 4/ymax, 1/show-cursor
  check-screen-row screen,                                  0/y, "1 line 0   ", "F - test-trace-scroll/up2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "||||||||   ", "F - test-trace-scroll/up2-0/cursor"
  check-screen-row screen,                                  1/y, "1 line 1   ", "F - test-trace-scroll/up2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "           ", "F - test-trace-scroll/up2-1/cursor"
  check-screen-row screen,                                  2/y, "1 line 2   ", "F - test-trace-scroll/up2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "           ", "F - test-trace-scroll/up2-2/cursor"
  check-screen-row screen,                                  3/y, "1 line 3   ", "F - test-trace-scroll/up2-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "           ", "F - test-trace-scroll/up2-3/cursor"
}

# saving and restoring trace indices

fn save-indices _self: (addr trace), _out: (addr trace-index-stash) {
  var self/esi: (addr trace) <- copy _self
  var out/edi: (addr trace-index-stash) <- copy _out
  var data-ah/eax: (addr handle array trace-line) <- get self, data
  var _data/eax: (addr array trace-line) <- lookup *data-ah
  var data/ebx: (addr array trace-line) <- copy _data
  # cursor
  var cursor-line-index-addr/eax: (addr int) <- get self, cursor-line-index
  var cursor-line-index/eax: int <- copy *cursor-line-index-addr
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, cursor-line-index, 2/fg 0/bg
  var offset/eax: (offset trace-line) <- compute-offset data, cursor-line-index
  var cursor-line/ecx: (addr trace-line) <- index data, offset
  var src/eax: (addr int) <- get cursor-line, depth
  var dest/edx: (addr int) <- get out, cursor-line-depth
  copy-object src, dest
  var src/eax: (addr handle array byte) <- get cursor-line, label
  var dest/edx: (addr handle array byte) <- get out, cursor-line-label
  copy-object src, dest
  src <- get cursor-line, data
#?   {
#?     var foo/eax: (addr array byte) <- lookup *src
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 7/fg 0/bg
#?     var cursor-line-visible-addr/eax: (addr boolean) <- get cursor-line, visible?
#?     var cursor-line-visible?/eax: boolean <- copy *cursor-line-visible-addr
#?     var foo/eax: int <- copy cursor-line-visible?
#?     draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 5/fg 0/bg
#?   }
  dest <- get out, cursor-line-data
  copy-object src, dest
  # top of screen
  var top-line-index-addr/eax: (addr int) <- get self, top-line-index
  var top-line-index/eax: int <- copy *top-line-index-addr
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, top-line-index, 2/fg 0/bg
  var offset/eax: (offset trace-line) <- compute-offset data, top-line-index
  var top-line/ecx: (addr trace-line) <- index data, offset
  var src/eax: (addr int) <- get top-line, depth
  var dest/edx: (addr int) <- get out, top-line-depth
  copy-object src, dest
  var src/eax: (addr handle array byte) <- get top-line, label
  var dest/edx: (addr handle array byte) <- get out, top-line-label
  copy-object src, dest
  src <- get top-line, data
  dest <- get out, top-line-data
  copy-object src, dest
}

fn restore-indices _self: (addr trace), _in: (addr trace-index-stash) {
  var self/edi: (addr trace) <- copy _self
  var in/esi: (addr trace-index-stash) <- copy _in
  var data-ah/eax: (addr handle array trace-line) <- get self, data
  var _data/eax: (addr array trace-line) <- lookup *data-ah
  var data/ebx: (addr array trace-line) <- copy _data
  # cursor
  var cursor-depth/edx: (addr int) <- get in, cursor-line-depth
  var cursor-line-label-ah/eax: (addr handle array byte) <- get in, cursor-line-label
  var _cursor-line-label/eax: (addr array byte) <- lookup *cursor-line-label-ah
  var cursor-line-label/ecx: (addr array byte) <- copy _cursor-line-label
  var cursor-line-data-ah/eax: (addr handle array byte) <- get in, cursor-line-data
  var cursor-line-data/eax: (addr array byte) <- lookup *cursor-line-data-ah
  var new-cursor-line-index/eax: int <- find-in-trace self, *cursor-depth, cursor-line-label, cursor-line-data
  var dest/edx: (addr int) <- get self, cursor-line-index
  copy-to *dest, new-cursor-line-index
  # top of screen
  var top-depth/edx: (addr int) <- get in, top-line-depth
  var top-line-label-ah/eax: (addr handle array byte) <- get in, top-line-label
  var _top-line-label/eax: (addr array byte) <- lookup *top-line-label-ah
  var top-line-label/ecx: (addr array byte) <- copy _top-line-label
  var top-line-data-ah/eax: (addr handle array byte) <- get in, top-line-data
  var top-line-data/eax: (addr array byte) <- lookup *top-line-data-ah
  var new-top-line-index/eax: int <- find-in-trace self, *top-depth, top-line-label, top-line-data
  var dest/edx: (addr int) <- get self, top-line-index
  copy-to *dest, new-top-line-index
}

# like trace-contains? but stateless
# this is super-inefficient, string comparing every trace line
fn find-in-trace _self: (addr trace), depth: int, label: (addr array byte), data: (addr array byte) -> _/eax: int {
  var self/esi: (addr trace) <- copy _self
  var candidates-ah/eax: (addr handle array trace-line) <- get self, data
  var candidates/eax: (addr array trace-line) <- lookup *candidates-ah
  var i/ecx: int <- copy 0
  var max/edx: (addr int) <- get self, first-free
  {
    compare i, *max
    break-if->=
    {
      var curr-offset/edx: (offset trace-line) <- compute-offset candidates, i
      var curr/edx: (addr trace-line) <- index candidates, curr-offset
      # if curr->depth does not match, continue
      var curr-depth-addr/eax: (addr int) <- get curr, depth
      var curr-depth/eax: int <- copy *curr-depth-addr
      compare curr-depth, depth
      break-if-!=
      # if curr->label does not match, continue
      var curr-label-ah/eax: (addr handle array byte) <- get curr, label
      var curr-label/eax: (addr array byte) <- lookup *curr-label-ah
      var match?/eax: boolean <- string-equal? curr-label, label
      compare match?, 0/false
      break-if-=
      # if curr->data does not match, continue
      var curr-data-ah/eax: (addr handle array byte) <- get curr, data
      var curr-data/eax: (addr array byte) <- lookup *curr-data-ah
      {
        var match?/eax: boolean <- string-equal? curr-data, data
        compare match?, 0/false
      }
      break-if-=
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " => ", 7/fg 0/bg
#? #?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, i, 4/fg 0/bg
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, curr-data, 7/fg 0/bg
#?       var curr-visible-addr/eax: (addr boolean) <- get curr, visible?
#?       var curr-visible?/eax: boolean <- copy *curr-visible-addr
#?       var foo/eax: int <- copy curr-visible?
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 2/fg 0/bg
      return i
    }
    i <- increment
    loop
  }
  abort "not in trace"
  return -1
}

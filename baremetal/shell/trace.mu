# A trace records the evolution of a computation.
# An integral part of the Mu Shell is facilities for browsing traces.

type trace {
  curr-depth: int
  data: (handle stream trace-line)
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

fn error self: (addr trace), data: (addr array byte) {
  var s: (stream byte 0x100)
  var s-a/eax: (addr stream byte) <- address s
  write s-a, data
  trace self, "error", s-a
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

fn render-trace screen: (addr screen), _self: (addr trace), xmin: int, ymin: int, xmax: int, ymax: int -> _/ecx: int {
  var x/eax: int <- copy xmin
  var y/ecx: int <- copy ymin
  x, y <- draw-text-wrapping-right-then-down screen, "...", xmin, ymin, xmax, ymax, x, y, 9/fg=trace, 0/bg
  return y
}

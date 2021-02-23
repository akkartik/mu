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

fn has-errors? _self: (addr trace) -> _/eax: boolean {
  return 0/false
}

fn trace _self: (addr trace), label: (addr array byte), data: (array stream byte) {
}

fn new-trace-line depth: int, label: (addr array byte), data: (array stream byte), out: (addr trace-line) {
}

fn trace-lower _self: (addr trace) {
}

fn trace-higher _self: (addr trace) {
}

fn render-trace screen: (addr screen), _self: (addr trace), _x: int, _y: int {
}

type word {
  data: gap-buffer
  next: (handle word)
  prev: (handle word)
}

fn initialize-word _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  initialize-gap-buffer data
}

## some helpers for creating words. mostly for tests

fn initialize-word-with _self: (addr word), s: (addr array byte) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  initialize-gap-buffer-with data, s
}

fn allocate-word-with _out: (addr handle word), s: (addr array byte) {
  var out/eax: (addr handle word) <- copy _out
  allocate out
  var out-addr/eax: (addr word) <- lookup *out
  initialize-word-with out-addr, s
}

# just for tests for now
# TODO: handle existing next
# one implication of handles: append must take a handle
fn append-word-with self-h: (handle word), s: (addr array byte) {
  var self/eax: (addr word) <- lookup self-h
  var next-ah/eax: (addr handle word) <- get self, next
  allocate-word-with next-ah, s
  var next/eax: (addr word) <- lookup *next-ah
  var prev-ah/eax: (addr handle word) <- get next, prev
  copy-handle self-h, prev-ah
}

# just for tests for now
# TODO: handle existing prev
fn prepend-word-with self-h: (handle word), s: (addr array byte) {
  var self/eax: (addr word) <- lookup self-h
  var prev-ah/eax: (addr handle word) <- get self, prev
  allocate-word-with prev-ah, s
  var prev/eax: (addr word) <- lookup *prev-ah
  var next-ah/eax: (addr handle word) <- get prev, next
  copy-handle self-h, next-ah
}

## real primitives

fn word-equal? _self: (addr word), s: (addr array byte) -> result/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  result <- gap-buffer-equal? data, s
}

fn word-length _self: (addr word) -> result/eax: int {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  result <- gap-buffer-length data
}

fn first-word _self: (addr word) -> result/eax: (addr word) {
  var self/esi: (addr word) <- copy _self
  var out/edi: (addr word) <- copy self
  var prev/esi: (addr handle word) <- get self, prev
  {
    var curr/eax: (addr word) <- lookup *prev
    compare curr, 0
    break-if-=
    out <- copy curr
    prev <- get curr, prev
    loop
  }
  result <- copy out
}

fn final-word _self: (addr word) -> result/eax: (addr word) {
  var self/esi: (addr word) <- copy _self
  var out/edi: (addr word) <- copy self
  var next/esi: (addr handle word) <- get self, next
  {
    var curr/eax: (addr word) <- lookup *next
    compare curr, 0
    break-if-=
    out <- copy curr
    next <- get curr, next
    loop
  }
  result <- copy out
}

fn add-grapheme-to-word _self: (addr word), c: grapheme {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  add-grapheme-at-gap data, c
}

fn cursor-at-start? _self: (addr word) -> result/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  result <- gap-at-start? data
}

fn cursor-at-end? _self: (addr word) -> result/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  result <- gap-at-end? data
}

fn cursor-left _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  var dummy/eax: grapheme <- gap-left data
}

fn cursor-right _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  var dummy/eax: grapheme <- gap-right data
}

fn cursor-to-start _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  gap-to-start data
}

fn cursor-to-end _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  gap-to-end data
}

fn print-word screen: (addr screen), _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  render-gap-buffer screen, data
}

# TODO: handle existing next
# one implication of handles: append must take a handle
fn append-word _self-ah: (addr handle word) {
  var self-ah/esi: (addr handle word) <- copy _self-ah
  var self/eax: (addr word) <- lookup *self-ah
  var next-ah/eax: (addr handle word) <- get self, next
  allocate next-ah
  var next/eax: (addr word) <- lookup *next-ah
  initialize-word next
  var prev-ah/eax: (addr handle word) <- get next, prev
  copy-handle *self-ah, prev-ah
}

fn emit-word _self: (addr word), out: (addr stream byte) {
  var self/esi: (addr word) <- copy _self
  var data/eax: (addr gap-buffer) <- get self, data
  emit-gap-buffer data, out
}

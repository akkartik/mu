fn initialize-word _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data
  # TODO: sometimes initialize box-data rather than scalar-data
}

## some helpers for creating words. mostly for tests

fn initialize-word-with _self: (addr word), s: (addr array byte) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
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

fn move-word-contents _src-ah: (addr handle word), _dest-ah: (addr handle word) {
  var dest-ah/eax: (addr handle word) <- copy _dest-ah
  var _dest/eax: (addr word) <- lookup *dest-ah
  var dest/edi: (addr word) <- copy _dest
  var src-ah/eax: (addr handle word) <- copy _src-ah
  var _src/eax: (addr word) <- lookup *src-ah
  var src/esi: (addr word) <- copy _src
  cursor-to-start src
  var src-data-ah/eax: (addr handle gap-buffer) <- get src, scalar-data
  var src-data/eax: (addr gap-buffer) <- lookup *src-data-ah
  var src-stack/ecx: (addr grapheme-stack) <- get src-data, right
  {
    var done?/eax: boolean <- grapheme-stack-empty? src-stack
    compare done?, 0  # false
    break-if-!=
    var g/eax: grapheme <- pop-grapheme-stack src-stack
#?     print-grapheme 0, g
#?     print-string 0, "\n"
    add-grapheme-to-word dest, g
    loop
  }
}

fn copy-word-contents-before-cursor _src-ah: (addr handle word), _dest-ah: (addr handle word) {
  var dest-ah/eax: (addr handle word) <- copy _dest-ah
  var _dest/eax: (addr word) <- lookup *dest-ah
  var dest/edi: (addr word) <- copy _dest
  var src-ah/eax: (addr handle word) <- copy _src-ah
  var src/eax: (addr word) <- lookup *src-ah
  var src-data-ah/eax: (addr handle gap-buffer) <- get src, scalar-data
  var src-data/eax: (addr gap-buffer) <- lookup *src-data-ah
  var src-stack/ecx: (addr grapheme-stack) <- get src-data, left
  var src-stack-data-ah/eax: (addr handle array grapheme) <- get src-stack, data
  var _src-stack-data/eax: (addr array grapheme) <- lookup *src-stack-data-ah
  var src-stack-data/edx: (addr array grapheme) <- copy _src-stack-data
  var top-addr/ecx: (addr int) <- get src-stack, top
  var i/eax: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr grapheme) <- index src-stack-data, i
    add-grapheme-to-word dest, *g
    i <- increment
    loop
  }
}

fn word-equal? _self: (addr word), s: (addr array byte) -> result/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  result <- gap-buffer-equal? data, s
}

fn word-length _self: (addr word) -> result/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  result <- gap-buffer-length data
}

fn first-word _in: (addr handle word), out: (addr handle word) {
  var curr-ah/esi: (addr handle word) <- copy _in
  var curr/eax: (addr word) <- lookup *curr-ah
  var prev/edi: (addr handle word) <- copy 0
  {
    prev <- get curr, prev
    var curr/eax: (addr word) <- lookup *prev
    compare curr, 0
    break-if-=
    copy-object prev, curr-ah
    loop
  }
  copy-object curr-ah, out
}

fn final-word _in: (addr handle word), out: (addr handle word) {
  var curr-h: (handle word)
  var curr-ah/esi: (addr handle word) <- address curr-h
  copy-object _in, curr-ah
  var curr/eax: (addr word) <- copy 0
  var next/edi: (addr handle word) <- copy 0
  {
    curr <- lookup *curr-ah
    next <- get curr, next
    curr <- lookup *next
    compare curr, 0
    break-if-=
    copy-object next, curr-ah
    loop
  }
  copy-object curr-ah, out
}

fn first-grapheme _self: (addr word) -> result/eax: grapheme {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  result <- first-grapheme-in-gap-buffer data
}

fn add-grapheme-to-word _self: (addr word), c: grapheme {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  add-grapheme-at-gap data, c
}

fn cursor-at-start? _self: (addr word) -> result/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  result <- gap-at-start? data
}

fn cursor-at-end? _self: (addr word) -> result/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  result <- gap-at-end? data
}

fn cursor-left _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var dummy/eax: grapheme <- gap-left data
}

fn cursor-right _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var dummy/eax: grapheme <- gap-right data
}

fn cursor-to-start _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  gap-to-start data
}

fn cursor-to-end _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  gap-to-end data
}

fn cursor-index _self: (addr word) -> result/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  result <- gap-index data
}

fn delete-before-cursor _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  delete-before-gap data
}

fn delete-next _self: (addr word) {
$delete-next:body: {
  var self/esi: (addr word) <- copy _self
  var next-ah/edi: (addr handle word) <- get self, next
  var next/eax: (addr word) <- lookup *next-ah
  compare next, 0
  break-if-= $delete-next:body
  var next-next-ah/ecx: (addr handle word) <- get next, next
  var self-ah/esi: (addr handle word) <- get next, prev
  copy-object next-next-ah, next-ah
  var new-next/eax: (addr word) <- lookup *next-next-ah
  compare new-next, 0
  break-if-= $delete-next:body
  var dest/eax: (addr handle word) <- get new-next, prev
  copy-object self-ah, dest
}
}

fn print-word screen: (addr screen), _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  render-gap-buffer screen, data
}

fn print-words screen: (addr screen), _words-ah: (addr handle word) {
  var words-ah/eax: (addr handle word) <- copy _words-ah
  var words-a/eax: (addr word) <- lookup *words-ah
  compare words-a, 0
  break-if-=
  # print
  print-word screen, words-a
  print-string screen, " "
  # recurse
  var next-ah/eax: (addr handle word) <- get words-a, next
  print-words screen, next-ah
}

fn print-words-in-reverse screen: (addr screen), _words-ah: (addr handle word) {
  var words-ah/eax: (addr handle word) <- copy _words-ah
  var words-a/eax: (addr word) <- lookup *words-ah
  compare words-a, 0
  break-if-=
  # recurse
  var next-ah/ecx: (addr handle word) <- get words-a, next
  print-words screen, next-ah
  # print
  print-word screen, words-a
  print-string screen, " "
}

# one implication of handles: append must take a handle
fn append-word _self-ah: (addr handle word) {
  var self-ah/esi: (addr handle word) <- copy _self-ah
  var _self/eax: (addr word) <- lookup *self-ah
  var self/ebx: (addr word) <- copy _self
  # allocate new handle
  var new: (handle word)
  var new-ah/ecx: (addr handle word) <- address new
  allocate new-ah
  var new-addr/eax: (addr word) <- lookup new
  initialize-word new-addr
  # new->next = self->next
  var src/esi: (addr handle word) <- get self, next
  var dest/edi: (addr handle word) <- get new-addr, next
  copy-object src, dest
  # new->next->prev = new
  {
    var next-addr/eax: (addr word) <- lookup *src
    compare next-addr, 0
    break-if-=
    dest <- get next-addr, prev
    copy-object new-ah, dest
  }
  # new->prev = self
  dest <- get new-addr, prev
  copy-object _self-ah, dest
  # self->next = new
  dest <- get self, next
  copy-object new-ah, dest
}

fn chain-words _self-ah: (addr handle word), _next: (addr handle word) {
  var self-ah/esi: (addr handle word) <- copy _self-ah
  var _self/eax: (addr word) <- lookup *self-ah
  var self/ecx: (addr word) <- copy _self
  var next-ah/edi: (addr handle word) <- copy _next
  var next/eax: (addr word) <- lookup *next-ah
  var dest/edx: (addr handle word) <- get next, prev
  copy-object self-ah, dest
  dest <- get self, next
  copy-object next-ah, dest
}

fn emit-word _self: (addr word), out: (addr stream byte) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  emit-gap-buffer data, out
}

fn word-to-string _self: (addr word), out: (addr handle array byte) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  gap-buffer-to-string data, out
}

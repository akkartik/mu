fn initialize-word _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data
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
  var src-stack/ecx: (addr code-point-utf8-stack) <- get src-data, right
  {
    var done?/eax: boolean <- code-point-utf8-stack-empty? src-stack
    compare done?, 0/false
    break-if-!=
    var g/eax: code-point-utf8 <- pop-code-point-utf8-stack src-stack
#?     print-code-point-utf8 0, g
#?     print-string 0, "\n"
    add-code-point-utf8-to-word dest, g
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
  var src-stack/ecx: (addr code-point-utf8-stack) <- get src-data, left
  var src-stack-data-ah/eax: (addr handle array code-point-utf8) <- get src-stack, data
  var _src-stack-data/eax: (addr array code-point-utf8) <- lookup *src-stack-data-ah
  var src-stack-data/edx: (addr array code-point-utf8) <- copy _src-stack-data
  var top-addr/ecx: (addr int) <- get src-stack, top
  var i/eax: int <- copy 0
  {
    compare i, *top-addr
    break-if->=
    var g/edx: (addr code-point-utf8) <- index src-stack-data, i
    add-code-point-utf8-to-word dest, *g
    i <- increment
    loop
  }
}

fn word-equal? _self: (addr word), s: (addr array byte) -> _/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: boolean <- gap-buffer-equal? data, s
  return result
}

fn word-length _self: (addr word) -> _/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: int <- gap-buffer-length data
  return result
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
  copy-object curr-ah, out  # modify 'out' right at the end, just in case it's same as 'in'
}

fn first-code-point-utf8 _self: (addr word) -> _/eax: code-point-utf8 {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: code-point-utf8 <- first-code-point-utf8-in-gap-buffer data
  return result
}

fn code-point-utf8-before-cursor _self: (addr word) -> _/eax: code-point-utf8 {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: code-point-utf8 <- code-point-utf8-before-cursor-in-gap-buffer data
  return result
}

fn add-code-point-utf8-to-word _self: (addr word), c: code-point-utf8 {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  add-code-point-utf8-at-gap data, c
}

fn cursor-at-start? _self: (addr word) -> _/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: boolean <- gap-at-start? data
  return result
}

fn cursor-at-end? _self: (addr word) -> _/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: boolean <- gap-at-end? data
  return result
}

fn cursor-left _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var dummy/eax: code-point-utf8 <- gap-left data
}

fn cursor-right _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var dummy/eax: code-point-utf8 <- gap-right data
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

fn cursor-index _self: (addr word) -> _/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: int <- gap-index data
  return result
}

fn delete-before-cursor _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  delete-before-gap data
}

fn pop-after-cursor _self: (addr word) -> _/eax: code-point-utf8 {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: code-point-utf8 <- pop-after-gap data
  return result
}

fn delete-next _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var next-ah/edi: (addr handle word) <- get self, next
  var next/eax: (addr word) <- lookup *next-ah
  compare next, 0
  break-if-=
  var next-next-ah/ecx: (addr handle word) <- get next, next
  var self-ah/esi: (addr handle word) <- get next, prev
  copy-object next-next-ah, next-ah
  var new-next/eax: (addr word) <- lookup *next-next-ah
  compare new-next, 0
  break-if-=
  var dest/eax: (addr handle word) <- get new-next, prev
  copy-object self-ah, dest
}

fn print-word screen: (addr screen), _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  render-gap-buffer screen, data
}

fn print-words-in-reverse screen: (addr screen), _words-ah: (addr handle word) {
  var words-ah/eax: (addr handle word) <- copy _words-ah
  var words-a/eax: (addr word) <- lookup *words-ah
  compare words-a, 0
  break-if-=
  # recurse
  var next-ah/ecx: (addr handle word) <- get words-a, next
  print-words-in-reverse screen, next-ah
  # print
  print-word screen, words-a
  print-string screen, " "
}

# Gotcha with some word operations: ensure dest-ah isn't in the middle of some
# existing chain of words. There are two pointers to patch, and you'll forget
# to do the other one.
fn copy-words _src-ah: (addr handle word), _dest-ah: (addr handle word) {
  var src-ah/eax: (addr handle word) <- copy _src-ah
  var src-a/eax: (addr word) <- lookup *src-ah
  compare src-a, 0
  break-if-=
  # copy
  var dest-ah/edi: (addr handle word) <- copy _dest-ah
  copy-word src-a, dest-ah
  # recurse
  var rest: (handle word)
  var rest-ah/ecx: (addr handle word) <- address rest
  var next-src-ah/esi: (addr handle word) <- get src-a, next
  copy-words next-src-ah, rest-ah
  chain-words dest-ah, rest-ah
}

fn copy-words-in-reverse _src-ah: (addr handle word), _dest-ah: (addr handle word) {
  var src-ah/eax: (addr handle word) <- copy _src-ah
  var _src-a/eax: (addr word) <- lookup *src-ah
  var src-a/esi: (addr word) <- copy _src-a
  compare src-a, 0
  break-if-=
  # recurse
  var next-src-ah/ecx: (addr handle word) <- get src-a, next
  var dest-ah/edi: (addr handle word) <- copy _dest-ah
  copy-words-in-reverse next-src-ah, dest-ah
  #
  copy-word-at-end src-a, dest-ah
}

fn copy-word-at-end src: (addr word), _dest-ah: (addr handle word) {
  var dest-ah/edi: (addr handle word) <- copy _dest-ah
  # if dest is null, copy and return
  var dest-a/eax: (addr word) <- lookup *dest-ah
  compare dest-a, 0
  {
    break-if-!=
    copy-word src, dest-ah
    return
  }
  # copy current word
  var new: (handle word)
  var new-ah/ecx: (addr handle word) <- address new
  copy-word src, new-ah
  # append it at the end
  var curr-ah/edi: (addr handle word) <- copy dest-ah
  {
    var curr-a/eax: (addr word) <- lookup *curr-ah  # curr-a guaranteed not to be null
    var next-ah/ecx: (addr handle word) <- get curr-a, next
    var next-a/eax: (addr word) <- lookup *next-ah
    compare next-a, 0
    break-if-=
    curr-ah <- copy next-ah
    loop
  }
  chain-words curr-ah, new-ah
}

fn append-word-at-end-with _dest-ah: (addr handle word), s: (addr array byte) {
  var dest-ah/edi: (addr handle word) <- copy _dest-ah
  # if dest is null, copy and return
  var dest-a/eax: (addr word) <- lookup *dest-ah
  compare dest-a, 0
  {
    break-if-!=
    allocate-word-with dest-ah, s
    return
  }
  # otherwise append at end
  var curr-ah/edi: (addr handle word) <- copy dest-ah
  {
    var curr-a/eax: (addr word) <- lookup *curr-ah  # curr-a guaranteed not to be null
    var next-ah/ecx: (addr handle word) <- get curr-a, next
    var next-a/eax: (addr word) <- lookup *next-ah
    compare next-a, 0
    break-if-=
    curr-ah <- copy next-ah
    loop
  }
  append-word-with *curr-ah, s
}

fn copy-word _src-a: (addr word), _dest-ah: (addr handle word) {
  var dest-ah/eax: (addr handle word) <- copy _dest-ah
  allocate dest-ah
  var _dest-a/eax: (addr word) <- lookup *dest-ah
  var dest-a/eax: (addr word) <- copy _dest-a
  initialize-word dest-a
  var dest/edi: (addr handle gap-buffer) <- get dest-a, scalar-data
  var src-a/eax: (addr word) <- copy _src-a
  var src/eax: (addr handle gap-buffer) <- get src-a, scalar-data
  copy-gap-buffer src, dest
}

# one implication of handles: append must take a handle
fn append-word _self-ah: (addr handle word) {
  var saved-self-storage: (handle word)
  var saved-self/eax: (addr handle word) <- address saved-self-storage
  copy-object _self-ah, saved-self
#?   {
#?     print-string 0, "self-ah is "
#?     var foo/eax: int <- copy _self-ah
#?     print-int32-hex 0, foo
#?     print-string 0, "\n"
#?   }
  var self-ah/esi: (addr handle word) <- copy _self-ah
  var _self/eax: (addr word) <- lookup *self-ah
  var self/ebx: (addr word) <- copy _self
#?   {
#?     print-string 0, "0: self is "
#?     var self-ah/eax: (addr handle word) <- copy _self-ah
#?     var self/eax: (addr word) <- lookup *self-ah
#?     var foo/eax: int <- copy self
#?     print-int32-hex 0, foo
#?     print-string 0, "\n"
#?   }
  # allocate new handle
  var new: (handle word)
  var new-ah/ecx: (addr handle word) <- address new
  allocate new-ah
  var new-addr/eax: (addr word) <- lookup new
  initialize-word new-addr
#?   {
#?     print-string 0, "new is "
#?     var foo/eax: int <- copy new-addr
#?     print-int32-hex 0, foo
#?     print-string 0, "\n"
#?   }
  # new->next = self->next
  var src/esi: (addr handle word) <- get self, next
#?   {
#?     print-string 0, "src is "
#?     var foo/eax: int <- copy src
#?     print-int32-hex 0, foo
#?     print-string 0, "\n"
#?   }
  var dest/edi: (addr handle word) <- get new-addr, next
  copy-object src, dest
  # new->next->prev = new
  {
    var next-addr/eax: (addr word) <- lookup *src
    compare next-addr, 0
    break-if-=
#?     {
#?       print-string 0, "next-addr is "
#?       var foo/eax: int <- copy next-addr
#?       print-int32-hex 0, foo
#?       print-string 0, "\n"
#?     }
    dest <- get next-addr, prev
#? #?     {
#? #?       print-string 0, "self-ah is "
#? #?       var foo/eax: int <- copy _self-ah
#? #?       print-int32-hex 0, foo
#? #?       print-string 0, "\n"
#? #?       print-string 0, "2: self is "
#? #?       var self-ah/eax: (addr handle word) <- copy _self-ah
#? #?       var self/eax: (addr word) <- lookup *self-ah
#? #?       var foo/eax: int <- copy self
#? #?       print-int32-hex 0, foo
#? #?       print-string 0, "\n"
#? #?     }
#?     {
#?       print-string 0, "copying new to "
#?       var foo/eax: int <- copy dest
#?       print-int32-hex 0, foo
#?       print-string 0, "\n"
#?     }
    copy-object new-ah, dest
#?     {
#?       print-string 0, "4: self is "
#?       var self-ah/eax: (addr handle word) <- copy _self-ah
#?       var self/eax: (addr word) <- lookup *self-ah
#?       var foo/eax: int <- copy self
#?       print-int32-hex 0, foo
#?       print-string 0, "\n"
#?     }
  }
  # new->prev = saved-self
  dest <- get new-addr, prev
#?   {
#?     print-string 0, "copying "
#?     var self-ah/esi: (addr handle word) <- copy _self-ah
#?     var self/eax: (addr word) <- lookup *self-ah
#?     var foo/eax: int <- copy self
#?     print-int32-hex 0, foo
#?     print-string 0, " to "
#?     foo <- copy dest
#?     print-int32-hex 0, foo
#?     print-string 0, "\n"
#?   }
  var saved-self-ah/eax: (addr handle word) <- address saved-self-storage
  copy-object saved-self-ah, dest
  # self->next = new
  dest <- get self, next
  copy-object new-ah, dest
}

fn chain-words _self-ah: (addr handle word), _next: (addr handle word) {
  var self-ah/esi: (addr handle word) <- copy _self-ah
  var _self/eax: (addr word) <- lookup *self-ah
  var self/ecx: (addr word) <- copy _self
  var dest/edx: (addr handle word) <- get self, next
  var next-ah/edi: (addr handle word) <- copy _next
  copy-object next-ah, dest
  var next/eax: (addr word) <- lookup *next-ah
  compare next, 0
  break-if-=
  dest <- get next, prev
  copy-object self-ah, dest
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

fn word-is-decimal-integer? _self: (addr word) -> _/eax: boolean {
  var self/eax: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: boolean <- gap-buffer-is-decimal-integer? data
  return result
}

# ABSOLUTELY GHASTLY
fn word-exists? _haystack-ah: (addr handle word), _needle: (addr word) -> _/ebx: boolean {
  var needle-name-storage: (handle array byte)
  var needle-name-ah/eax: (addr handle array byte) <- address needle-name-storage
  word-to-string _needle, needle-name-ah  # profligate leak
  var _needle-name/eax: (addr array byte) <- lookup *needle-name-ah
  var needle-name/edi: (addr array byte) <- copy _needle-name
  # base case
  var haystack-ah/esi: (addr handle word) <- copy _haystack-ah
  var curr/eax: (addr word) <- lookup *haystack-ah
  compare curr, 0
  {
    break-if-!=
    return 0/false
  }
  # check curr
  var curr-name-storage: (handle array byte)
  var curr-name-ah/ecx: (addr handle array byte) <- address curr-name-storage
  word-to-string curr, curr-name-ah  # profligate leak
  var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
  var found?/eax: boolean <- string-equal? needle-name, curr-name
  compare found?, 0
  {
    break-if-=
    return 1/true
  }
  # recurse
  var curr/eax: (addr word) <- lookup *haystack-ah
  var next-haystack-ah/eax: (addr handle word) <- get curr, next
  var result/ebx: boolean <- word-exists? next-haystack-ah, _needle
  return result
}

fn word-list-length words: (addr handle word) -> _/eax: int {
  var curr-ah/esi: (addr handle word) <- copy words
  var result/edi: int <- copy 0
  {
    var curr/eax: (addr word) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    {
      var word-len/eax: int <- word-length curr
      result <- add word-len
      result <- add 1/inter-word-margin
    }
    curr-ah <- get curr, next
    loop
  }
  return result
}

# out-ah already has a word allocated and initialized
fn parse-words in: (addr array byte), out-ah: (addr handle word) {
  var in-stream: (stream byte 0x100)
  var in-stream-a/esi: (addr stream byte) <- address in-stream
  write in-stream-a, in
  var cursor-word-ah/ebx: (addr handle word) <- copy out-ah
  $parse-words:loop: {
    var done?/eax: boolean <- stream-empty? in-stream-a
    compare done?, 0/false
    break-if-!=
    var _g/eax: code-point-utf8 <- read-code-point-utf8 in-stream-a
    var g/ecx: code-point-utf8 <- copy _g
    # if not space, insert
    compare g, 0x20/space
    {
      break-if-=
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      add-code-point-utf8-to-word cursor-word, g
      loop $parse-words:loop
    }
    # otherwise insert word after and move cursor to it
    append-word cursor-word-ah
    var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    cursor-to-start cursor-word  # reset cursor in each function
    cursor-word-ah <- get cursor-word, next
    loop
  }
}

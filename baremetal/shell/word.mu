type word {
  scalar-data: (handle gap-buffer)
  next: (handle word)
  prev: (handle word)
}

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
  var src-stack/ecx: (addr grapheme-stack) <- get src-data, right
  {
    var done?/eax: boolean <- grapheme-stack-empty? src-stack
    compare done?, 0/false
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

fn word-equal? _self: (addr word), s: (addr array byte) -> _/eax: boolean {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: boolean <- gap-buffer-equal? data, s
  return result
}

fn words-equal? _self: (addr word), _w: (addr word) -> _/eax: boolean {
  var self/eax: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/ecx: (addr gap-buffer) <- copy _data
  var w/eax: (addr word) <- copy _w
  var w-data-ah/eax: (addr handle gap-buffer) <- get w, scalar-data
  var w-data/eax: (addr gap-buffer) <- lookup *w-data-ah
  var result/eax: boolean <- gap-buffers-equal? data, w-data
  return result
}

fn word-length _self: (addr word) -> _/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: int <- gap-buffer-length data
  return result
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
  copy-object curr-ah, out  # modify 'out' right at the end, just in case it's same as 'in'
}

fn first-grapheme _self: (addr word) -> _/eax: grapheme {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: grapheme <- first-grapheme-in-gap-buffer data
  return result
}

fn grapheme-before-cursor _self: (addr word) -> _/eax: grapheme {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: grapheme <- grapheme-before-cursor-in-gap-buffer data
  return result
}

fn add-grapheme-to-word _self: (addr word), c: grapheme {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  add-grapheme-at-gap data, c
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

fn cursor-index _self: (addr word) -> _/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: int <- index-of-gap data
  return result
}

fn delete-before-cursor _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  delete-before-gap data
}

fn pop-after-cursor _self: (addr word) -> _/eax: grapheme {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: grapheme <- pop-after-gap data
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

fn render-word screen: (addr screen), _self: (addr word), x: int, y: int, render-cursor?: boolean -> _/eax: int {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: int <- render-gap-buffer screen, data, x, y, render-cursor?
  return result
}

fn render-words-in-reverse screen: (addr screen), _words-ah: (addr handle word), x: int, y: int, cursor-word-addr: int -> _/eax: int {
  var words-ah/eax: (addr handle word) <- copy _words-ah
  var _words-a/eax: (addr word) <- lookup *words-ah
  var words-a/ecx: (addr word) <- copy _words-a
  compare words-a, 0
  {
    break-if-!=
    return x
  }
  # recurse
  var next-ah/eax: (addr handle word) <- get words-a, next
  var next-x/eax: int <- render-words-in-reverse screen, next-ah, x, y, cursor-word-addr
  # print
  var render-cursor?/edx: boolean <- copy 0/false
  {
    compare cursor-word-addr, words-a
    break-if-!=
    render-cursor? <- copy 1/true
  }
  next-x <- render-word screen, words-a, next-x, y, render-cursor?
  var space/ecx: grapheme <- copy 0x20/space
  draw-grapheme screen, space, next-x, y, 3/fg=cyan, 0/bg
  next-x <- increment
  return next-x
}

fn test-render-words-in-reverse {
  # words = [aaa, bbb, ccc, ddd]
  var w-storage: (handle word)
  var w-ah/esi: (addr handle word) <- address w-storage
  allocate w-ah
  var _w/eax: (addr word) <- lookup *w-ah
  var w/ecx: (addr word) <- copy _w
  initialize-word-with w, "aaa"
  append-word-at-end-with w-ah, "bbb"
  append-word-at-end-with w-ah, "ccc"
  append-word-at-end-with w-ah, "ddd"
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 4
  #
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "               | ", "F - test-render-words-in-reverse/0 cursor"
  # - start moving cursor left through final word
  cursor-left w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "              |  ", "F - test-render-words-in-reverse/1 cursor"
  #
  cursor-left w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "             |   ", "F - test-render-words-in-reverse/2 cursor"
  #
  cursor-left w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "            |    ", "F - test-render-words-in-reverse/3 cursor"
  # further moves left within the word change nothing
  cursor-left w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "            |    ", "F - test-render-words-in-reverse/3 cursor"
  # - switch to next word
  var w2-ah/eax: (addr handle word) <- get w, next
  var _w/eax: (addr word) <- lookup *w2-ah
  var w/ecx: (addr word) <- copy _w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb  aaa  ", "F - test-render-words-in-reverse/4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "           |      ", "F - test-render-words-in-reverse/4 cursor"
  # now speed up a little
  cursor-left w
  cursor-left w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/5"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "         |       ", "F - test-render-words-in-reverse/5 cursor"
  #
  var w2-ah/eax: (addr handle word) <- get w, next
  var _w/eax: (addr word) <- lookup *w2-ah
  var w/ecx: (addr word) <- copy _w
  cursor-left w
  var cursor-word/eax: int <- copy w
  var new-x/eax: int <- render-words-in-reverse screen, w-ah, 0/x, 0/y, cursor-word
  check-screen-row screen, 0/y,                                   "ddd ccc bbb aaa  ", "F - test-render-words-in-reverse/6"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y,  "      |          ", "F - test-render-words-in-reverse/6 cursor"
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

fn word-is-decimal-integer? _self: (addr word) -> _/eax: boolean {
  var self/eax: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var result/eax: boolean <- gap-buffer-is-decimal-integer? data
  return result
}

fn word-exists? haystack: (addr word), needle: (addr word) -> _/eax: boolean {
  # base case
  compare haystack, 0
  {
    break-if-!=
    return 0/false
  }
  # check current word
  var found?/eax: boolean <- words-equal? haystack, needle
  compare found?, 0/false
  {
    break-if-=
    return 1/true
  }
  # recurse
  var curr/eax: (addr word) <- copy haystack
  var next-ah/eax: (addr handle word) <- get curr, next
  var next/eax: (addr word) <- lookup *next-ah
  var result/eax: boolean <- word-exists? next, needle
  return result
}

fn test-word-exists? {
  var needle-storage: word
  var needle/esi: (addr word) <- address needle-storage
  initialize-word-with needle, "abc"
  var w-storage: (handle word)
  var w-ah/edi: (addr handle word) <- address w-storage
  allocate w-ah
  var _w/eax: (addr word) <- lookup *w-ah
  var w/ecx: (addr word) <- copy _w
  initialize-word-with w, "aaa"
  #
  var result/eax: boolean <- word-exists? w, w
  check result, "F - test-word-exists? reflexive"
  result <- word-exists? w, needle
  check-not result, "F - test-word-exists? 1"
  append-word-at-end-with w-ah, "bbb"
  result <- word-exists? w, needle
  check-not result, "F - test-word-exists? 2"
  append-word-at-end-with w-ah, "abc"
  result <- word-exists? w, needle
  check result, "F - test-word-exists? 3"
  append-word-at-end-with w-ah, "ddd"
  result <- word-exists? w, needle
  check result, "F - test-word-exists? 4"
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
    var _g/eax: grapheme <- read-grapheme in-stream-a
    var g/ecx: grapheme <- copy _g
    # if not space, insert
    compare g, 0x20/space
    {
      break-if-=
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      add-grapheme-to-word cursor-word, g
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

type sandbox {
  setup: (handle line)
  data: (handle line)
  # display data
  cursor-call-path: (handle call-path-element)
  expanded-words: (handle call-path)
  #
  next: (handle sandbox)
  prev: (handle sandbox)
}

type function {
  name: (handle array byte)
  args: (handle word)  # in reverse order
  body: (handle line)
  # some sort of indication of spatial location
  next: (handle function)
}

type line {
  name: (handle array byte)
  data: (handle word)
  result: (handle result)  # might be cached
  next: (handle line)
  prev: (handle line)
}

type word {
  # at most one of these will be non-null
  scalar-data: (handle gap-buffer)
  text-data: (handle array byte)
  box-data: (handle line)  # recurse
  #
  next: (handle word)
  prev: (handle word)
}

type value {
  scalar-data: int
  text-data: (handle array byte)
  box-data: (handle line)
}

type table {
  data: (handle array bind)
  next: (handle table)
}

type bind {
  key: (handle array byte)
  value: (handle value)  # I'd inline this but we sometimes want to return a specific value from a table
}

# A call-path is a data structure that can unambiguously refer to any specific
# call arbitrarily deep inside the call hierarchy of a program.
type call-path {
  data: (handle call-path-element)
  next: (handle call-path)
}

# A call-path is a list of elements, each of which corresponds to some call.
# Calls are denoted by their position in the caller's body. They also include
# the function being called.
type call-path-element {
  index-in-body: int
  next: (handle call-path-element)
}

type result {
  data: value-stack
  error: (handle array byte)  # single error message for now
}

fn initialize-sandbox _sandbox: (addr sandbox) {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
  allocate cursor-call-path-ah
  var line-ah/eax: (addr handle line) <- get sandbox, data
  allocate line-ah
  var line/eax: (addr line) <- lookup *line-ah
  initialize-line line
}

# initialize line with a single empty word
fn initialize-line _line: (addr line) {
  var line/esi: (addr line) <- copy _line
  var word-ah/eax: (addr handle word) <- get line, data
  allocate word-ah
  var word/eax: (addr word) <- lookup *word-ah
  initialize-word word
}

fn create-primitive-functions _self: (addr handle function) {
  # x 2* = x 2 *
  var self/esi: (addr handle function) <- copy _self
  allocate self
  var _f/eax: (addr function) <- lookup *self
  var f/esi: (addr function) <- copy _f
  var name-ah/eax: (addr handle array byte) <- get f, name
  populate-text-with name-ah, "2*"
  var args-ah/eax: (addr handle word) <- get f, args
  allocate args-ah
  var args/eax: (addr word) <- lookup *args-ah
  initialize-word-with args, "x"
  var body-ah/eax: (addr handle line) <- get f, body
  allocate body-ah
  var body/eax: (addr line) <- lookup *body-ah
  initialize-line body
  var curr-word-ah/ecx: (addr handle word) <- get body, data
  # *curr-word = "x"
  allocate curr-word-ah
  var tmp/eax: (addr word) <- lookup *curr-word-ah
  var curr-word/edx: (addr word) <- copy tmp
  initialize-word-with curr-word, "x"
  # *curr-word->next = "2"
  var next-word-ah/ebx: (addr handle word) <- get curr-word, next
  allocate next-word-ah
  tmp <- lookup *next-word-ah
  initialize-word-with tmp, "2"
  # *curr-word->next->prev = curr-word
  var prev-word-ah/edi: (addr handle word) <- get tmp, prev
  copy-object curr-word-ah, prev-word-ah
  # curr-word = curr-word->next
  curr-word-ah <- copy next-word-ah
  curr-word <- copy tmp
  # *curr-word->next = "*"
  next-word-ah <- get curr-word, next
  allocate next-word-ah
  tmp <- lookup *next-word-ah
  initialize-word-with tmp, "*"
  # *curr-word->next->prev = curr-word
  prev-word-ah <- get tmp, prev
  copy-object curr-word-ah, prev-word-ah
  tmp <- lookup *prev-word-ah
#?   # x 1+ = x 1 +
#?   var next/esi: (addr handle function) <- get f, next
#?   allocate next
#?   var _f/eax: (addr function) <- lookup *next
#?   var f/esi: (addr function) <- copy _f
#?   var name-ah/eax: (addr handle array byte) <- get f, name
#?   populate-text-with name-ah, "1+"
#?   var args-ah/eax: (addr handle word) <- get f, args
#?   allocate args-ah
#?   var args/eax: (addr word) <- lookup *args-ah
#?   initialize-word-with args, "x"
#?   var body-ah/eax: (addr handle line) <- get f, body
#?   allocate body-ah
#?   var body/eax: (addr line) <- lookup *body-ah
#?   initialize-line body
#?   var curr-word-ah/ecx: (addr handle word) <- get body, data
#?   allocate curr-word-ah
#?   var curr-word/eax: (addr word) <- lookup *curr-word-ah
#?   initialize-word-with curr-word, "x"
#?   curr-word-ah <- get curr-word, next
#?   allocate curr-word-ah
#?   curr-word <- lookup *curr-word-ah
#?   initialize-word-with curr-word, "1"
#?   curr-word-ah <- get curr-word, next
#?   allocate curr-word-ah
#?   curr-word <- lookup *curr-word-ah
#?   initialize-word-with curr-word, "+"
#?   # x 2+ = x 1+ 1+
#?   var next/esi: (addr handle function) <- get f, next
#?   allocate next
#?   var _f/eax: (addr function) <- lookup *next
#?   var f/ecx: (addr function) <- copy _f
#?   var name-ah/eax: (addr handle array byte) <- get f, name
#?   populate-text-with name-ah, "2+"
#?   var args-ah/eax: (addr handle word) <- get f, args
#?   allocate args-ah
#?   var args/eax: (addr word) <- lookup *args-ah
#?   initialize-word-with args, "x"
#?   var body-ah/eax: (addr handle line) <- get f, body
#?   allocate body-ah
#?   var body/eax: (addr line) <- lookup *body-ah
#?   initialize-line body
#?   var curr-word-ah/ecx: (addr handle word) <- get body, data
#?   allocate curr-word-ah
#?   var curr-word/eax: (addr word) <- lookup *curr-word-ah
#?   initialize-word-with curr-word, "x"
#?   curr-word-ah <- get curr-word, next
#?   allocate curr-word-ah
#?   curr-word <- lookup *curr-word-ah
#?   initialize-word-with curr-word, "1+"
#?   curr-word-ah <- get curr-word, next
#?   allocate curr-word-ah
#?   curr-word <- lookup *curr-word-ah
#?   initialize-word-with curr-word, "1+"
}

fn function-body functions: (addr handle function), _word: (addr handle word), out: (addr handle line) {
  var function-name-storage: (handle array byte)
  var function-name-ah/ecx: (addr handle array byte) <- address function-name-storage
  var word-ah/esi: (addr handle word) <- copy _word
  var word/eax: (addr word) <- lookup *word-ah
  var gap-ah/eax: (addr handle gap-buffer) <- get word, scalar-data
  var gap/eax: (addr gap-buffer) <- lookup *gap-ah
  gap-buffer-to-string gap, function-name-ah
  var _function-name/eax: (addr array byte) <- lookup *function-name-ah
  var function-name/esi: (addr array byte) <- copy _function-name
  var curr-ah/ecx: (addr handle function) <- copy functions
  $function-body:loop: {
    var _curr/eax: (addr function) <- lookup *curr-ah
    var curr/edx: (addr function) <- copy _curr
    compare curr, 0
    break-if-=
    var curr-name-ah/eax: (addr handle array byte) <- get curr, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var found?/eax: boolean <- string-equal? curr-name, function-name
    compare found?, 0  # false
    {
      break-if-=
      var src/eax: (addr handle line) <- get curr, body
      copy-object src, out
      break $function-body:loop
    }
    curr-ah <- get curr, next
    loop
  }
}

fn body-length functions: (addr handle function), function-name: (addr handle word) -> result/eax: int {
  var body-storage: (handle line)
  var body-ah/edi: (addr handle line) <- address body-storage
  function-body functions, function-name, body-ah
  var body/eax: (addr line) <- lookup *body-ah
  result <- line-length body
}

fn line-length _in: (addr line) -> result/eax: int {
  var in/esi: (addr line) <- copy _in
  var curr-ah/ecx: (addr handle word) <- get in, data
  var out/edi: int <- copy 0
  {
    var curr/eax: (addr word) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    curr-ah <- get curr, next
    out <- increment
    loop
  }
  result <- copy out
}

fn populate-text-with _out: (addr handle array byte), _in: (addr array byte) {
  var in/esi: (addr array byte) <- copy _in
  var n/ecx: int <- length in
  var out/edx: (addr handle array byte) <- copy _out
  populate out, n
  var _out-addr/eax: (addr array byte) <- lookup *out
  var out-addr/edx: (addr array byte) <- copy _out-addr
  var i/eax: int <- copy 0
  {
    compare i, n
    break-if->=
    var src/esi: (addr byte) <- index in, i
    var val/ecx: byte <- copy-byte *src
    var dest/edi: (addr byte) <- index out-addr, i
    copy-byte-to *dest, val
    i <- increment
    loop
  }
}

fn find-in-call-path in: (addr handle call-path), needle: (addr handle call-path-element) -> result/eax: boolean {
  var curr-ah/esi: (addr handle call-path) <- copy in
  var out/edi: boolean <- copy 0  # false
  $find-in-call-path:loop: {
    var curr/eax: (addr call-path) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    {
      var curr-data/eax: (addr handle call-path-element) <- get curr, data
      var match?/eax: boolean <- call-path-element-match? curr-data, needle
      compare match?, 0  # false
      {
        break-if-=
        out <- copy 1  # true
        break $find-in-call-path:loop
      }
    }
    curr-ah <- get curr, next
    loop
  }
  result <- copy out
}

fn call-path-element-match? _x: (addr handle call-path-element), _y: (addr handle call-path-element) -> result/eax: boolean {
$call-path-element-match?:body: {
  var x-ah/eax: (addr handle call-path-element) <- copy _x
  var x-a/eax: (addr call-path-element) <- lookup *x-ah
  var x/esi: (addr call-path-element) <- copy x-a
  var y-ah/eax: (addr handle call-path-element) <- copy _y
  var y-a/eax: (addr call-path-element) <- lookup *y-ah
  var y/edi: (addr call-path-element) <- copy y-a
  compare x, y
  {
    break-if-!=
    result <- copy 1  # true
    break $call-path-element-match?:body
  }
  compare x, 0
  {
    break-if-!=
    result <- copy 0  # false
    break $call-path-element-match?:body
  }
  compare y, 0
  {
    break-if-!=
    result <- copy 0  # false
    break $call-path-element-match?:body
  }
  var x-data-a/ecx: (addr int) <- get x, index-in-body
  var x-data/ecx: int <- copy *x-data-a
  var y-data-a/eax: (addr int) <- get y, index-in-body
  var y-data/eax: int <- copy *y-data-a
  compare x-data, y-data
  {
    break-if-=
    result <- copy 0  # false
    break $call-path-element-match?:body
  }
  var x-next/ecx: (addr handle call-path-element) <- get x, next
  var y-next/eax: (addr handle call-path-element) <- get y, next
  result <- call-path-element-match? x-next, y-next
}
}

# order is irrelevant
fn insert-in-call-path list: (addr handle call-path), new: (addr handle call-path-element) {
  var new-path-storage: (handle call-path)
  var new-path-ah/edi: (addr handle call-path) <- address new-path-storage
  allocate new-path-ah
  var new-path/eax: (addr call-path) <- lookup *new-path-ah
  var next/ecx: (addr handle call-path) <- get new-path, next
  copy-object list, next
  var dest/ecx: (addr handle call-path-element) <- get new-path, data
  deep-copy-call-path-element new, dest
  copy-object new-path-ah, list
}

# assumes dest is initially clear
fn deep-copy-call-path-element _src: (addr handle call-path-element), _dest: (addr handle call-path-element) {
  var src/esi: (addr handle call-path-element) <- copy _src
  # if src is null, return
  var _src-addr/eax: (addr call-path-element) <- lookup *src
  compare _src-addr, 0
  break-if-=
  # allocate
  var src-addr/esi: (addr call-path-element) <- copy _src-addr
  var dest/eax: (addr handle call-path-element) <- copy _dest
  allocate dest
  # copy data
  var dest-addr/eax: (addr call-path-element) <- lookup *dest
  {
    var dest-data-addr/ecx: (addr int) <- get dest-addr, index-in-body
    var tmp/eax: (addr int) <- get src-addr, index-in-body
    var tmp2/eax: int <- copy *tmp
    copy-to *dest-data-addr, tmp2
  }
  # recurse
  var src-next/esi: (addr handle call-path-element) <- get src-addr, next
  var dest-next/eax: (addr handle call-path-element) <- get dest-addr, next
  deep-copy-call-path-element src-next, dest-next
}

fn delete-in-call-path list: (addr handle call-path), needle: (addr handle call-path-element) {
$delete-in-call-path:body: {
  var curr-ah/esi: (addr handle call-path) <- copy list
  $delete-in-call-path:loop: {
    var _curr/eax: (addr call-path) <- lookup *curr-ah
    var curr/ecx: (addr call-path) <- copy _curr
    compare curr, 0
    break-if-=
    {
      var curr-data/eax: (addr handle call-path-element) <- get curr, data
      var match?/eax: boolean <- call-path-element-match? curr-data, needle
      compare match?, 0  # false
      {
        break-if-=
        var next-ah/ecx: (addr handle call-path) <- get curr, next
        copy-object next-ah, curr-ah
        loop $delete-in-call-path:loop
      }
    }
    curr-ah <- get curr, next
    loop
  }
}
}

fn increment-final-element list: (addr handle call-path-element) {
  var final-ah/eax: (addr handle call-path-element) <- copy list
  var final/eax: (addr call-path-element) <- lookup *final-ah
  var val/eax: (addr int) <- get final, index-in-body
  increment *val
}

fn decrement-final-element list: (addr handle call-path-element) {
  var final-ah/eax: (addr handle call-path-element) <- copy list
  var final/eax: (addr call-path-element) <- lookup *final-ah
  var val/eax: (addr int) <- get final, index-in-body
  decrement *val
}

fn final-element-value list: (addr handle call-path-element) -> result/eax: int {
  var final-ah/eax: (addr handle call-path-element) <- copy list
  var final/eax: (addr call-path-element) <- lookup *final-ah
  var val/eax: (addr int) <- get final, index-in-body
  result <- copy *val
}

fn push-to-call-path-element list: (addr handle call-path-element), new: int {
  var new-element-storage: (handle call-path-element)
  var new-element-ah/edi: (addr handle call-path-element) <- address new-element-storage
  allocate new-element-ah
  var new-element/eax: (addr call-path-element) <- lookup *new-element-ah
  # index-in-body
  var dest/ecx: (addr int) <- get new-element, index-in-body
  var src/edx: int <- copy new
  copy-to *dest, src
  # next
  var dest2/ecx: (addr handle call-path-element) <- get new-element, next
  copy-object list, dest2
  # return
  copy-object new-element-ah, list
}

fn drop-from-call-path-element _list: (addr handle call-path-element) {
  var list-ah/esi: (addr handle call-path-element) <- copy _list
  var list/eax: (addr call-path-element) <- lookup *list-ah
  var next/eax: (addr handle call-path-element) <- get list, next
  copy-object next, _list
}

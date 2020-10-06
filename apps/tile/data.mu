type sandbox {
  setup: (handle line)
  data: (handle line)
  # display data
  cursor-word: (handle word)
  cursor-word-index: int
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
  data: int
  next: (handle call-path)
}

type result {
  data: value-stack
  error: (handle array byte)  # single error message for now
}

fn initialize-sandbox _sandbox: (addr sandbox) {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var line-ah/eax: (addr handle line) <- get sandbox, data
  allocate line-ah
  var line/eax: (addr line) <- lookup *line-ah
  var cursor-word-ah/esi: (addr handle word) <- get sandbox, cursor-word
  allocate cursor-word-ah
  initialize-line line, cursor-word-ah
}

# initialize line with a single empty word
# if 'out' is non-null, save the word there as well
fn initialize-line _line: (addr line), out: (addr handle word) {
  var line/esi: (addr line) <- copy _line
  var word-ah/eax: (addr handle word) <- get line, data
  allocate word-ah
  {
    compare out, 0
    break-if-=
    var dest/edi: (addr handle word) <- copy out
    copy-object word-ah, dest
  }
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
  initialize-line body, 0
  var curr-word-ah/ecx: (addr handle word) <- get body, data
  allocate curr-word-ah
  var curr-word/eax: (addr word) <- lookup *curr-word-ah
  initialize-word-with curr-word, "x"
  curr-word-ah <- get curr-word, next
  allocate curr-word-ah
  curr-word <- lookup *curr-word-ah
  initialize-word-with curr-word, "2"
  curr-word-ah <- get curr-word, next
  allocate curr-word-ah
  curr-word <- lookup *curr-word-ah
  initialize-word-with curr-word, "*"
  # x 1+ = x 1 +
  var next/esi: (addr handle function) <- get f, next
  allocate next
  var _f/eax: (addr function) <- lookup *next
  var f/esi: (addr function) <- copy _f
  var name-ah/eax: (addr handle array byte) <- get f, name
  populate-text-with name-ah, "1+"
  var args-ah/eax: (addr handle word) <- get f, args
  allocate args-ah
  var args/eax: (addr word) <- lookup *args-ah
  initialize-word-with args, "x"
  var body-ah/eax: (addr handle line) <- get f, body
  allocate body-ah
  var body/eax: (addr line) <- lookup *body-ah
  initialize-line body, 0
  var curr-word-ah/ecx: (addr handle word) <- get body, data
  allocate curr-word-ah
  var curr-word/eax: (addr word) <- lookup *curr-word-ah
  initialize-word-with curr-word, "x"
  curr-word-ah <- get curr-word, next
  allocate curr-word-ah
  curr-word <- lookup *curr-word-ah
  initialize-word-with curr-word, "1"
  curr-word-ah <- get curr-word, next
  allocate curr-word-ah
  curr-word <- lookup *curr-word-ah
  initialize-word-with curr-word, "+"
  # x 2+ = x 1+ 1+
  var next/esi: (addr handle function) <- get f, next
  allocate next
  var _f/eax: (addr function) <- lookup *next
  var f/ecx: (addr function) <- copy _f
  var name-ah/eax: (addr handle array byte) <- get f, name
  populate-text-with name-ah, "2+"
  var args-ah/eax: (addr handle word) <- get f, args
  allocate args-ah
  var args/eax: (addr word) <- lookup *args-ah
  initialize-word-with args, "x"
  var body-ah/eax: (addr handle line) <- get f, body
  allocate body-ah
  var body/eax: (addr line) <- lookup *body-ah
  initialize-line body, 0
  var curr-word-ah/ecx: (addr handle word) <- get body, data
  allocate curr-word-ah
  var curr-word/eax: (addr word) <- lookup *curr-word-ah
  initialize-word-with curr-word, "x"
  curr-word-ah <- get curr-word, next
  allocate curr-word-ah
  curr-word <- lookup *curr-word-ah
  initialize-word-with curr-word, "1+"
  curr-word-ah <- get curr-word, next
  allocate curr-word-ah
  curr-word <- lookup *curr-word-ah
  initialize-word-with curr-word, "1+"
  # TODO: populate prev pointers
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

fn find-in-call-path in: (addr handle call-path), _needle: int -> result/eax: boolean {
$find-in-call-path:body: {
  var curr-ah/esi: (addr handle call-path) <- copy in
  var needle/ebx: int <- copy _needle
  {
    var curr/eax: (addr call-path) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    var curr-n/ecx: (addr int) <- get curr, data
    compare needle, *curr-n
    {
      break-if-!=
      result <- copy 1  # true
      break $find-in-call-path:body
    }
    curr-ah <- get curr, next
    loop
  }
  result <- copy 0  # false
}
}

# order is irrelevant
fn insert-in-call-path list: (addr handle call-path), _n: int {
  var new-path-storage: (handle call-path)
  var new-path-ah/edi: (addr handle call-path) <- address new-path-storage
  allocate new-path-ah
  var new-path/eax: (addr call-path) <- lookup *new-path-ah
  var next/ecx: (addr handle call-path) <- get new-path, next
  copy-object list, next
  var data/ecx: (addr int) <- get new-path, data
  var n/edx: int <- copy _n
  copy-to *data, n
  copy-object new-path-ah, list
}

fn delete-in-call-path list: (addr handle call-path), _n: int {
$delete-in-call-path:body: {
  var curr-ah/esi: (addr handle call-path) <- copy list
  var n/ebx: int <- copy _n
  $delete-in-call-path:loop: {
    var curr/eax: (addr call-path) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    var curr-n/ecx: (addr int) <- get curr, data
    compare n, *curr-n
    {
      break-if-!=
      var next-ah/ecx: (addr handle call-path) <- get curr, next
      copy-object next-ah, curr-ah
      loop $delete-in-call-path:loop
    }
    curr-ah <- get curr, next
    loop
  }
}
}

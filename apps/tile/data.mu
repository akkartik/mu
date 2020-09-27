type program {
  defs: (handle function)
  sandboxes: (handle sandbox)
}

type sandbox {
  setup: (handle line)
  data: (handle line)
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

type result {
  data: value-stack
  error: (handle array byte)  # single error message for now
}

# if 'out' is non-null, save the first word of the program there
fn initialize-program _program: (addr program), out: (addr handle word) {
  var program/esi: (addr program) <- copy _program
  var defs/eax: (addr handle function) <- get program, defs
  create-primitive-defs defs
  var sandbox-ah/eax: (addr handle sandbox) <- get program, sandboxes
  allocate sandbox-ah
  var sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
  initialize-sandbox sandbox, out
}

# if 'out' is non-null, save the first word of the sandbox there
fn initialize-sandbox _sandbox: (addr sandbox), out: (addr handle word) {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var line-ah/eax: (addr handle line) <- get sandbox, data
  allocate line-ah
  var line/eax: (addr line) <- lookup *line-ah
  initialize-line line, out
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

fn create-primitive-defs _self: (addr handle function) {
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

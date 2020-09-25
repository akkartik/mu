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
  args: (handle word)
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

#? type result {
#?   data: (handle value-stack)
#?   error: (handle array byte)  # single error message for now
#? }

# if 'out' is non-null, save the first word of the program there
fn initialize-program _program: (addr program), out: (addr handle word) {
  var program/esi: (addr program) <- copy _program
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

fn initialize-word _self: (addr word) {
  var self/esi: (addr word) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, scalar-data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data
  # TODO: sometimes initialize box-data rather than scalar-data
}

type line {
  name: (handle array byte)
  data: (handle word)
  cursor: (handle word)
  next: (handle line)
  prev: (handle line)
}

# initialize line with a single empty word
fn initialize-line _line: (addr line) {
  var line/esi: (addr line) <- copy _line
  var word-ah/eax: (addr handle word) <- get line, data
  allocate word-ah
  var word/eax: (addr word) <- lookup *word-ah
  initialize-word word
}

fn num-words-in-line _in: (addr line) -> _/eax: int {
  var in/esi: (addr line) <- copy _in
  var curr-ah/ecx: (addr handle word) <- get in, data
  var result/edi: int <- copy 0
  {
    var curr/eax: (addr word) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    curr-ah <- get curr, next
    result <- increment
    loop
  }
  return result
}

fn line-list-length lines: (addr handle line) -> _/eax: int {
  var curr-ah/esi: (addr handle line) <- copy lines
  var result/edi: int <- copy 0
  {
    var curr/eax: (addr line) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    curr-ah <- get curr, next
    result <- increment
    loop
  }
  return result
}

fn render-line screen: (addr screen), _line: (addr line), x: int, y: int, render-cursor?: boolean -> _/eax: int {
  var line/eax: (addr line) <- copy _line
  var first-word-ah/esi: (addr handle word) <- get line, data
  # cursor-word
  var cursor-word/edi: int <- copy 0
  compare render-cursor?, 0/false
  {
    break-if-=
    var cursor-word-ah/eax: (addr handle word) <- get line, cursor
    var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    cursor-word <- copy _cursor-word
  }
  #
  var result/eax: int <- render-words screen, first-word-ah, x, y, cursor-word
  return result
}

fn parse-line in: (addr array byte), _out: (addr line) {
  var out/edi: (addr line) <- copy _out
  initialize-line out
  var dest/eax: (addr handle word) <- get out, data
  parse-words in, dest
}

#? fn main {
#?   # line = [aaa, bbb, ccc, ddd]
#?   var line-storage: line
#?   var w-ah/eax: (addr handle word) <- get line-storage, data
#?   allocate-word-with w-ah, "aaa"
#?   append-word-at-end-with w-ah, "bbb"
#?   append-word-at-end-with w-ah, "ccc"
#?   append-word-at-end-with w-ah, "ddd"
#?   var cursor-ah/ecx: (addr handle word) <- get line-storage, cursor
#?   var w/eax: (addr word) <- lookup *w-ah
#?   var next-ah/eax: (addr handle word) <- get w, next
#?   copy-object next-ah, cursor-ah
#?   var line-addr/eax: (addr line) <- address line-storage
#?   var dummy/eax: int <- render-line 0/screen, line-addr, 0/x, 0/y, 1/render-cursor
#? }

fn render-line-with-stack screen: (addr screen), _line: (addr line), x: int, y: int, render-cursor?: boolean -> _/eax: int, _/ecx: int {
  var line/esi: (addr line) <- copy _line
  # cursor-word
  var cursor-word/edi: int <- copy 0
  compare render-cursor?, 0/false
  {
    break-if-=
    var cursor-word-ah/eax: (addr handle word) <- get line, cursor
    var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    cursor-word <- copy _cursor-word
  }
  #
  var curr-word-ah/eax: (addr handle word) <- get line, data
  var _curr-word/eax: (addr word) <- lookup *curr-word-ah
  var curr-word/edx: (addr word) <- copy _curr-word
  var new-x/eax: int <- copy x  # increases each iteration
  var new-y/ebx: int <- copy y  # compute max across all iterations
  {
    compare curr-word, 0
    break-if-=
    var curr-y/ecx: int <- copy 0
    new-x, curr-y <- render-word-with-stack-and-cursor screen, line, curr-word, new-x, y, cursor-word
    compare curr-y, new-y
    {
      break-if-<=
      new-y <- copy curr-y
    }
    # update
    var next-word-ah/eax: (addr handle word) <- get curr-word, next
    var next-word/eax: (addr word) <- lookup *next-word-ah
    curr-word <- copy next-word
    loop
  }
  return new-x, new-y
}

fn render-word-with-stack-and-cursor screen: (addr screen), line: (addr line), curr-word: (addr word), x: int, y: int, _cursor-word-addr: int -> _/eax: int, _/ecx: int {
  # print curr-word, with cursor if necessary
  var render-cursor?/eax: boolean <- copy 0/false
  var cursor-word-addr/ecx: int <- copy _cursor-word-addr
  {
    compare cursor-word-addr, curr-word
    break-if-!=
    render-cursor? <- copy 1/true
  }
  var new-x/eax: int <- render-word screen, curr-word, x, y, render-cursor?
  var new-x-saved/edx: int <- copy new-x
  add-to y, 1/word-stack-spacing
  # compute stack until word
  var stack-storage: value-stack
  var stack/edi: (addr value-stack) <- address stack-storage
  evaluate line, curr-word, stack
  # render stack
  var new-y/ecx: int <- copy 0
  new-x, new-y <- render-value-stack screen, stack, x, y
  compare new-x, new-x-saved
  {
    break-if-<=
    new-x <- copy new-x-saved
  }
  return new-x, new-y
}

fn test-render-line-with-stack-singleton {
  # line = [1]
  var line-storage: line
  var line/esi: (addr line) <- address line-storage
  parse-line "1", line
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 4
  #
  var new-x/eax: int <- copy 0
  var new-y/ecx: int <- copy 0
  new-x, new-y <- render-line-with-stack screen, line, 0/x, 0/y, 0/no-cursor
  check-screen-row screen, 0/y, "1  ", "F - test-render-line-with-stack-singleton/0"
  check-screen-row screen, 1/y, " 1 ", "F - test-render-line-with-stack-singleton/1"
  # not bothering to test hash colors for numbers
}

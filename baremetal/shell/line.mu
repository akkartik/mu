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

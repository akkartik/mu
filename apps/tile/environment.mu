type environment {
  screen: (handle screen)
  functions: (handle function)
  sandboxes: (handle sandbox)
  nrows: int
  ncols: int
  code-separator-col: int
}

fn initialize-environment _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  # initialize some predefined function definitions
  var functions/eax: (addr handle function) <- get env, functions
  create-primitive-functions functions
  # initialize first sandbox
  var sandbox-ah/eax: (addr handle sandbox) <- get env, sandboxes
  allocate sandbox-ah
  var sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
  initialize-sandbox sandbox
  # initialize screen
  var screen-ah/eax: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size screen
  var dest/edx: (addr int) <- get env, nrows
  copy-to *dest, nrows
  dest <- get env, ncols
  copy-to *dest, ncols
  var repl-col/ecx: int <- copy ncols
  repl-col <- shift-right 1
  dest <- get env, code-separator-col
  copy-to *dest, repl-col
}

fn draw-screen _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  var screen-ah/eax: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  var dest/edx: (addr int) <- get env, code-separator-col
  var tmp/eax: int <- copy *dest
  clear-canvas env
  tmp <- add 2  # repl-margin-left
  move-cursor screen, 3, tmp  # input-row
}

fn initialize-environment-with-fake-screen _self: (addr environment), nrows: int, ncols: int {
  var self/esi: (addr environment) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  allocate screen-ah
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  initialize-screen screen-addr, nrows, ncols
  initialize-environment self
}

fn process _self: (addr environment), key: grapheme {
$process:body: {
    var self/esi: (addr environment) <- copy _self
    var functions/ecx: (addr handle function) <- get self, functions
    var sandbox-ah/eax: (addr handle sandbox) <- get self, sandboxes
    var _sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
    var sandbox/edi: (addr sandbox) <- copy _sandbox
    var cursor-word-storage: (handle word)
    var cursor-word-ah/ebx: (addr handle word) <- address cursor-word-storage
    get-cursor-word sandbox, functions, cursor-word-ah
    var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    var cursor-word/ecx: (addr word) <- copy _cursor-word
    compare key, 0x445b1b  # left-arrow
    {
      break-if-!=
      # if not at start, move left within current word
      var at-start?/eax: boolean <- cursor-at-start? cursor-word
      compare at-start?, 0  # false
      {
        break-if-=
        cursor-left cursor-word
        break $process:body
      }
      # otherwise, move to end of prev word
      var prev-word-ah/eax: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      {
        compare prev-word, 0
        break-if-=
        cursor-to-end prev-word
        var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        decrement-final-element cursor-call-path
      }
      break $process:body
    }
    compare key, 0x435b1b  # right-arrow
    {
      break-if-!=
      # if not at end, move right within current word
      var at-end?/eax: boolean <- cursor-at-end? cursor-word
      compare at-end?, 0  # false
      {
        break-if-=
        cursor-right cursor-word
        break $process:body
      }
      # otherwise, move to start of next word
      var next-word-ah/eax: (addr handle word) <- get cursor-word, next
      var next-word/eax: (addr word) <- lookup *next-word-ah
      {
        compare next-word, 0
        break-if-=
        cursor-to-start next-word
        var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        increment-final-element cursor-call-path
      }
      break $process:body
    }
    compare key, 0x7f  # del (backspace on Macs)
    {
      break-if-!=
      # if not at start of some word, delete grapheme before cursor within current word
      var at-start?/eax: boolean <- cursor-at-start? cursor-word
      compare at-start?, 0  # false
      {
        break-if-=
        delete-before-cursor cursor-word
        break $process:body
      }
      # otherwise delete current word and move to end of prev word
      var prev-word-ah/eax: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      {
        compare prev-word, 0
        break-if-=
        cursor-to-end prev-word
        delete-next prev-word
        var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        decrement-final-element cursor-call-path
      }
      break $process:body
    }
    compare key, 0x20  # space
    {
      break-if-!=
      # insert new word
      append-word cursor-word-ah
      var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      increment-final-element cursor-call-path
      break $process:body
    }
    compare key, 0xa  # enter
    {
      break-if-!=
      # toggle display of subsidiary stack
      toggle-cursor-word sandbox
      break $process:body
    }
    # otherwise insert key within current word
    var g/edx: grapheme <- copy key
    var print?/eax: boolean <- real-grapheme? key
    {
      compare print?, 0  # false
      break-if-=
      add-grapheme-to-word cursor-word, g
      break $process:body
    }
    # silently ignore other hotkeys
}
}

fn get-cursor-word _sandbox: (addr sandbox), functions: (addr handle function), out: (addr handle word) {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var cursor-call-path/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
  var line/ecx: (addr handle line) <- get sandbox, data
  get-word-from-path line, functions, cursor-call-path, out
}

fn get-word-from-path _line: (addr handle line), functions: (addr handle function), _path-ah: (addr handle call-path-element), out: (addr handle word) {
  # if (path->next)
  #   get-word-from-path(line, functions, path->next, out)
  #   line = function-body(functions, out)
  # word-index(line, path->index-in-body, out)
  var path-ah/eax: (addr handle call-path-element) <- copy _path-ah
  var _path/eax: (addr call-path-element) <- lookup *path-ah
  var path/ecx: (addr call-path-element) <- copy _path
  var next-ah/edx: (addr handle call-path-element) <- get path, next
  var next/eax: (addr call-path-element) <- lookup *next-ah
  var line-ah/ebx: (addr handle line) <- copy _line
  {
    compare next, 0
    break-if-=
    get-word-from-path _line, functions, next-ah, out
    function-body functions, out, line-ah
  }
  var n/ecx: (addr int) <- get path, index-in-body
  var line/eax: (addr line) <- lookup *line-ah
  var words/eax: (addr handle word) <- get line, data
  word-index words, *n, out
}

fn word-index _words: (addr handle word), _n: int, out: (addr handle word) {
$word-index:body: {
  var n/ecx: int <- copy _n
  {
    compare n, 0
    break-if-!=
    copy-object _words, out
    break $word-index:body
  }
  var words-ah/eax: (addr handle word) <- copy _words
  var words/eax: (addr word) <- lookup *words-ah
  var next/eax: (addr handle word) <- get words, next
  n <- decrement
  word-index next, n, out
}
}

fn toggle-cursor-word _sandbox: (addr sandbox) {
$toggle-cursor-word:body: {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var expanded-words/edi: (addr handle call-path) <- get sandbox, expanded-words
  var cursor-call-path/ecx: (addr handle call-path-element) <- get sandbox, cursor-call-path
  var already-expanded?/eax: boolean <- find-in-call-path expanded-words, cursor-call-path
  compare already-expanded?, 0  # false
  {
    break-if-!=
    # if not already-expanded, insert
    insert-in-call-path expanded-words cursor-call-path
    break $toggle-cursor-word:body
  }
  {
    break-if-=
    # otherwise delete
    delete-in-call-path expanded-words cursor-call-path
  }
}
}

fn evaluate-environment _env: (addr environment), stack: (addr value-stack) {
  var env/esi: (addr environment) <- copy _env
  # functions
  var functions/edx: (addr handle function) <- get env, functions
  # line
  var sandbox-ah/esi: (addr handle sandbox) <- get env, sandboxes
  var sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
  var line-ah/eax: (addr handle line) <- get sandbox, data
  var _line/eax: (addr line) <- lookup *line-ah
  var line/esi: (addr line) <- copy _line
  evaluate functions, 0, line, 0, stack
}

fn render _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  clear-canvas env
  # screen
  var screen-ah/eax: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # repl-col
  var _repl-col/eax: (addr int) <- get env, code-separator-col
  var repl-col/ecx: int <- copy *_repl-col
  repl-col <- add 2  # repl-margin-left
  # functions
  var functions/edx: (addr handle function) <- get env, functions
  # sandbox
  var sandbox-ah/eax: (addr handle sandbox) <- get env, sandboxes
  var sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
  render-sandbox screen, functions, 0, sandbox, 3, repl-col
}

fn render-sandbox screen: (addr screen), functions: (addr handle function), bindings: (addr table), _sandbox: (addr sandbox), top-row: int, left-col: int {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  # expanded-words
  var expanded-words/edi: (addr handle call-path) <- get sandbox, expanded-words
  # line
  var line-ah/eax: (addr handle line) <- get sandbox, data
  var _line/eax: (addr line) <- lookup *line-ah
  var line/ecx: (addr line) <- copy _line
  # cursor-word
  var cursor-word-storage: (handle word)
  var cursor-word-ah/eax: (addr handle word) <- address cursor-word-storage
  get-cursor-word sandbox, functions, cursor-word-ah
  var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
  var cursor-word/ebx: (addr word) <- copy _cursor-word
  # cursor-col
  var cursor-col: int
  var cursor-col-a/eax: (addr int) <- address cursor-col
  #
  var dummy/ecx: int <- render-line screen, functions, 0, line, expanded-words, 3, left-col, cursor-word, cursor-col-a  # input-row=3
  move-cursor screen, 3, cursor-col  # input-row
}

fn render-line screen: (addr screen), functions: (addr handle function), bindings: (addr table), _line: (addr line), expanded-words: (addr handle call-path), top-row: int, left-col: int, cursor-word: (addr word), cursor-col-a: (addr int) -> right-col/ecx: int {
  # curr-word
  var line/esi: (addr line) <- copy _line
  var first-word-ah/eax: (addr handle word) <- get line, data
  var curr-word/eax: (addr word) <- lookup *first-word-ah
  #
  var word-index-storage: (handle call-path-element)
  var word-index/ebx: (addr handle call-path-element) <- address word-index-storage
  allocate word-index  # leak
  # loop-carried dependency
  var curr-col/ecx: int <- copy left-col
  #
  {
    compare curr-word, 0
    break-if-=
    # if necessary, first render columns for subsidiary stack
    $render-line:subsidiary: {
      {
        # can't expand subsidiary stacks for now
        compare bindings, 0
        break-if-!= $render-line:subsidiary
        #
        var display-subsidiary-stack?/eax: boolean <- find-in-call-path expanded-words, word-index
        compare display-subsidiary-stack?, 0  # false
        break-if-= $render-line:subsidiary
      }
      # does function exist?
      var callee/edi: (addr function) <- copy 0
      {
        var curr-stream-storage: (stream byte 0x10)
        var curr-stream/esi: (addr stream byte) <- address curr-stream-storage
        emit-word curr-word, curr-stream
        var callee-h: (handle function)
        var callee-ah/eax: (addr handle function) <- address callee-h
        find-function functions, curr-stream, callee-ah
        var _callee/eax: (addr function) <- lookup *callee-ah
        callee <- copy _callee
        compare callee, 0
        break-if-= $render-line:subsidiary
      }
      move-cursor screen, top-row, curr-col
      print-word screen, curr-word
      {
        var word-len/eax: int <- word-length curr-word
        curr-col <- add word-len
        curr-col <- add 2
        increment top-row
      }
      # obtain stack at call site
      var stack-storage: value-stack
      var stack/edx: (addr value-stack) <- address stack-storage
      initialize-value-stack stack, 0x10
      {
        var prev-word-ah/eax: (addr handle word) <- get curr-word, prev
        var prev-word/eax: (addr word) <- lookup *prev-word-ah
        compare prev-word, 0
        break-if-=
        evaluate functions, bindings, line, prev-word, stack
      }
      # construct new bindings
      var callee-bindings-storage: table
      var callee-bindings/esi: (addr table) <- address callee-bindings-storage
      initialize-table callee-bindings, 0x10
      bind-args callee, stack, callee-bindings
      # obtain body
      var callee-body-ah/eax: (addr handle line) <- get callee, body
      var callee-body/eax: (addr line) <- lookup *callee-body-ah
      # - render subsidiary stack
      curr-col <- render-line screen, functions, callee-bindings, callee-body, 0, top-row, curr-col, cursor-word, cursor-col-a
      #
      move-cursor screen, top-row, curr-col
      print-code-point screen, 0x21d7  # ⇗
      #
      curr-col <- add 2
      decrement top-row
    }
    # debug info: print word index
#?     decrement top-row
#?       move-cursor screen, top-row, curr-col
#?       start-color screen, 8, 7
#?         {
#?           var word-index-val/eax: int <- final-element-value word-index
#?           print-int32-hex-bits screen, word-index-val, 4
#?         }
#?       reset-formatting screen
#?     increment top-row
    # now render main column
    curr-col <- render-column screen, functions, bindings, line, curr-word, top-row, curr-col, cursor-word, cursor-col-a
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    increment-final-element word-index
    loop
  }
  right-col <- copy curr-col
}

# Render:
#   - starting at top-row, left-col: final-word
#   - starting somewhere below at left-col: the stack result from interpreting first-world to final-word (inclusive)
#     unless final-word is truly the final word, in which case it might be incomplete
#
# Outputs:
# - Return the farthest column written.
# - If final-word is same as cursor-word, do some additional computation to set
#   cursor-col-a.
fn render-column screen: (addr screen), functions: (addr handle function), bindings: (addr table), scratch: (addr line), final-word: (addr word), top-row: int, left-col: int, cursor-word: (addr word), cursor-col-a: (addr int) -> right-col/ecx: int {
  var max-width/ecx: int <- copy 0
  {
    # indent stack
    var indented-col/ebx: int <- copy left-col
    indented-col <- add 1  # margin-right - 2 for padding spaces
    # compute stack
    var stack: value-stack
    var stack-addr/edi: (addr value-stack) <- address stack
    initialize-value-stack stack-addr, 0x10  # max-words
    evaluate functions, bindings, scratch, final-word, stack-addr
    # render stack
    var curr-row/edx: int <- copy top-row
    curr-row <- add 3  # stack-margin-top
    var _max-width/eax: int <- value-stack-max-width stack-addr
    var max-width/esi: int <- copy _max-width
    var i/eax: int <- value-stack-length stack-addr
    {
      compare i, 0
      break-if-<=
      move-cursor screen, curr-row, indented-col
      {
        var val/eax: int <- pop-int-from-value-stack stack-addr
        render-integer screen, val, max-width
        var size/eax: int <- decimal-size val
        compare size, max-width
        break-if-<=
        max-width <- copy size
      }
      curr-row <- increment
      i <- decrement
      loop
    }
  }

  # render word, initialize result
  reset-formatting screen
  move-cursor screen, top-row, left-col
  print-word screen, final-word
  {
    var size/eax: int <- word-length final-word
    compare size, max-width
    break-if-<=
    max-width <- copy size
  }

  # update cursor
  {
    var f/eax: (addr word) <- copy final-word
    compare f, cursor-word
    break-if-!=
    var cursor-index/eax: int <- cursor-index cursor-word
    cursor-index <- add left-col
    var dest/edi: (addr int) <- copy cursor-col-a
    copy-to *dest, cursor-index
  }

  # post-process right-col
  right-col <- copy max-width
  right-col <- add left-col
  right-col <- add 3  # margin-right
}

# synaesthesia
fn render-integer screen: (addr screen), val: int, max-width: int {
  var bg/eax: int <- hash-color val
  var fg/ecx: int <- copy 7
  {
    compare bg, 2
    break-if-!=
    fg <- copy 0
  }
  {
    compare bg, 3
    break-if-!=
    fg <- copy 0
  }
  {
    compare bg, 6
    break-if-!=
    fg <- copy 0
  }
  start-color screen, fg, bg
  print-grapheme screen, 0x20  # space
  print-int32-decimal-right-justified screen, val, max-width
  print-grapheme screen, 0x20  # space
}

fn hash-color val: int -> result/eax: int {
  result <- try-modulo val, 7  # assumes that 7 is always the background color
}

fn clear-canvas _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  var screen-ah/edi: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  clear-screen screen
  var nrows/eax: (addr int) <- get env, nrows
  var _repl-col/ecx: (addr int) <- get env, code-separator-col
  var repl-col/ecx: int <- copy *_repl-col
  draw-vertical-line screen, 1, *nrows, repl-col
  move-cursor screen, 3, 2
  print-string screen, "x 2* = x 2 *"
  move-cursor screen, 4, 2
  print-string screen, "x 1+ = x 1 +"
  move-cursor screen, 5, 2
  print-string screen, "x 2+ = x 1+ 1+"
}

fn real-grapheme? g: grapheme -> result/eax: boolean {
$real-grapheme?:body: {
  # if g == newline return true
  compare g, 0xa
  {
    break-if-!=
    result <- copy 1  # true
    break $real-grapheme?:body
  }
  # if g == tab return true
  compare g, 9
  {
    break-if-!=
    result <- copy 1  # true
    break $real-grapheme?:body
  }
  # if g < 32 return false
  compare g, 0x20
  {
    break-if->=
    result <- copy 0  # false
    break $real-grapheme?:body
  }
  # if g <= 255 return true
  compare g, 0xff
  {
    break-if->
    result <- copy 1  # true
    break $real-grapheme?:body
  }
  # if (g&0xff == Esc) it's an escape sequence
  and-with g, 0xff
  compare g, 0x1b  # Esc
  {
    break-if-!=
    result <- copy 0  # false
    break $real-grapheme?:body
  }
  # otherwise return true
  result <- copy 1  # true
}
}

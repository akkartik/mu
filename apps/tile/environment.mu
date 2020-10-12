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
#?     {
#?       print-string 0, "A: line starts with "
#?       var line-ah/eax: (addr handle line) <- get sandbox, data
#?       var line/eax: (addr line) <- lookup *line-ah
#?       var first-word-ah/eax: (addr handle word) <- get line, data
#?       var curr-word/eax: (addr word) <- lookup *first-word-ah
#?       print-word 0, curr-word
#?       print-string 0, "\n"
#?     }
    get-cursor-word sandbox, functions, cursor-word-ah
#?     {
#?       print-string 0, "Z: line starts with "
#?       var line-ah/eax: (addr handle line) <- get sandbox, data
#?       var line/eax: (addr line) <- lookup *line-ah
#?       var first-word-ah/eax: (addr handle word) <- get line, data
#?       var curr-word/eax: (addr word) <- lookup *first-word-ah
#?       print-word 0, curr-word
#?       print-string 0, "\n"
#?     }
    var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    var cursor-word/ecx: (addr word) <- copy _cursor-word
    compare key, 0x445b1b  # left-arrow
    $process:key-left-arrow: {
      break-if-!=
#?       print-string 0, "left-arrow\n"
      # if not at start, move left within current word
      var at-start?/eax: boolean <- cursor-at-start? cursor-word
      compare at-start?, 0  # false
      {
        break-if-=
#?         print-string 0, "cursor left within word\n"
        cursor-left cursor-word
        break $process:body
      }
      # if current word is expanded, move to the rightmost word in its body
      {
        var cursor-call-path/esi: (addr handle call-path-element) <- get sandbox, cursor-call-path
        var expanded-words/edx: (addr handle call-path) <- get sandbox, expanded-words
        var curr-word-is-expanded?/eax: boolean <- find-in-call-path expanded-words, cursor-call-path
        compare curr-word-is-expanded?, 0  # false
        break-if-=
        # update cursor-call-path
#?         print-string 0, "curr word is expanded\n"
        var self/ecx: (addr environment) <- copy _self
        var functions/ecx: (addr handle function) <- get self, functions
        var n/eax: int <- body-length functions, cursor-word-ah
        n <- decrement
        push-to-call-path-element cursor-call-path, n
        # move cursor to end of word
        get-cursor-word sandbox, functions, cursor-word-ah
        var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
        cursor-to-end cursor-word
        break $process:body
      }
      # if at first word, look for a caller to jump to
      $process:key-left-arrow-first-word: {
        var prev-word-ah/edx: (addr handle word) <- get cursor-word, prev
        var prev-word/eax: (addr word) <- lookup *prev-word-ah
        compare prev-word, 0
        break-if-!=
        $process:key-left-arrow-first-word-and-caller: {
#?           print-string 0, "return\n"
          {
            var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
            var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
            var next-cursor-element-ah/edx: (addr handle call-path-element) <- get cursor-call-path, next
            var next-cursor-element/eax: (addr call-path-element) <- lookup *next-cursor-element-ah
            compare next-cursor-element, 0
            break-if-= $process:key-left-arrow-first-word-and-caller
            copy-object next-cursor-element-ah, cursor-call-path-ah
          }
          var functions/eax: (addr handle function) <- get self, functions
          get-cursor-word sandbox, functions, cursor-word-ah
          var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
          cursor-word <- copy _cursor-word
        }
      }
      # then move to end of previous word
      var prev-word-ah/edx: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      {
        compare prev-word, 0
        break-if-=
#?         print-string 0, "previous word\n"
        copy-object prev-word-ah, cursor-word-ah
        cursor-to-end prev-word
        var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        decrement-final-element cursor-call-path
      }
      break $process:body
    }
    compare key, 0x435b1b  # right-arrow
    $process:key-right-arrow: {
      break-if-!=
      # if not at end, move right within current word
      var at-end?/eax: boolean <- cursor-at-end? cursor-word
      compare at-end?, 0  # false
      {
        break-if-=
#?         print-string 0, "a\n"
        cursor-right cursor-word
        break $process:body
      }
      # if at final word, look for a caller to jump to
      {
        var next-word-ah/edx: (addr handle word) <- get cursor-word, next
        var next-word/eax: (addr word) <- lookup *next-word-ah
        compare next-word, 0
        break-if-!=
        var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
        var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
        var next-cursor-element-ah/ecx: (addr handle call-path-element) <- get cursor-call-path, next
        var next-cursor-element/eax: (addr call-path-element) <- lookup *next-cursor-element-ah
        compare next-cursor-element, 0
        break-if-=
        copy-object next-cursor-element-ah, cursor-call-path-ah
        break $process:body
      }
      # otherwise, move to the next word
      var next-word-ah/edx: (addr handle word) <- get cursor-word, next
      var next-word/eax: (addr word) <- lookup *next-word-ah
      {
        compare next-word, 0
        break-if-=
#?         print-string 0, "b\n"
        cursor-to-start next-word
        # . . cursor-word now out of date
        var cursor-call-path/ecx: (addr handle call-path-element) <- get sandbox, cursor-call-path
        increment-final-element cursor-call-path
        # Is the new cursor word expanded? If so, it's a function call. Add a
        # new level to the cursor-call-path for the call's body.
        {
#?           print-string 0, "c\n"
          var expanded-words/eax: (addr handle call-path) <- get sandbox, expanded-words
          var curr-word-is-expanded?/eax: boolean <- find-in-call-path expanded-words, cursor-call-path
          compare curr-word-is-expanded?, 0  # false
          break-if-=
          push-to-call-path-element cursor-call-path, 0
          # position cursor at left
          var functions/eax: (addr handle function) <- get self, functions
          get-cursor-word sandbox, functions, cursor-word-ah
          var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
          cursor-to-start cursor-word
#?           print-string 0, "d\n"
          break $process:body
        }
      }
      break $process:body
    }
    compare key, 0xa  # enter
    {
      break-if-!=
      # toggle display of subsidiary stack
      toggle-cursor-word sandbox
      break $process:body
    }
    # word-based motions
    compare key, 2  # ctrl-b
    $process:prev-word: {
      break-if-!=
#?       print-string 0, "AA\n"
      # jump to previous word at same level
      var prev-word-ah/edx: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      {
        compare prev-word, 0
        break-if-=
        copy-object prev-word-ah, cursor-word-ah
        cursor-to-end prev-word
        var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        decrement-final-element cursor-call-path
        break $process:body
      }
      # if previous word doesn't exist, try to bump up one level
#?       print-string 0, "BB\n"
      {
        var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
        var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
        var caller-cursor-element-ah/ecx: (addr handle call-path-element) <- get cursor-call-path, next
        var caller-cursor-element/eax: (addr call-path-element) <- lookup *caller-cursor-element-ah
        compare caller-cursor-element, 0
        break-if-=
        # check if previous word exists in caller
#?         print-string 0, "CC\n"
        var caller-index/eax: (addr int) <- get caller-cursor-element, index-in-body
        compare *caller-index, 0
        break-if-<=
        # if so jump to it
#?         print-string 0, "DD\n"
        copy-object caller-cursor-element-ah, cursor-call-path-ah
        decrement-final-element cursor-call-path-ah
        break $process:body
      }
    }
    compare key, 6  # ctrl-f
    $process:next-word: {
      break-if-!=
#?       print-string 0, "AA\n"
      # jump to previous word at same level
      var next-word-ah/edx: (addr handle word) <- get cursor-word, next
      var next-word/eax: (addr word) <- lookup *next-word-ah
      {
        compare next-word, 0
        break-if-=
#?         print-string 0, "BB\n"
        copy-object next-word-ah, cursor-word-ah
        cursor-to-end next-word
        var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        increment-final-element cursor-call-path
        break $process:body
      }
      # if next word doesn't exist, try to bump up one level
#?       print-string 0, "CC\n"
      var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
      var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
      var caller-cursor-element-ah/ecx: (addr handle call-path-element) <- get cursor-call-path, next
      var caller-cursor-element/eax: (addr call-path-element) <- lookup *caller-cursor-element-ah
      compare caller-cursor-element, 0
      break-if-=
#?       print-string 0, "DD\n"
      copy-object caller-cursor-element-ah, cursor-call-path-ah
      break $process:body
    }
    # line-based motions
    compare key, 1  # ctrl-a
    $process:start-of-line: {
      break-if-!=
      # move cursor to initial word of sandbox
      var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      allocate cursor-call-path-ah
      # move cursor to start of initial word
      var functions/ecx: (addr handle function) <- get self, functions
      get-cursor-word sandbox, functions, cursor-word-ah
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      cursor-to-start cursor-word
      # this works as long as the first word isn't expanded
      # but we don't expect to see zero-arg functions first-up
      break $process:body
    }
    compare key, 5  # ctrl-e
    $process:end-of-line: {
      break-if-!=
      # move cursor to final word of sandbox
      var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      allocate cursor-call-path-ah
      var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
      var dest/edx: (addr int) <- get cursor-call-path, index-in-body
      var line-ah/eax: (addr handle line) <- get sandbox, data
      var line/eax: (addr line) <- lookup *line-ah
      var n/eax: int <- line-length line
      n <- decrement
      copy-to *dest, n
      # move cursor to end of final word
      var functions/ecx: (addr handle function) <- get self, functions
      get-cursor-word sandbox, functions, cursor-word-ah
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      cursor-to-end cursor-word
      # this works because expanded words lie to the right of their bodies
      # so the final word is always guaranteed to be at the top-level
      break $process:body
    }
    compare key, 0x15  # ctrl-u
    $process:clear-line: {
      break-if-!=
      # clear line in sandbox
      var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      allocate cursor-call-path-ah
      var line-ah/eax: (addr handle line) <- get sandbox, data
      allocate line-ah
      var line/eax: (addr line) <- lookup *line-ah
      initialize-line line
      break $process:body
    }
    # if cursor is within a call, disable editing hotkeys below
    var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
    var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
    var next-cursor-element-ah/eax: (addr handle call-path-element) <- get cursor-call-path, next
    var next-cursor-element/eax: (addr call-path-element) <- lookup *next-cursor-element-ah
    compare next-cursor-element, 0
    break-if-!= $process:body
    # - remaining keys only work at the top row outside any function calls
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
#?   {
#?     print-string 0, "B: line starts with "
#?     var line-ah/eax: (addr handle line) <- get sandbox, data
#?     var line/eax: (addr line) <- lookup *line-ah
#?     var first-word-ah/eax: (addr handle word) <- get line, data
#?     var curr-word/eax: (addr word) <- lookup *first-word-ah
#?     print-word 0, curr-word
#?     print-string 0, "\n"
#?   }
  get-word-from-path line, functions, cursor-call-path, out
#?   {
#?     print-string 0, "Y: line starts with "
#?     var line-ah/eax: (addr handle line) <- get sandbox, data
#?     var line/eax: (addr line) <- lookup *line-ah
#?     var first-word-ah/eax: (addr handle word) <- get line, data
#?     var curr-word/eax: (addr word) <- lookup *first-word-ah
#?     print-word 0, curr-word
#?     print-string 0, "\n"
#?   }
}

fn get-word-from-path _line: (addr handle line), functions: (addr handle function), _path-ah: (addr handle call-path-element), out: (addr handle word) {
  # var tmp = line
  # if (path->next)
  #   get-word-from-path(line, functions, path->next, out)
  #   tmp = function-body(functions, out)
  # word-index(tmp, path->index-in-body, out)
#?   print-string 0, "C\n"
  var tmp: (handle line)
  {
    var tmp-ah/eax: (addr handle line) <- address tmp
    copy-object _line, tmp-ah
  }
  var path-ah/eax: (addr handle call-path-element) <- copy _path-ah
  var _path/eax: (addr call-path-element) <- lookup *path-ah
  var path/ecx: (addr call-path-element) <- copy _path
  var next-ah/edx: (addr handle call-path-element) <- get path, next
  var next/eax: (addr call-path-element) <- lookup *next-ah
  {
    compare next, 0
    break-if-=
    get-word-from-path _line, functions, next-ah, out
#?     {
#?       print-string 0, "D: line starts with "
#?       var line/eax: (addr line) <- lookup *line-ah
#?       var words/eax: (addr handle word) <- get line, data
#?       var curr-word/eax: (addr word) <- lookup *words
#?       print-word 0, curr-word
#?       print-string 0, "\n"
#?     }
    var tmp-ah/eax: (addr handle line) <- address tmp
    function-body functions, out, tmp-ah
#?     {
#?       print-string 0, "G: line starts with "
#?       var line/eax: (addr line) <- lookup *line-ah
#?       var words/eax: (addr handle word) <- get line, data
#?       var curr-word/eax: (addr word) <- lookup *words
#?       print-word 0, curr-word
#?       print-string 0, "\n"
#?     }
    # TODO: support multiple levels
  }
  var n/ecx: (addr int) <- get path, index-in-body
  var line/eax: (addr line) <- lookup tmp
  var words/eax: (addr handle word) <- get line, data
#?   {
#?     print-string 0, "M: line starts with "
#?     var curr-word/eax: (addr word) <- lookup *words
#?     print-word 0, curr-word
#?     print-string 0, "\n"
#?   }
  word-index words, *n, out
#?   {
#?     print-string 0, "P: line starts with "
#?     var curr-word/eax: (addr word) <- lookup *words
#?     print-word 0, curr-word
#?     print-string 0, "\n"
#?   }
#?   print-string 0, "X\n"
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
#?   print-string 0, "cursor call path: "
#?   dump-call-path-element 0, cursor-call-path
#?   print-string 0, "expanded words:\n"
#?   dump-call-paths 0, expanded-words
  var already-expanded?/eax: boolean <- find-in-call-path expanded-words, cursor-call-path
  compare already-expanded?, 0  # false
  {
    break-if-!=
#?     print-string 0, "expand\n"
    # if not already-expanded, insert
    insert-in-call-path expanded-words cursor-call-path
#?     print-string 0, "expanded words now:\n"
#?     dump-call-paths 0, expanded-words
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
#?   {
#?     var line-ah/eax: (addr handle line) <- get sandbox, data
#?     var line/eax: (addr line) <- lookup *line-ah
#?     var first-word-ah/eax: (addr handle word) <- get line, data
#?     var curr-word/eax: (addr word) <- lookup *first-word-ah
#?     print-word 0, curr-word
#?     print-string 0, "\n"
#?   }
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
  var cursor-col-a/edx: (addr int) <- address cursor-col
  # cursor-call-path
  var cursor-call-path: (addr handle call-path-element)
  {
    var src/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
    copy-to cursor-call-path, src
  }
  #
  var curr-path-storage: (handle call-path-element)
  var curr-path/esi: (addr handle call-path-element) <- address curr-path-storage
  allocate curr-path  # leak
#?   print-string 0, "==\n"
  var dummy/ecx: int <- render-line screen, functions, 0, line, expanded-words, 3, left-col, curr-path, cursor-word, cursor-call-path, cursor-col-a  # input-row=3
  var cursor-row/eax: int <- call-depth-at-cursor _sandbox
  move-cursor screen, cursor-row, cursor-col
}

fn call-depth-at-cursor _sandbox: (addr sandbox) -> result/eax: int {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var cursor-call-path/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
  result <- call-path-element-length cursor-call-path
  result <- add 2  # input-row-1
}

fn call-path-element-length _x: (addr handle call-path-element) -> result/eax: int {
  var curr-ah/ecx: (addr handle call-path-element) <- copy _x
  var out/edi: int <- copy 0
  {
    var curr/eax: (addr call-path-element) <- lookup *curr-ah
    compare curr, 0
    break-if-=
    curr-ah <- get curr, next
    out <- increment
    loop
  }
  result <- copy out
}

# Render the line of words in line, along with the state of the stack under each word.
# Also render any expanded function calls using recursive calls.
#
# Along the way, compute the column the cursor should be positioned at (cursor-col-a).
fn render-line screen: (addr screen), functions: (addr handle function), bindings: (addr table), _line: (addr line), expanded-words: (addr handle call-path), top-row: int, left-col: int, curr-path: (addr handle call-path-element), cursor-word: (addr word), cursor-call-path: (addr handle call-path-element), cursor-col-a: (addr int) -> right-col/ecx: int {
#?   print-string 0, "--\n"
  # curr-word
  var line/esi: (addr line) <- copy _line
  var first-word-ah/eax: (addr handle word) <- get line, data
  var curr-word/eax: (addr word) <- lookup *first-word-ah
  #
  # loop-carried dependency
  var curr-col/ecx: int <- copy left-col
  #
  {
    compare curr-word, 0
    break-if-=
#?     print-string 0, "-- "
#?     dump-call-path-element 0, curr-path
#?     print-word 0, curr-word
#?     print-string 0, "\n"

#?     {
#?       var dummy/eax: grapheme <- read-key-from-real-keyboard
#?     }
    # if necessary, first render columns for subsidiary stack
    $render-line:subsidiary: {
      {
#?         print-string 0, "check sub\n"
        var display-subsidiary-stack?/eax: boolean <- find-in-call-path expanded-words, curr-path
        compare display-subsidiary-stack?, 0  # false
        break-if-= $render-line:subsidiary
      }
#?       print-string 0, "render subsidiary stack\n"
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
      start-color screen, 8, 7
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
      push-to-call-path-element curr-path, 0  # leak
      curr-col <- render-line screen, functions, callee-bindings, callee-body, expanded-words, top-row, curr-col, curr-path, cursor-word, cursor-call-path, cursor-col-a
      drop-from-call-path-element curr-path
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
    # render main column
    var old-col/edx: int <- copy curr-col
    curr-col <- render-column screen, functions, bindings, line, curr-word, top-row, curr-col
    # cache cursor column if necessary
    $render-line:cache-cursor-column: {
      {
        var found?/eax: boolean <- call-path-element-match? curr-path, cursor-call-path
        compare found?, 0  # false
        break-if-= $render-line:cache-cursor-column
      }
      var dest/edi: (addr int) <- copy cursor-col-a
      copy-to *dest, old-col
      var cursor-index-in-word/eax: int <- cursor-index curr-word
      add-to *dest, cursor-index-in-word
    }
    # loop update
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    increment-final-element curr-path
    loop
  }
  right-col <- copy curr-col
}

# Render:
#   - starting at top-row, left-col: final-word
#   - starting somewhere below at left-col: the stack result from interpreting first-world to final-word (inclusive)
#
# Return the farthest column written.
fn render-column screen: (addr screen), functions: (addr handle function), bindings: (addr table), scratch: (addr line), final-word: (addr word), top-row: int, left-col: int -> right-col/ecx: int {
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
  # wordstar-style cheatsheet of shortcuts
  move-cursor screen, *nrows, 0
  start-reverse-video screen
  print-string screen, " ctrl-q "
  reset-formatting screen
  print-string screen, " quit "
  var menu-start/ecx: int <- copy repl-col
  menu-start <- subtract 0x2c  # 44 = half the size of the menu
  move-cursor screen, *nrows, menu-start
  start-reverse-video screen
  print-string screen, " ctrl-a "
  reset-formatting screen
  print-string screen, " ⏮   "
  start-reverse-video screen
  print-string screen, " ctrl-b "
  reset-formatting screen
  print-string screen, " ◀ prev word  "
  start-reverse-video screen
  print-string screen, " ctrl-f "
  reset-formatting screen
  print-string screen, " next word ▶  "
  start-reverse-video screen
  print-string screen, " ctrl-e "
  reset-formatting screen
  print-string screen, " ⏭  "
  start-reverse-video screen
  print-string screen, " ctrl-u "
  reset-formatting screen
  print-string screen, " clear line  "
  # currently defined functions
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

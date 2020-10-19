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

#############
# Iterate
#############

fn process _self: (addr environment), key: grapheme {
$process:body: {
  var self/esi: (addr environment) <- copy _self
  var sandbox-ah/eax: (addr handle sandbox) <- get self, sandboxes
  var _sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
  var sandbox/edi: (addr sandbox) <- copy _sandbox
  var rename-word-mode-ah?/ecx: (addr handle word) <- get sandbox, partial-name-for-cursor-word
  var rename-word-mode?/eax: (addr word) <- lookup *rename-word-mode-ah?
  compare rename-word-mode?, 0
  {
    break-if-!=
#?     print-string 0, "processing sandbox\n"
    process-sandbox self, sandbox, key
    break $process:body
  }
  {
    break-if-=
#?     print-string 0, "processing sandbox rename\n"
    process-sandbox-rename sandbox, key
  }
}
}

fn process-sandbox _self: (addr environment), _sandbox: (addr sandbox), key: grapheme {
$process-sandbox:body: {
  var self/esi: (addr environment) <- copy _self
  var sandbox/edi: (addr sandbox) <- copy _sandbox
  var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
  var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
  var cursor-word-ah/ebx: (addr handle word) <- get cursor-call-path, word
  var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
  var cursor-word/ecx: (addr word) <- copy _cursor-word
  compare key, 0x445b1b  # left-arrow
  $process-sandbox:key-left-arrow: {
    break-if-!=
#?     print-string 0, "left-arrow\n"
    # if not at start, move left within current word
    var at-start?/eax: boolean <- cursor-at-start? cursor-word
    compare at-start?, 0  # false
    {
      break-if-!=
#?       print-string 0, "cursor left within word\n"
      cursor-left cursor-word
      break $process-sandbox:body
    }
    # if current word is expanded, move to the rightmost word in its body
    {
      var cursor-call-path/esi: (addr handle call-path-element) <- get sandbox, cursor-call-path
      var expanded-words/edx: (addr handle call-path) <- get sandbox, expanded-words
      var curr-word-is-expanded?/eax: boolean <- find-in-call-path expanded-words, cursor-call-path
      compare curr-word-is-expanded?, 0  # false
      break-if-=
      # update cursor-call-path
#?       print-string 0, "curr word is expanded\n"
      var self/ecx: (addr environment) <- copy _self
      var functions/ecx: (addr handle function) <- get self, functions
      var body: (handle line)
      var body-ah/eax: (addr handle line) <- address body
      function-body functions, cursor-word-ah, body-ah
      var body-addr/eax: (addr line) <- lookup *body-ah
      var first-word-ah/edx: (addr handle word) <- get body-addr, data
      var final-word-h: (handle word)
      var final-word-ah/eax: (addr handle word) <- address final-word-h
      final-word first-word-ah, final-word-ah
      push-to-call-path-element cursor-call-path, final-word-ah
      # move cursor to end of word
      var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
      var cursor-word-ah/eax: (addr handle word) <- get cursor-call-path, word
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      cursor-to-end cursor-word
      break $process-sandbox:body
    }
    # if at first word, look for a caller to jump to
    $process-sandbox:key-left-arrow-first-word: {
      var prev-word-ah/edx: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      compare prev-word, 0
      break-if-!=
      $process-sandbox:key-left-arrow-first-word-and-caller: {
#?         print-string 0, "return\n"
        {
          var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
          var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
          var next-cursor-element-ah/edx: (addr handle call-path-element) <- get cursor-call-path, next
          var next-cursor-element/eax: (addr call-path-element) <- lookup *next-cursor-element-ah
          compare next-cursor-element, 0
          break-if-= $process-sandbox:key-left-arrow-first-word-and-caller
          copy-object next-cursor-element-ah, cursor-call-path-ah
        }
        var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
        var cursor-word-ah/eax: (addr handle word) <- get cursor-call-path, word
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
#?       print-string 0, "previous word\n"
      cursor-to-end prev-word
      var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      decrement-final-element cursor-call-path
    }
    break $process-sandbox:body
  }
  compare key, 0x435b1b  # right-arrow
  $process-sandbox:key-right-arrow: {
    break-if-!=
    # if not at end, move right within current word
    var at-end?/eax: boolean <- cursor-at-end? cursor-word
    compare at-end?, 0  # false
    {
      break-if-!=
#?       print-string 0, "a\n"
      cursor-right cursor-word
      break $process-sandbox:body
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
      break $process-sandbox:body
    }
    # otherwise, move to the next word
    var next-word-ah/edx: (addr handle word) <- get cursor-word, next
    var next-word/eax: (addr word) <- lookup *next-word-ah
    {
      compare next-word, 0
      break-if-=
#?       print-string 0, "b\n"
      cursor-to-start next-word
      # . . cursor-word now out of date
      var cursor-call-path/ecx: (addr handle call-path-element) <- get sandbox, cursor-call-path
      increment-final-element cursor-call-path
      # Is the new cursor word expanded? If so, it's a function call. Add a
      # new level to the cursor-call-path for the call's body.
      $process-sandbox:key-right-arrow-next-word-is-call-expanded: {
#?         print-string 0, "c\n"
        {
          var expanded-words/eax: (addr handle call-path) <- get sandbox, expanded-words
          var curr-word-is-expanded?/eax: boolean <- find-in-call-path expanded-words, cursor-call-path
          compare curr-word-is-expanded?, 0  # false
          break-if-= $process-sandbox:key-right-arrow-next-word-is-call-expanded
        }
        var callee-h: (handle function)
        var callee-ah/edx: (addr handle function) <- address callee-h
        var functions/ebx: (addr handle function) <- get self, functions
        callee functions, next-word, callee-ah
        var callee/eax: (addr function) <- lookup *callee-ah
        var callee-body-ah/eax: (addr handle line) <- get callee, body
        var callee-body/eax: (addr line) <- lookup *callee-body-ah
        var callee-body-first-word/edx: (addr handle word) <- get callee-body, data
        push-to-call-path-element cursor-call-path, callee-body-first-word
        # position cursor at left
        var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
        var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
        var cursor-word-ah/eax: (addr handle word) <- get cursor-call-path, word
        var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
        cursor-to-start cursor-word
#?         print-string 0, "d\n"
        break $process-sandbox:body
      }
    }
    break $process-sandbox:body
  }
  compare key, 0xa  # enter
  {
    break-if-!=
    # toggle display of subsidiary stack
    toggle-cursor-word sandbox
    break $process-sandbox:body
  }
  # word-based motions
  compare key, 2  # ctrl-b
  $process-sandbox:prev-word: {
    break-if-!=
    # jump to previous word at same level
    var prev-word-ah/edx: (addr handle word) <- get cursor-word, prev
    var prev-word/eax: (addr word) <- lookup *prev-word-ah
    {
      compare prev-word, 0
      break-if-=
      cursor-to-end prev-word
      var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      decrement-final-element cursor-call-path
      break $process-sandbox:body
    }
    # if previous word doesn't exist, try to bump up one level
    {
      var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
      var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
      var caller-cursor-element-ah/ecx: (addr handle call-path-element) <- get cursor-call-path, next
      var caller-cursor-element/eax: (addr call-path-element) <- lookup *caller-cursor-element-ah
      compare caller-cursor-element, 0
      break-if-=
      # check if previous word exists in caller
      var caller-word-ah/eax: (addr handle word) <- get caller-cursor-element, word
      var caller-word/eax: (addr word) <- lookup *caller-word-ah
      var word-before-caller-ah/eax: (addr handle word) <- get caller-word, prev
      var word-before-caller/eax: (addr word) <- lookup *word-before-caller-ah
      compare word-before-caller, 0
      break-if-=
      # if so jump to it
      drop-from-call-path-element cursor-call-path-ah
      decrement-final-element cursor-call-path-ah
      break $process-sandbox:body
    }
  }
  compare key, 6  # ctrl-f
  $process-sandbox:next-word: {
    break-if-!=
#?     print-string 0, "AA\n"
    # jump to previous word at same level
    var next-word-ah/edx: (addr handle word) <- get cursor-word, next
    var next-word/eax: (addr word) <- lookup *next-word-ah
    {
      compare next-word, 0
      break-if-=
#?       print-string 0, "BB\n"
      cursor-to-end next-word
      var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      increment-final-element cursor-call-path
      break $process-sandbox:body
    }
    # if next word doesn't exist, try to bump up one level
#?     print-string 0, "CC\n"
    var cursor-call-path-ah/edi: (addr handle call-path-element) <- get sandbox, cursor-call-path
    var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
    var caller-cursor-element-ah/ecx: (addr handle call-path-element) <- get cursor-call-path, next
    var caller-cursor-element/eax: (addr call-path-element) <- lookup *caller-cursor-element-ah
    compare caller-cursor-element, 0
    break-if-=
#?     print-string 0, "DD\n"
    copy-object caller-cursor-element-ah, cursor-call-path-ah
    break $process-sandbox:body
  }
  # line-based motions
  compare key, 1  # ctrl-a
  $process-sandbox:start-of-line: {
    break-if-!=
    # move cursor to initial word of sandbox
    var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
    initialize-path-from-sandbox sandbox, cursor-call-path-ah
    # move cursor to start of initial word
    var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
    var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
    var cursor-word-ah/eax: (addr handle word) <- get cursor-call-path, word
    var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    cursor-to-start cursor-word
    # this works as long as the first word isn't expanded
    # but we don't expect to see zero-arg functions first-up
    break $process-sandbox:body
  }
  compare key, 5  # ctrl-e
  $process-sandbox:end-of-line: {
    break-if-!=
    # move cursor to final word of sandbox
    var cursor-call-path-ah/ecx: (addr handle call-path-element) <- get sandbox, cursor-call-path
    initialize-path-from-sandbox sandbox, cursor-call-path-ah
    var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
    var dest/eax: (addr handle word) <- get cursor-call-path, word
    final-word dest, dest
    # move cursor to end of final word
    var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
    cursor-to-end cursor-word
    # this works because expanded words lie to the right of their bodies
    # so the final word is always guaranteed to be at the top-level
    break $process-sandbox:body
  }
  compare key, 0x15  # ctrl-u
  $process-sandbox:clear-line: {
    break-if-!=
    # clear line in sandbox
    initialize-sandbox sandbox
    break $process-sandbox:body
  }
  # if cursor is within a call, disable editing hotkeys below
  var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
  var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
  var next-cursor-element-ah/eax: (addr handle call-path-element) <- get cursor-call-path, next
  var next-cursor-element/eax: (addr call-path-element) <- lookup *next-cursor-element-ah
  compare next-cursor-element, 0
  break-if-!= $process-sandbox:body
  # - remaining keys only work at the top row outside any function calls
  compare key, 0x7f  # del (backspace on Macs)
  $process-sandbox:backspace: {
    break-if-!=
    # if not at start of some word, delete grapheme before cursor within current word
    var at-start?/eax: boolean <- cursor-at-start? cursor-word
    compare at-start?, 0  # false
    {
      break-if-!=
      delete-before-cursor cursor-word
      break $process-sandbox:body
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
    break $process-sandbox:body
  }
  compare key, 0x20  # space
  $process-sandbox:space: {
    break-if-!=
    # insert new word
    append-word cursor-word-ah
    var cursor-call-path/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
    increment-final-element cursor-call-path
    break $process-sandbox:body
  }
  compare key, 0x12  # ctrl-r
  $process:rename-word: {
    break-if-!=
    # TODO: ensure current word is not a function
    # rename word at cursor
    var new-name-ah/eax: (addr handle word) <- get sandbox, partial-name-for-cursor-word
    allocate new-name-ah
    var new-name/eax: (addr word) <- lookup *new-name-ah
    initialize-word new-name
    break $process-sandbox:body
  }
  # otherwise insert key within current word
  var g/edx: grapheme <- copy key
  var print?/eax: boolean <- real-grapheme? key
  $process-sandbox:real-grapheme: {
    compare print?, 0  # false
    break-if-=
    add-grapheme-to-word cursor-word, g
    break $process-sandbox:body
  }
  # silently ignore other hotkeys
}
}

# collect new name in partial-name-for-cursor-word, and then rename the word
# at cursor to it
# Precondition: cursor-call-path is a singleton (not within a call)
fn process-sandbox-rename _sandbox: (addr sandbox), key: grapheme {
$process-sandbox-rename:body: {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  var new-name-ah/edi: (addr handle word) <- get sandbox, partial-name-for-cursor-word
  # if 'esc' pressed, cancel rename
  compare key, 0x1b  # esc
  $process-sandbox-rename:cancel: {
    break-if-!=
    var empty: (handle word)
    copy-handle empty, new-name-ah
    break $process-sandbox-rename:body
  }
  # if 'enter' pressed, perform rename
  compare key, 0xa  # enter
  $process-sandbox-rename:commit: {
    break-if-!=
#?     print-string 0, "rename\n"
    # new line
    var new-line-h: (handle line)
    var new-line-ah/eax: (addr handle line) <- address new-line-h
    allocate new-line-ah
    var new-line/eax: (addr line) <- lookup *new-line-ah
    initialize-line new-line
    var new-line-word-ah/ecx: (addr handle word) <- get new-line, data
    {
      # move word at cursor to new line
      var cursor-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      var cursor/eax: (addr call-path-element) <- lookup *cursor-ah
      var word-at-cursor-ah/eax: (addr handle word) <- get cursor, word
#?       print-string 0, "cursor before at word "
#?       {
#?         var cursor-word/eax: (addr word) <- lookup *word-at-cursor-ah
#?         print-word 0, cursor-word
#?         print-string 0, "\n"
#?       }
      move-word-contents word-at-cursor-ah, new-line-word-ah
      # copy name to word at cursor
      copy-word-contents-before-cursor new-name-ah, word-at-cursor-ah
#?       print-string 0, "cursor after at word "
#?       {
#?         var cursor-word/eax: (addr word) <- lookup *word-at-cursor-ah
#?         print-word 0, cursor-word
#?         print-string 0, "\n"
#?         var foo/eax: int <- copy cursor-word
#?         print-int32-hex 0, foo
#?         print-string 0, "\n"
#?       }
#?       print-string 0, "new name word "
#?       {
#?         var new-name/eax: (addr word) <- lookup *new-name-ah
#?         print-word 0, new-name
#?         print-string 0, "\n"
#?         var foo/eax: int <- copy new-name
#?         print-int32-hex 0, foo
#?         print-string 0, "\n"
#?       }
    }
    # prepend '=' to name
    {
      var new-name/eax: (addr word) <- lookup *new-name-ah
      cursor-to-start new-name
      add-grapheme-to-word new-name, 0x3d  # '='
    }
    # append name to new line
    chain-words new-line-word-ah, new-name-ah
    # new-line->next = sandbox->data
    var new-line-next/ecx: (addr handle line) <- get new-line, next
    var sandbox-slot/edx: (addr handle line) <- get sandbox, data
    copy-object sandbox-slot, new-line-next
    # sandbox->data = new-line
    copy-handle new-line-h, sandbox-slot
    # clear partial-name-for-cursor-word
    var empty: (handle word)
    copy-handle empty, new-name-ah
#?     # XXX
#?     var cursor-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
#?     var cursor/eax: (addr call-path-element) <- lookup *cursor-ah
#?     var word-at-cursor-ah/eax: (addr handle word) <- get cursor, word
#?     print-string 0, "cursor after rename: "
#?     {
#?       var cursor-word/eax: (addr word) <- lookup *word-at-cursor-ah
#?       print-word 0, cursor-word
#?       print-string 0, " -- "
#?       var foo/eax: int <- copy cursor-word
#?       print-int32-hex 0, foo
#?       print-string 0, "\n"
#?     }
    break $process-sandbox-rename:body
  }
  #
  compare key, 0x7f  # del (backspace on Macs)
  $process-sandbox-rename:backspace: {
    break-if-!=
    # if not at start, delete grapheme before cursor
    var new-name/eax: (addr word) <- lookup *new-name-ah
    var at-start?/eax: boolean <- cursor-at-start? new-name
    compare at-start?, 0  # false
    {
      break-if-!=
      var new-name/eax: (addr word) <- lookup *new-name-ah
      delete-before-cursor new-name
    }
    break $process-sandbox-rename:body
  }
  # otherwise insert key within current word
  var print?/eax: boolean <- real-grapheme? key
  $process-sandbox-rename:real-grapheme: {
    compare print?, 0  # false
    break-if-=
    var new-name/eax: (addr word) <- lookup *new-name-ah
    add-grapheme-to-word new-name, key
    break $process-sandbox-rename:body
  }
  # silently ignore other hotkeys
}
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

#############
# Visualize
#############

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
#?   print-string 0, "==\n"
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
  # bindings
  var bindings-storage: table
  var bindings/ebx: (addr table) <- address bindings-storage
  initialize-table bindings, 0x10
  render-sandbox screen, functions, bindings, sandbox, 3, repl-col
}

fn render-sandbox screen: (addr screen), functions: (addr handle function), bindings: (addr table), _sandbox: (addr sandbox), top-row: int, left-col: int {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  # line
  var curr-line-ah/eax: (addr handle line) <- get sandbox, data
  var _curr-line/eax: (addr line) <- lookup *curr-line-ah
  var curr-line/ecx: (addr line) <- copy _curr-line
  #
  var curr-row/edx: int <- copy top-row
  # cursor row, col
  var cursor-row: int
  var cursor-row-addr: (addr int)
  var tmp/eax: (addr int) <- address cursor-row
  copy-to cursor-row-addr, tmp
  var cursor-col: int
  var cursor-col-addr: (addr int)
  tmp <- address cursor-col
  copy-to cursor-col-addr, tmp
  # render all but final line without stack
#?   print-string 0, "render all but final line\n"
  {
    var next-line-ah/eax: (addr handle line) <- get curr-line, next
    var next-line/eax: (addr line) <- lookup *next-line-ah
    compare next-line, 0
    break-if-=
    {
      var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
      var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
      var cursor-word-ah/eax: (addr handle word) <- get cursor-call-path, word
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
#?       print-string 0, "cursor 2: "
#?       {
#?         print-word 0, cursor-word
#?         print-string 0, " -- "
#?         var foo/eax: int <- copy cursor-word
#?         print-int32-hex 0, foo
#?         print-string 0, "\n"
#?       }
      # it's enough to pass in the first word of the path, because if the path isn't a singleton the word is guaranteed to be unique
      render-line-without-stack screen, curr-line, curr-row, left-col, cursor-word, cursor-row-addr, cursor-col-addr
    }
    curr-line <- copy next-line
    curr-row <- increment
    loop
  }
  #
#?   print-string 0, "render final line\n"
  render-final-line-with-stack screen, functions, bindings, sandbox, curr-row, left-col, cursor-row-addr, cursor-col-addr
  render-rename-dialog screen, sandbox, cursor-row, cursor-col
  move-cursor screen, cursor-row, cursor-col
}

fn render-final-line-with-stack screen: (addr screen), functions: (addr handle function), bindings: (addr table), _sandbox: (addr sandbox), top-row: int, left-col: int, cursor-row-addr: (addr int), cursor-col-addr: (addr int) {
  var sandbox/esi: (addr sandbox) <- copy _sandbox
  # expanded-words
  var expanded-words/edi: (addr handle call-path) <- get sandbox, expanded-words
  # cursor-word
  var cursor-call-path-ah/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
  var cursor-call-path/eax: (addr call-path-element) <- lookup *cursor-call-path-ah
  var cursor-word-ah/eax: (addr handle word) <- get cursor-call-path, word
  var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
  var cursor-word/ebx: (addr word) <- copy _cursor-word
  # cursor-call-path
  var cursor-call-path: (addr handle call-path-element)
  {
    var src/eax: (addr handle call-path-element) <- get sandbox, cursor-call-path
    copy-to cursor-call-path, src
  }
  # final line
  var line-ah/eax: (addr handle line) <- get sandbox, data
  var curr-line/eax: (addr line) <- lookup *line-ah
  var first-line/edx: (addr line) <- copy curr-line
  $render-final-line-with-stack:line-loop: {
    var next-line-ah/ecx: (addr handle line) <- get curr-line, next
    {
      var next-line/eax: (addr line) <- lookup *next-line-ah
      compare next-line, 0
      break-if-= $render-final-line-with-stack:line-loop
    }
#?     print-string 0, "skipping line\n"
    curr-line <- lookup *next-line-ah
    loop
  }
  # curr-path
  var curr-path-storage: (handle call-path-element)
  var curr-path/ecx: (addr handle call-path-element) <- address curr-path-storage
  allocate curr-path  # leak
  initialize-path-from-line curr-line, curr-path
  #
  var dummy/ecx: int <- render-line screen, functions, bindings, first-line, curr-line, expanded-words, top-row, left-col, curr-path, cursor-word, cursor-call-path, cursor-row-addr, cursor-col-addr
}

fn render-rename-dialog screen: (addr screen), _sandbox: (addr sandbox), cursor-row: int, cursor-col: int {
  var sandbox/edi: (addr sandbox) <- copy _sandbox
  var rename-word-mode-ah?/ecx: (addr handle word) <- get sandbox, partial-name-for-cursor-word
  var rename-word-mode?/eax: (addr word) <- lookup *rename-word-mode-ah?
  compare rename-word-mode?, 0
  break-if-=
  # clear a space for the dialog
  var top-row/eax: int <- copy cursor-row
  top-row <- subtract 3
  var bottom-row/ecx: int <- copy cursor-row
  bottom-row <- add 3
  var left-col/edx: int <- copy cursor-col
  left-col <- subtract 0x10
  var right-col/ebx: int <- copy cursor-col
  right-col <- add 0x10
  clear-rect screen, top-row, left-col, bottom-row, right-col
  draw-box screen, top-row, left-col, bottom-row, right-col
  # render a little menu for the dialog
  var menu-row/ecx: int <- copy bottom-row
  menu-row <- decrement
  var menu-col/edx: int <- copy left-col
  menu-col <- add 2
  move-cursor screen, menu-row, menu-col
  start-reverse-video screen
  print-string screen, " esc "
  reset-formatting screen
  print-string screen, " cancel  "
  start-reverse-video screen
  print-string screen, " enter "
  reset-formatting screen
  print-string screen, " rename  "
  # draw the word, positioned appropriately around the cursor
  var start-col/ecx: int <- copy cursor-col
  var word-ah?/edx: (addr handle word) <- get sandbox, partial-name-for-cursor-word
  var word/eax: (addr word) <- lookup *word-ah?
  var cursor-index/eax: int <- cursor-index word
  start-col <- subtract cursor-index
  move-cursor screen, cursor-row, start-col
  var word/eax: (addr word) <- lookup *word-ah?
  print-word screen, word
}

# Render just the words in 'line'.
fn render-line-without-stack screen: (addr screen), _line: (addr line), curr-row: int, left-col: int, cursor-word: (addr word), cursor-row-addr: (addr int), cursor-col-addr: (addr int) {
  # curr-word
  var line/eax: (addr line) <- copy _line
  var first-word-ah/eax: (addr handle word) <- get line, data
  var _curr-word/eax: (addr word) <- lookup *first-word-ah
  var curr-word/esi: (addr word) <- copy _curr-word
  #
  # loop-carried dependency
  var curr-col/ecx: int <- copy left-col
  #
  {
    compare curr-word, 0
    break-if-=
#?     print-string 0, "-- word in penultimate lines: "
#?     {
#?       var foo/eax: int <- copy curr-word
#?       print-int32-hex 0, foo
#?     }
#?     print-string 0, "\n"
    var old-col/edx: int <- copy curr-col
    reset-formatting screen
    move-cursor screen, curr-row, curr-col
    print-word screen, curr-word
    {
      var max-width/eax: int <- word-length curr-word
      curr-col <- add max-width
      curr-col <- add 1  # margin-right
    }
    # cache cursor column if necessary
    {
      compare curr-word, cursor-word
      break-if-!=
#?       print-string 0, "Cursor at "
#?       print-int32-decimal 0, curr-row
#?       print-string 0, ", "
#?       print-int32-decimal 0, old-col
#?       print-string 0, "\n"
#?       print-string 0, "contents: "
#?       print-word 0, cursor-word
#?       print-string 0, "\n"
#?       {
#?         var foo/eax: int <- copy cursor-word
#?         print-int32-hex 0, foo
#?         print-string 0, "\n"
#?       }
      var dest/ecx: (addr int) <- copy cursor-row-addr
      var src/eax: int <- copy curr-row
      copy-to *dest, src
      dest <- copy cursor-col-addr
      copy-to *dest, old-col
      var cursor-index-in-word/eax: int <- cursor-index curr-word
      add-to *dest, cursor-index-in-word
    }
    # loop update
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    var _curr-word/eax: (addr word) <- lookup *next-word-ah
    curr-word <- copy _curr-word
    loop
  }
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
# Along the way, compute the column the cursor should be positioned at (cursor-col-addr).
fn render-line screen: (addr screen), functions: (addr handle function), bindings: (addr table), first-line: (addr line), _line: (addr line), expanded-words: (addr handle call-path), top-row: int, left-col: int, curr-path: (addr handle call-path-element), cursor-word: (addr word), cursor-call-path: (addr handle call-path-element), cursor-row-addr: (addr int), cursor-col-addr: (addr int) -> right-col/ecx: int {
#?   print-string 0, "--\n"
  # curr-word
  var line/esi: (addr line) <- copy _line
  var first-word-ah/eax: (addr handle word) <- get line, data
  var curr-word/eax: (addr word) <- lookup *first-word-ah
  var debug-row: int
  copy-to debug-row, 0x20
  #
  # loop-carried dependency
  var curr-col/ecx: int <- copy left-col
  #
  {
    compare curr-word, 0
    break-if-=
#?     print-string 0, "-- word in final line: "
#?     {
#?       var foo/eax: int <- copy curr-word
#?       print-int32-hex 0, foo
#?     }
#?     print-string 0, "\n"
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
        var callee-h: (handle function)
        var callee-ah/ecx: (addr handle function) <- address callee-h
        callee functions, curr-word, callee-ah
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
      var callee-body-first-word/edx: (addr handle word) <- get callee-body, data
      # - render subsidiary stack
      push-to-call-path-element curr-path, callee-body-first-word  # leak
      curr-col <- render-line screen, functions, callee-bindings, callee-body, callee-body, expanded-words, top-row, curr-col, curr-path, cursor-word, cursor-call-path, cursor-row-addr, cursor-col-addr
      drop-from-call-path-element curr-path
      #
      move-cursor screen, top-row, curr-col
      print-code-point screen, 0x21d7  # ⇗
      #
      curr-col <- add 2
      decrement top-row
    }
    # render main column
    var old-col/edx: int <- copy curr-col
#?     move-cursor 0, debug-row, 1
#?     increment debug-row
#?     print-string 0, "rendering column from "
#?     print-int32-decimal 0, curr-col
#?     print-string 0, "\n"
    curr-col <- render-column screen, functions, bindings, first-line, line, curr-word, top-row, curr-col
    # cache cursor column if necessary
    $render-line:cache-cursor-column: {
#?       print-string 0, "cache cursor? "
#?       {
#?         var foo/eax: int <- copy curr-word
#?         print-int32-hex 0, foo
#?       }
#?       print-string 0, "\n"
      {
        var found?/eax: boolean <- call-path-element-match? curr-path, cursor-call-path
        compare found?, 0  # false
        break-if-= $render-line:cache-cursor-column
      }
#?       print-string 0, "cursor at "
#?       print-int32-decimal 0, top-row
#?       print-string 0, ", "
#?       print-int32-decimal 0, old-col
#?       print-string 0, "\n"
      var dest/edi: (addr int) <- copy cursor-row-addr
      {
        var src/eax: int <- copy top-row
        copy-to *dest, src
      }
      dest <- copy cursor-col-addr
      copy-to *dest, old-col
      var cursor-index-in-word/eax: int <- cursor-index curr-word
      add-to *dest, cursor-index-in-word
    }
    # loop update
#?     print-string 0, "next word\n"
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
#?     {
#?       var foo/eax: int <- copy curr-word
#?       print-int32-hex 0, foo
#?       print-string 0, "\n"
#?     }
    increment-final-element curr-path
    loop
  }
  right-col <- copy curr-col
}

fn callee functions: (addr handle function), word: (addr word), out: (addr handle function) {
  var stream-storage: (stream byte 0x10)
  var stream/esi: (addr stream byte) <- address stream-storage
  emit-word word, stream
  find-function functions, stream, out
}

# Render:
#   - starting at top-row, left-col: final-word
#   - starting somewhere below at left-col: the stack result from interpreting first-world to final-word (inclusive)
#
# Return the farthest column written.
fn render-column screen: (addr screen), functions: (addr handle function), bindings: (addr table), first-line: (addr line), line: (addr line), final-word: (addr word), top-row: int, left-col: int -> right-col/ecx: int {
#?   print-string 0, "render-column\n"
  var max-width/esi: int <- copy 0
  {
    # indent stack
    var indented-col/ebx: int <- copy left-col
    indented-col <- add 1  # margin-right
    # compute stack
    var stack: value-stack
    var stack-addr/edi: (addr value-stack) <- address stack
    initialize-value-stack stack-addr, 0x10  # max-words
    evaluate functions, bindings, first-line, final-word, stack-addr
    # render stack
    var curr-row/edx: int <- copy top-row
    curr-row <- add 3  # stack-margin-top
    var _max-width/eax: int <- value-stack-max-width stack-addr
    max-width <- copy _max-width
    var i/eax: int <- value-stack-length stack-addr
    {
      compare i, 0
      break-if-<=
      move-cursor screen, curr-row, indented-col
      {
        var val/eax: int <- pop-int-from-value-stack stack-addr
#?         print-int32-decimal 0, val
#?         print-string 0, "\n"
        render-integer screen, val, max-width
      }
      curr-row <- increment
      i <- decrement
      loop
    }
  }

  max-width <- add 2  # spaces on either side of items on the stack

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
  right-col <- copy left-col
  right-col <- add max-width
  right-col <- add 1  # margin-right
#?   print-int32-decimal 0, left-col
#?   print-string 0, " => "
#?   print-int32-decimal 0, right-col
#?   print-string 0, "\n"
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
  menu-start <- subtract 0x40  # 64 = half the size of the menu
  move-cursor screen, *nrows, menu-start
  start-reverse-video screen
  print-string screen, " ctrl-a "
  reset-formatting screen
  print-string screen, " ⏮   "
  start-reverse-video screen
  print-string screen, " ctrl-b "
  reset-formatting screen
  print-string screen, " ◀ word  "
  start-reverse-video screen
  print-string screen, " ctrl-f "
  reset-formatting screen
  print-string screen, " word ▶  "
  start-reverse-video screen
  print-string screen, " ctrl-e "
  reset-formatting screen
  print-string screen, " ⏭   "
  start-reverse-video screen
  print-string screen, " ctrl-u "
  reset-formatting screen
  print-string screen, " clear line  "
  start-reverse-video screen
  print-string screen, " ctrl-r "
  reset-formatting screen
  print-string screen, " rename word  "
  start-reverse-video screen
  print-string screen, " ctrl-d "
  reset-formatting screen
  print-string screen, " define function  "
  # currently defined functions
  move-cursor screen, 3, 2
  print-string screen, "x 2* = x 2 *"
  move-cursor screen, 4, 2
  print-string screen, "x 1+ = x 1 +"
  move-cursor screen, 5, 2
  print-string screen, "x 2+ = x 1+ 1+"
  move-cursor screen, 6, 2
  print-string screen, "x square = x x *"
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

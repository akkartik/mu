type environment {
  screen: (handle screen)
  cursor-word: (handle word)
}

fn initialize-environment _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  var cursor-word-ah/eax: (addr handle word) <- get env, cursor-word
  allocate cursor-word-ah
  var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
  initialize-word cursor-word
}

fn initialize-environment-with-fake-screen _self: (addr environment), nrows: int, ncols: int {
  var self/esi: (addr environment) <- copy _self
  var screen-ah/eax: (addr handle screen) <- get self, screen
  allocate screen-ah
  var screen-addr/eax: (addr screen) <- lookup *screen-ah
  initialize-screen screen-addr, nrows, ncols
  initialize-environment self
}

fn render-loop _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  # initial render
  {
    var screen-ah/edi: (addr handle screen) <- get self, screen
    var screen/eax: (addr screen) <- lookup *screen-ah
    move-cursor screen, 3, 3
  }
  #
  $interactive:loop: {
    var key/eax: grapheme <- read-key-from-real-keyboard
    compare key, 0x71  # 'q'
    break-if-=
    process self, key
    var max-depth/eax: int <- compute-max-depth self
    render self, max-depth
    loop
  }
}

fn process _self: (addr environment), key: grapheme {
$process:body: {
    var self/esi: (addr environment) <- copy _self
    compare key, 0x445b1b  # left-arrow
    {
      break-if-!=
      # TODO:
      #   gap-left cursor-word
      # or
      #   cursor-word = cursor-word->prev
      #   gap-to-end cursor-word
      break $process:body
    }
    compare key, 0x435b1b  # right-arrow
    {
      break-if-!=
      # TODO:
      #   gap-right cursor-word
      # or
      #   cursor-word = cursor-word->next
      #   gap-to-start cursor-word
      break $process:body
    }
    compare key, 0x20  # space
    {
      break-if-!=
      var cursor-word-ah/edx: (addr handle word) <- get self, cursor-word
      append-word cursor-word-ah
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      var next-word-ah/ecx: (addr handle word) <- get cursor-word, next
      copy-object next-word-ah, cursor-word-ah
      break $process:body
    }
    var g/edx: grapheme <- copy key
    var print?/eax: boolean <- real-grapheme? key
    {
      compare print?, 0  # false
      break-if-=
      var cursor-word-ah/eax: (addr handle word) <- get self, cursor-word
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      add-grapheme-to-word cursor-word, g
      break $process:body
    }
    # silently ignore other hotkeys
}
}

fn render _env: (addr environment), max-depth: int {
  var env/esi: (addr environment) <- copy _env
  var screen-ah/edi: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # prepare screen
  clear-screen screen
  move-cursor screen, 3, 3
  # cursor-word
  var cursor-word-ah/esi: (addr handle word) <- get env, cursor-word
  var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
  var cursor-word/ebx: (addr word) <- copy _cursor-word
  # curr-word
  var curr-word/eax: (addr word) <- first-word cursor-word
  # first-word
  var first-word: (addr word)
  copy-to first-word, curr-word
  # cursor-col
  var cursor-col: int
  var cursor-col-a: (addr int)
  var tmp/ecx: (addr int) <- address cursor-col
  copy-to cursor-col-a, tmp
  # curr-col
  var curr-col/ecx: int <- copy 3
  {
    compare curr-word, 0
    break-if-=
    move-cursor screen, 3, curr-col
    curr-col <- render-stack screen, first-word, curr-word, max-depth, curr-col, cursor-word, cursor-col-a
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    loop
  }
  move-cursor screen, 3, *cursor-col-a
}

# Render the stack result from interpreting first-world to final-word (inclusive)
# with the bottom-left corner at botleft-row, botleft-col.
#
# Outputs:
# - Return the farthest column written.
# - If final-word is same as cursor-word, do some additional computation to set
#   cursor-col-a.
fn render-stack screen: (addr screen), first-word: (addr word), final-word: (addr word), botleft-row: int, botleft-col: int, cursor-word: (addr word), cursor-col-a: (addr int) -> right-col/ecx: int {
  var curr/eax: (addr word) <- copy first-word
  {
    print-word screen, curr
    compare curr, final-word
    break-if-=
    print-string screen " "
    var next/ecx: (addr handle word) <- get curr, next
    curr <- lookup *next
    loop
  }
}

# We could be a little faster by not using 'first-word' (since max is commutative),
# but this way the code follows the pattern of 'render'. Let's see if that's a net win.
fn compute-max-depth _env: (addr environment) -> result/eax: int {
  var env/esi: (addr environment) <- copy _env
  # cursor-word
  var cursor-word-ah/esi: (addr handle word) <- get env, cursor-word
  var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
  # curr-word
  var curr-word/eax: (addr word) <- first-word cursor-word
  # first-word
  var first-word: (addr word)
  copy-to first-word, curr-word
  #
  var out/ebx: int <- copy 0
  {
    compare curr-word, 0
    break-if-=
    var curr-max-depth/edi: int <- max-stack-depth first-word, curr-word
    compare curr-max-depth, out
    {
      break-if-<=
      out <- copy curr-max-depth
    }
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    loop
  }
  result <- copy out
}

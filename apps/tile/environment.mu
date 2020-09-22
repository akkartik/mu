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
    move-cursor screen, 3, 3  # input-row, input-col
  }
  #
  $interactive:loop: {
    var key/eax: grapheme <- read-key-from-real-keyboard
    compare key, 0x71  # 'q'
    break-if-=
    process self, key
    render self
    loop
  }
}

fn process _self: (addr environment), key: grapheme {
$process:body: {
    var self/esi: (addr environment) <- copy _self
    compare key, 0x445b1b  # left-arrow
    {
      break-if-!=
      var cursor-word-ah/edi: (addr handle word) <- get self, cursor-word
      var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      var cursor-word/ecx: (addr word) <- copy _cursor-word
      # if not at start, move left within current word
      var at-start?/eax: boolean <- cursor-at-start? cursor-word
      compare at-start?, 0  # false
      {
        break-if-=
        cursor-left cursor-word
        break $process:body
      }
      # otherwise, move to end of prev word
      var prev-word-ah/esi: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      {
        compare prev-word, 0
        break-if-=
        copy-object prev-word-ah, cursor-word-ah
        cursor-to-end prev-word
      }
      break $process:body
    }
    compare key, 0x435b1b  # right-arrow
    {
      break-if-!=
      var cursor-word-ah/edi: (addr handle word) <- get self, cursor-word
      var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      var cursor-word/ecx: (addr word) <- copy _cursor-word
      # if not at end, move right within current word
      var at-end?/eax: boolean <- cursor-at-end? cursor-word
      compare at-end?, 0  # false
      {
        break-if-=
        cursor-right cursor-word
        break $process:body
      }
      # otherwise, move to start of next word
      var next-word-ah/esi: (addr handle word) <- get cursor-word, next
      var next-word/eax: (addr word) <- lookup *next-word-ah
      {
        compare next-word, 0
        break-if-=
        copy-object next-word-ah, cursor-word-ah
        cursor-to-start next-word
      }
      break $process:body
    }
    compare key, 0x7f  # del (backspace on Macs)
    {
      break-if-!=
      var cursor-word-ah/edi: (addr handle word) <- get self, cursor-word
      var _cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      var cursor-word/ecx: (addr word) <- copy _cursor-word
      # if not at start of some word, delete grapheme before cursor within current word
      var at-start?/eax: boolean <- cursor-at-start? cursor-word
      compare at-start?, 0  # false
      {
        break-if-=
        delete-before-cursor cursor-word
        break $process:body
      }
      # otherwise delete current word and move to end of prev word
      var prev-word-ah/esi: (addr handle word) <- get cursor-word, prev
      var prev-word/eax: (addr word) <- lookup *prev-word-ah
      {
        compare prev-word, 0
        break-if-=
        copy-object prev-word-ah, cursor-word-ah
        cursor-to-end prev-word
        delete-next prev-word
      }
      break $process:body
    }
    compare key, 0x20  # space
    {
      break-if-!=
      # insert new word
      var cursor-word-ah/edx: (addr handle word) <- get self, cursor-word
      append-word cursor-word-ah
      var cursor-word/eax: (addr word) <- lookup *cursor-word-ah
      var next-word-ah/ecx: (addr handle word) <- get cursor-word, next
      copy-object next-word-ah, cursor-word-ah
      break $process:body
    }
    # otherwise insert key within current word
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

fn render _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  var screen-ah/edi: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  # prepare screen
  clear-screen screen
  move-cursor screen, 5, 1  # input-row+stack-margin-top
  print-string screen, "stack:"
  move-cursor screen, 3, 3  # input-row, input-col
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
  var curr-col/ecx: int <- copy 3  # input-col
  {
    compare curr-word, 0
    break-if-=
    move-cursor screen, 3, curr-col  # input-row
    curr-col <- render-column screen, first-word, curr-word, curr-col, cursor-word, cursor-col-a
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    loop
  }
  var col/eax: (addr int) <- copy cursor-col-a
  move-cursor screen, 3, *col  # input-row
}

# Render:
#   - final-word
#   - the stack result from interpreting first-world to final-word (inclusive)
#     - unless final-word is truly the final word, in which case it might be incomplete
#
# Outputs:
# - Return the farthest column written.
# - If final-word is same as cursor-word, do some additional computation to set
#   cursor-col-a.
fn render-column screen: (addr screen), first-word: (addr word), final-word: (addr word), left-col: int, cursor-word: (addr word), cursor-col-a: (addr int) -> right-col/ecx: int {
  var max-width/ecx: int <- copy 0
  {
    # render stack for all but final column
    var curr/eax: (addr word) <- copy final-word
    var next-ah/eax: (addr handle word) <- get curr, next
    var next/eax: (addr word) <- lookup *next-ah
    compare next, 0
    break-if-=
    # indent stack
    var indented-col/ebx: int <- copy left-col
    indented-col <- add 1
    # compute stack
    var stack: int-stack
    var stack-addr/edi: (addr int-stack) <- address stack
    initialize-int-stack stack-addr, 0x10  # max-words
    evaluate first-word, final-word, stack-addr
    # render stack
    var curr-row/edx: int <- copy 6  # input-row 3 + stack-margin-top 3
    var i/eax: int <- int-stack-length stack-addr
    {
      compare i, 0
      break-if-<=
      move-cursor screen, curr-row, indented-col
      {
        var val/eax: int <- pop-int-stack stack-addr
        render-integer screen, val
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
  move-cursor screen, 3, left-col  # input-row
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
fn render-integer screen: (addr screen), val: int {
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
  print-int32-decimal screen, val
  print-grapheme screen, 0x20  # space
}

fn hash-color val: int -> result/eax: int {
  result <- try-modulo val, 7  # assumes that 7 is always the background color
}

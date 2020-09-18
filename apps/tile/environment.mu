type environment {
  screen: (handle screen)
  buf: gap-buffer
  cursor-row: int
  cursor-col: int
}

fn initialize-environment _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  var screen-ah/edi: (addr handle screen) <- get env, screen
  var _screen/eax: (addr screen) <- lookup *screen-ah
  var screen/edi: (addr screen) <- copy _screen
  {
    var cursor-col/eax: (addr int) <- get env, cursor-col
    copy-to *cursor-col, 3
  }
  {
    var cursor-row/eax: (addr int) <- get env, cursor-row
    copy-to *cursor-row, 3
  }
  # buf
  var gap/eax: (addr gap-buffer) <- get env, buf
  initialize-gap-buffer gap
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
  render self
  #
  $interactive:loop: {
    var key/eax: grapheme <- read-key-from-real-keyboard
    compare key, 0x71  # 'q'
    break-if-=
    process self, key
    loop
  }
}

fn process _self: (addr environment), key: grapheme {
$process:body: {
    var self/esi: (addr environment) <- copy _self
    var screen-ah/edi: (addr handle screen) <- get self, screen
    var _screen/eax: (addr screen) <- lookup *screen-ah
    var screen/edi: (addr screen) <- copy _screen
    var buf/ebx: (addr gap-buffer) <- get self, buf
    compare key, 0x445b1b  # left-arrow
    {
      break-if-!=
      var char-skipped/eax: grapheme <- gap-left buf
      compare char-skipped, -1
      {
        break-if-=
        var cursor-row/eax: (addr int) <- get self, cursor-row
        var cursor-col/ecx: (addr int) <- get self, cursor-col
        decrement *cursor-col
        move-cursor screen, *cursor-row, *cursor-col
      }
      break $process:body
    }
    compare key, 0x435b1b  # right-arrow
    {
      break-if-!=
      var char-skipped/eax: grapheme <- gap-right buf
      compare char-skipped, -1
      {
        break-if-=
        var cursor-row/eax: (addr int) <- get self, cursor-row
        var cursor-col/ecx: (addr int) <- get self, cursor-col
        increment *cursor-col
        move-cursor screen, *cursor-row, *cursor-col
      }
      break $process:body
    }
    var g/ecx: grapheme <- copy key
    var print?/eax: boolean <- real-grapheme? key
    {
      compare print?, 0  # false
      break-if-=
      add-grapheme-at-gap buf, g
      var cursor-col/eax: (addr int) <- get self, cursor-col
      increment *cursor-col
      render self
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
  move-cursor screen, 3, 3
  # render input area
  var buf/ecx: (addr gap-buffer) <- get env, buf
  render-gap-buffer screen, buf
#?   # render stacks
#?   render-all-stacks screen
  # update cursor
  var cursor-row/eax: (addr int) <- get env, cursor-row
  var cursor-col/ecx: (addr int) <- get env, cursor-col
  move-cursor screen, *cursor-row, *cursor-col
}

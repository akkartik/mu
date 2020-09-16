fn main args-on-stack: (addr array addr array byte) -> exit-status/ebx: int {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
  var len/ecx: int <- length args
  $main-body: {
    # if no args, run in interactive mode
    compare len, 1
    {
      break-if->
      exit-status <- interactive args-on-stack
      break $main-body
    }
    # else if single arg is 'test', run tests
    compare len, 2
    {
      break-if-!=
      var tmp/ecx: (addr addr array byte) <- index args, 1
      var tmp2/eax: boolean <- string-equal? *tmp, "test"
      compare tmp2, 0
      {
        break-if-=
        run-tests
        exit-status <- copy 0  # TODO: get at Num-test-failures somehow
        break $main-body
      }
    }
    # otherwise error message
    print-string-to-real-screen "usage: tile\n"
    print-string-to-real-screen "    or tile test\n"
    exit-status <- copy 1
  }
}

fn interactive args: (addr array addr array byte) -> exit-status/ebx: int {
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  var buf-storage: gap-buffer
  var buf/esi: (addr gap-buffer) <- address buf-storage
  initialize-gap-buffer buf
  #
  {
    render 0, buf
    var key/eax: byte <- read-key-from-real-keyboard
    compare key, 0x71  # 'q'
    break-if-=
    var g/ecx: grapheme <- copy key
    add-grapheme buf, g
    loop
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

fn render screen: (addr screen), buf: (addr gap-buffer) {
  clear-screen screen
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size screen
  var midcol/edx: int <- copy ncols
  midcol <- shift-right 1
  draw-vertical-line screen, 1, nrows, midcol
  var midrow/ebx: int <- copy 0
  {
    var tmp/eax: int <- try-divide nrows, 3
    midrow <- copy tmp
  }
  var left-col/edx: int <- copy midcol
  left-col <- increment
  draw-horizontal-line screen, midrow, left-col, ncols
  # initialize cursor
  var start-row/ebx: int <- copy midrow
  start-row <- subtract 3
  var start-col/edx: int <- copy left-col
  start-col <- increment
  move-cursor screen, start-row, start-col
  #
  render-gap-buffer screen, buf
  flush-stdout
}

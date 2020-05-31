# Render text with word-wrap.
#
# To run:
#   $ ./translate_mu apps/browse.mu
#   $ ./a.elf __text_file__
#
# Press 'q' to quit. All other keys scroll down.

fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var filename/eax: (addr array byte) <- first-arg args
  var file/esi: (addr buffered-file) <- load-file filename
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  var display-state-storage: display-state
  var display-state: (addr display-state) = address display-state-storage
  init-display-state display-state, nrows, ncols
  {
    render file, display-state
    var key/eax: byte <- read-key
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

type display-state {
  nrows: int  # const
  ncols: int  # const
  toprow: int
  botrow: int
  leftcol: int
  rightcol: int
  row: int
  col: int
}

fn render in: (addr buffered-file), state: (addr display-state) {
  start-drawing state
  render-normal in, state
}

fn render-normal in: (addr buffered-file), state: (addr display-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') start-bold, render-until-asterisk(in, state), reset
    # else if (c == '_') start-bold, render-until-underscore(in, state), reset
    # else if (c == '#') compute-color, start color, render-header-line(in, state), reset
    # else add-char(state, c)
  }
}

fn render-until-asterisk in: (addr buffered-file), state: (addr display-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    # else add-char(state, c)
  }
}

fn render-until-underscore in: (addr buffered-file), state: (addr display-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '_') break
    # else add-char(state, c)
  }
}

fn render-header-line in: (addr buffered-file), state: (addr display-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0
    break-if-!=
    #
    var c/eax: byte <- read-byte-buffered in
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    # else add-char(state, c)
  }
}

fn init-display-state self: (addr display-state), nrows: int, ncols: int {
  # hardcoded parameters:
  #   top-margin
  #   page-margin
  #   text-width
  var dest/eax: (addr int) <- copy 0
  # self->nrows = nrows
  # self->ncols = ncols
  # self->toprow = top-margin
  # self->botrow = nrows
  # self->leftcol = page-margin
  # self->rightcol = self->leftcol + text-width
  # start-drawing(self)
}

fn start-drawing self: (addr display-state) {
  # self->row = toprow
  # self->col = leftcol
}

fn add-char self: (addr display-state), c: byte {
  # print c
  # self->col++
  # if (self->col > self->rightcol) next-line(self)
}

fn next-line self: (addr display-state) {
  # self->row++
  # if (self->row > self->botrow) next-page(self)
}

fn next-page self: (addr display-state) {
  # self->leftcol = self->rightcol + 5
  # self->rightcol = self->leftcol + text-width
}

fn done-drawing? self: (addr display-state) -> result/eax: boolean {
  # self->rightcol >= self->ncols
}

# screen manipulation:
#   properties: width, height
#   reset attributes
#   clear
#   color
#   bold
#   underline
#   print char

# pages:
#   properties: screen, row, col
# methods for new pages
#   new page
#   new line

# decide how to lay out pages on screen
fn render in: (addr buffered-file), nrows: int, ncols: int {
  # Fit multiple pages on screen on separate columns, each wide enough to read
  # comfortably.
  # Pages are separated horizontally by a 'page margin'. Among other reasons,
  # this allows the odd line to bleed out on the right if necessary.
  #
  # hardcoded parameters:
  #   top-margin
  #   page-margin
  #   text-width
  var toprow/eax: int <- copy 2  # top-margin
  var botrow/ecx: int <- copy nrows
  var leftcol/edx: int <- copy 5  # page-margin
  var rightcol/ebx: int <- copy leftcol
  rightcol <- add 0x40  # text-width = 64 characters
  start-color 0xec, 7  # 236 = darkish gray
  {
    compare rightcol, ncols
    break-if->=
    clear toprow, leftcol, botrow, rightcol
    render-page in, toprow, leftcol, botrow, rightcol
    leftcol <- copy rightcol
    leftcol <- add 5  # page-margin
    rightcol <- copy leftcol
    rightcol <- add 0x40  # text-width
    loop
  }
}

fn render-page in: (addr buffered-file), toprow: int, leftcol: int, botrow: int, rightcol: int {
  var row/ecx: int <- copy toprow
$line-loop: {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor row, col
$char-loop: {
      compare col, rightcol
      break-if->=
      var c/eax: byte <- read-byte-buffered in
      compare c, 0xffffffff  # EOF marker
      break-if-= $line-loop
$change-state: {
        compare *state, 0  # normal
        {
          break-if-!=
          compare c, 0x2a  # '*'
          {
            break-if-!=
            # r->current-state == 0 && c == '*' => bold text
            start-bold
            copy-to *state, 1
            break $change-state
          }
          compare c, 0x5f  # '_'
          {
            break-if-!=
            # r->current-state == 0 && c == '_' => bold text
            start-bold
            copy-to *state, 1
            break $change-state
          }
          break $change-state
        }
        compare *state, 1  # bold
        {
          break-if-!=
          compare c, 0x2a  # '*'
          {
            break-if-!=
            # r->current-state == 1 && c == '*' => print c, then normal text
            print-byte c
            col <- increment
            reset-formatting
            start-color 0xec, 7  # 236 = darkish gray
            copy-to *state, 0
            loop $char-loop
          }
          compare c, 0x5f  # '_'
          {
            break-if-!=
            print-byte c
            col <- increment
            # r->current-state == 1 && c == '_' => print c, then normal text
            reset-formatting
            start-color 0xec, 7  # 236 = darkish gray
            copy-to *state, 0
            loop $char-loop
          }
          break $change-state
        }
      }
      compare c, 0xa  # newline
      break-if-=  # no need to print newlines
      print-byte c
      col <- increment
      loop
    }
    row <- increment
    loop
  }
}

fn clear toprow: int, leftcol: int, botrow: int, rightcol: int {
  var row/ecx: int <- copy toprow
  {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor row, col
    {
      compare col, rightcol
      break-if->=
      print-string " "
      col <- increment
      loop
    }
    row <- increment
    loop
  }
}

fn first-arg args-on-stack: (addr array (addr array byte)) -> out/eax: (addr array byte) {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

fn load-file filename: (addr array byte) -> out/esi: (addr buffered-file) {
  var result: (handle buffered-file)
  {
    var tmp1/eax: (addr handle buffered-file) <- address result
    open filename, 0, tmp1
  }
  var tmp2/eax: (addr buffered-file) <- lookup result
  out <- copy tmp2
}

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte c
  loop
}

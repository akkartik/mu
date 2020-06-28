# Render text with word-wrap.
#
# To run:
#   $ ./translate_mu apps/browse.mu
#   $ ./a.elf __text_file__
#
# Press 'q' to quit. All other keys scroll down.

fn main args-on-stack: (addr array (addr array byte)) -> exit-status/ebx: int {
  # var file/esi: (addr buffered-file) = open args-on-stack[1] for reading {{{
  var file/esi: (addr buffered-file) <- copy 0
  {
    var file-handle: (handle buffered-file)
    {
      var address-of-file-handle/esi: (addr handle buffered-file) <- address file-handle
      # var filename/ecx: (addr array byte) = args-on-stack[1] {{{
      var filename/ecx: (addr array byte) <- copy 0
      {
        var args/eax: (addr array (addr array byte)) <- copy args-on-stack
        var tmp/eax: (addr addr array byte) <- index args, 1
        filename <- copy *tmp
      }
      # }}}
      open filename, 0, address-of-file-handle
    }
    var tmp/eax: (addr buffered-file) <- lookup file-handle
    file <- copy tmp
  }
  # }}}
  enable-screen-grid-mode
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  enable-keyboard-immediate-mode
  {
    render file, nrows, ncols
    var key/eax: byte <- read-key
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

type render-state {
  current-state: int  # enum 0: normal, 1: bold
}

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
  #   page-width
  var _r: render-state
  var r/edi: (addr render-state) <- address _r
  var toprow/eax: int <- copy 2  # top-margin
  var botrow/ecx: int <- copy nrows
  var leftcol/edx: int <- copy 5  # page-margin
  var rightcol/ebx: int <- copy leftcol
  rightcol <- add 0x40  # page-width = 64 characters
  start-color 0xec, 7  # 236 = darkish gray
  {
    compare rightcol, ncols
    break-if->=
    render-page in, toprow, leftcol, botrow, rightcol, r
    leftcol <- copy rightcol
    leftcol <- add 5  # page-margin
    rightcol <- copy leftcol
    rightcol <- add 0x40  # page-width
    loop
  }
}

fn render-page in: (addr buffered-file), toprow: int, leftcol: int, botrow: int, rightcol: int, r: (addr render-state) {
  clear toprow, leftcol, botrow, rightcol
  # render screen rows
  var row/ecx: int <- copy toprow
$line-loop: {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor row, col
    {
      compare col, rightcol
      break-if->=
      var c/eax: byte <- read-byte-buffered in
      compare c, 0xffffffff  # EOF marker
      break-if-= $line-loop
      update-attributes c, r
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

fn update-attributes c: byte, _r: (addr render-state) {
  var r/edi: (addr render-state) <- copy _r
  var state/esi: (addr int) <- get r, current-state
$update-attributes:check-state: {
    compare *state, 0  # normal
    {
      break-if-!=
      compare c, 0x2a  # '*'
      {
        break-if-!=
        # r->current-state == 0 && c == '*'
        start-bold
        copy-to *state, 1
        break $update-attributes:check-state
      }
      compare c, 0x5f  # '_'
      {
        break-if-!=
        # r->current-state == 0 && c == '_'
        start-bold
        copy-to *state, 1
        break $update-attributes:check-state
      }
      break $update-attributes:check-state
    }
    {
      break-if-=
      compare c, 0x2a  # '*'
      {
        break-if-!=
        # r->current-state == 1 && c == '*'
        reset-formatting
        copy-to *state, 0
        break $update-attributes:check-state
      }
      compare c, 0x5f  # '_'
      {
        break-if-!=
        # r->current-state == 1 && c == '_'
        reset-formatting
        copy-to *state, 0
        break $update-attributes:check-state
      }
      break $update-attributes:check-state
    }
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

fn dump in: (addr buffered-file) {
  var c/eax: byte <- read-byte-buffered in
  compare c, 0xffffffff  # EOF marker
  break-if-=
  print-byte c
  loop
}
# The current organization doesn't really work for the next feature (section
# headings) so let's inline attribute-handling.

fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  var filename/eax: (addr array byte) <- first-arg args
  var file/esi: (addr buffered-file) <- load-file filename
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
  start-color-on-screen 0xec, 7  # 236 = darkish gray
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

fn render-page in: (addr buffered-file), toprow: int, leftcol: int, botrow: int, rightcol: int, _r: (addr render-state) {
  var r/edi: (addr render-state) <- copy _r
  var state/esi: (addr int) <- get r, current-state
  clear toprow, leftcol, botrow, rightcol
  var row/ecx: int <- copy toprow
$line-loop: {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor-on-screen row, col
$char-loop: {
      compare col, rightcol
      break-if->=
      var c/eax: byte <- read-byte-buffered in
      compare c, 0xffffffff  # EOF marker
      break-if-= $line-loop
$update-attributes:check-state: {
        compare *state, 0  # normal
        {
          break-if-!=
          compare c, 0x2a  # '*'
          {
            break-if-!=
            # r->current-state == 0 && c == '*' => bold text
            start-bold-on-screen
            copy-to *state, 1
            break $update-attributes:check-state
          }
          compare c, 0x5f  # '_'
          {
            break-if-!=
            # r->current-state == 0 && c == '_' => bold text
            start-bold-on-screen
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
            # r->current-state == 1 && c == '*' => normal text
            reset-formatting-on-screen
            start-color-on-screen 0xec, 7  # 236 = darkish gray
            copy-to *state, 0
            break $update-attributes:check-state
          }
          compare c, 0x5f  # '_'
          {
            break-if-!=
            # r->current-state == 1 && c == '_' => normal text
            reset-formatting-on-screen
            start-color-on-screen 0xec, 7  # 236 = darkish gray
            copy-to *state, 0
            break $update-attributes:check-state
          }
          break $update-attributes:check-state
        }
      }  # $change-state
      compare c, 0xa  # newline
      break-if-=  # no need to print newlines
      # print c
      print-byte-to-screen c
      col <- increment
      loop
    }  # $char-loop
    row <- increment
    loop
  }  # $line-loop
}

fn clear toprow: int, leftcol: int, botrow: int, rightcol: int {
  var row/ecx: int <- copy toprow
  {
    compare row, botrow
    break-if->=
    var col/edx: int <- copy leftcol
    move-cursor-on-screen row, col
    {
      compare col, rightcol
      break-if->=
      print-string-to-screen " "
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
  print-byte-to-screen c
  loop
}

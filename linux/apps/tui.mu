# Test some primitives for text-mode.
#
# To run:
#   $ ./translate apps/tui.mu
#   $ ./a.elf

fn main -> _/ebx: int {
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size 0
  enable-screen-grid-mode
  move-cursor 0/screen, 5/row, 0x22/col
  start-color 0/screen, 1/fg, 0x7a/bg
  start-blinking 0/screen
  print-string 0/screen, "Hello world!"
  reset-formatting 0/screen
  move-cursor 0/screen, 6/row, 0x22/col
  print-string 0/screen, "tty dimensions: "
  print-int32-hex 0/screen, nrows
  print-string 0/screen, " rows, "
  print-int32-hex 0/screen, ncols
  print-string 0/screen, " rows\n"

  print-string 0/screen, "press a key to see its code: "
  enable-keyboard-immediate-mode
  var x/eax: grapheme <- read-key-from-real-keyboard
  enable-keyboard-type-mode
  enable-screen-type-mode
  print-string 0/screen, "You pressed "
  var x-int/eax: int <- copy x
  print-int32-hex 0/screen, x-int
  print-string 0/screen, "\n"
  return 0
}

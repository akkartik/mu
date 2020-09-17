# Test some primitives for text-mode.
#
# To run:
#   $ ./translate_mu apps/tui.mu
#   $ ./a.elf

fn main -> exit-status/ebx: int {
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size 0
  enable-screen-grid-mode
  move-cursor 0, 5, 0x22
  start-color 0, 1, 0x7a
  start-blinking 0
  print-string 0, "Hello world!"
  reset-formatting 0
  move-cursor 0, 6, 0x22
  print-string 0, "tty dimensions: "
  print-int32-hex 0, nrows
  print-string 0, " rows, "
  print-int32-hex 0, ncols
  print-string 0, " rows\n"

  print-string 0, "press a key to see its code: "
  enable-keyboard-immediate-mode
  var x/eax: grapheme <- read-key-from-real-keyboard
  enable-keyboard-type-mode
  enable-screen-type-mode
  print-string 0, "You pressed "
  var x-int/eax: int <- copy x
  print-int32-hex 0, x-int
  print-string 0, "\n"
  exit-status <- copy 0
}

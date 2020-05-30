# Test some primitives for text-mode.
#
# To run:
#   $ ./translate_mu apps/tui.mu
#   $ ./a.elf

fn main -> exit-status/ebx: int {
  var nrows/eax: int <- copy 0
  var ncols/ecx: int <- copy 0
  nrows, ncols <- screen-size
  enable-screen-grid-mode
  move-cursor 5, 35
  start-color 1, 0x7a
  start-blinking
  print-string "Hello world!"
  reset-formatting
  move-cursor 6, 35
  print-string "tty dimensions: "
  print-int32-to-screen nrows
  print-string " rows, "
  print-int32-to-screen ncols
  print-string " rows\n"

  print-string "press a key to see its code: "
  enable-keyboard-immediate-mode
  var x/eax: byte <- read-key
  enable-keyboard-type-mode
  enable-screen-type-mode
  print-string "You pressed "
  print-int32-to-screen x
  print-string "\n"
  exit-status <- copy 0
}

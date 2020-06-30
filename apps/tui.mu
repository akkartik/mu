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
  move-cursor-on-screen 5, 35
  start-color-on-screen 1, 0x7a
  start-blinking-on-screen
  print-string-to-screen "Hello world!"
  reset-formatting-on-screen
  move-cursor-on-screen 6, 35
  print-string-to-screen "tty dimensions: "
  print-int32-hex-to-screen nrows
  print-string-to-screen " rows, "
  print-int32-hex-to-screen ncols
  print-string-to-screen " rows\n"

  print-string-to-screen "press a key to see its code: "
  enable-keyboard-immediate-mode
  var x/eax: byte <- read-key
  enable-keyboard-type-mode
  enable-screen-type-mode
  print-string-to-screen "You pressed "
  print-int32-hex-to-screen x
  print-string-to-screen "\n"
  exit-status <- copy 0
}

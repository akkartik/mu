# little example program: animate a line in text-mode
#
# To run (on Linux and x86):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate_mu prototypes/tile/1.mu
#   $ ./a.elf
# You should see a line drawn on a blank screen. Press a key. You should see
# the line seem to fall down the screen. Press a second key to quit.
# https://archive.org/details/akkartik-2min-2020-07-01

fn main -> exit-status/ebx: int {
  clear-screen 0
  move-cursor 0, 5, 5
  print-string 0, "_________"
  enable-keyboard-immediate-mode
  var dummy/eax: grapheme <- read-key-from-real-keyboard
  var row/eax: int <- copy 5
  {
    compare row, 0xe  # 15
    break-if-=
    animate row
    row <- increment
    sleep 0 0x5f5e100  # 100ms
    loop
  }
  var dummy/eax: grapheme <- read-key-from-real-keyboard
  enable-keyboard-type-mode
  clear-screen 0
  exit-status <- copy 0
}

fn animate row: int {
  var col/eax: int <- copy 5
  {
    compare col, 0xe
    break-if-=
    move-cursor 0, row, col
    print-string 0, " "
    increment row
    move-cursor 0, row, col
    print-string 0, "_"
    decrement row
    col <- increment
    loop
  }
}

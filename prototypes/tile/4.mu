# animate a large box
#
# To run (on Linux and x86):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate_mu prototypes/tile/4.mu
#   $ ./a.elf

fn main -> exit-status/ebx: int {
  clear-screen
  enable-keyboard-immediate-mode
  var dummy/eax: byte <- read-key
  draw-box 5, 5, 0x23, 0x23  # 35, 35
  sleep 0 0x5f5e100  # 100ms
  sleep 0 0x5f5e100  # 100ms
  draw-box 5, 5, 0x23, 0x69  # 35, 105
  sleep 0 0x5f5e100  # 100ms
  sleep 0 0x5f5e100  # 100ms
  draw-box 5, 5, 0x23, 0xaf  # 35, 175
  var dummy/eax: byte <- read-key
  enable-keyboard-type-mode
  clear-screen
  exit-status <- copy 0
}

fn draw-box row1: int, col1: int, row2: int, col2: int {
  clear-screen
  draw-horizontal-line row1, col1, col2
  draw-vertical-line row1, row2, col1
  draw-horizontal-line row2, col1, col2
  draw-vertical-line row1, row2, col2
}

fn draw-horizontal-line row: int, col1: int, col2: int {
  var col/eax: int <- copy col1
  move-cursor-on-screen row, col
  {
    compare col, col2
    break-if->=
    print-string-to-screen "-"
    col <- increment
    loop
  }
}

fn draw-vertical-line row1: int, row2: int, col: int {
  var row/eax: int <- copy row1
  {
    compare row, row2
    break-if->=
    move-cursor-on-screen row, col
    print-string-to-screen "|"
    row <- increment
    loop
  }
}

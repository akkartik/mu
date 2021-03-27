# Cursor-based motions.
#
# To build a disk image:
#   ./translate ex7.mu             # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f bochsrc               # bochsrc loads disk.img
#
# Expected output: an interactive game a bit like "snakes". Try pressing h, j,
# k, l.

fn main screen: (addr screen), keyboard: (addr keyboard) {
  var space/eax: grapheme <- copy 0x20
  set-cursor-position screen, 0, 0
  {
    draw-cursor screen, space
    var key/eax: byte <- read-key keyboard
    {
      compare key, 0x68/h
      break-if-!=
      draw-code-point-at-cursor screen, 0x2d/dash, 0x31/fg, 0/bg
      move-cursor-left 0
    }
    {
      compare key, 0x6a/j
      break-if-!=
      draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x31/fg, 0/bg
      move-cursor-down 0
    }
    {
      compare key, 0x6b/k
      break-if-!=
      draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x31/fg, 0/bg
      move-cursor-up 0
    }
    {
      compare key, 0x6c/l
      break-if-!=
      var g/eax: code-point <- copy 0x2d/dash
      draw-code-point-at-cursor screen, 0x2d/dash, 0x31/fg, 0/bg
      move-cursor-right 0
    }
    loop
  }
}

# Cursor-based motions.
#
# To build a disk image:
#   ./translate apps/ex7.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img
#
# Expected output: an interactive game a bit like "snakes". Try pressing h, j,
# k, l.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  set-cursor-position screen, 0, 0
  {
    draw-cursor screen, 0x20/space
    var key/eax: byte <- read-key keyboard
    {
      compare key, 0x80/left-arrow
      break-if-!=
      draw-code-point-at-cursor screen, 0x2d/dash, 0x31/fg, 0/bg
      move-cursor-left 0
    }
    {
      compare key, 0x81/down-arrow
      break-if-!=
      draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x31/fg, 0/bg
      move-cursor-down 0
    }
    {
      compare key, 0x82/up-arrow
      break-if-!=
      draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x31/fg, 0/bg
      move-cursor-up 0
    }
    {
      compare key, 0x83/right-arrow
      break-if-!=
      var g/eax: code-point <- copy 0x2d/dash
      draw-code-point-at-cursor screen, 0x2d/dash, 0x31/fg, 0/bg
      move-cursor-right 0
    }
    loop
  }
}

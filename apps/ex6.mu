# Drawing ASCII text incrementally.
#
# To build a disk image:
#   ./translate apps/ex6.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img
# Or:
#   bochs -f bochsrc               # bochsrc loads code.img
#
# Expected output: a box and text that doesn't overflow it

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # drawing text within a bounding box
  draw-box-on-real-screen 0xf, 0x1f, 0x79, 0x51, 0x4
  var x/eax: int <- copy 0x20
  var y/ecx: int <- copy 0x20
  x, y <- draw-text-wrapping-right-then-down screen, "hello ",     0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/fg, 0/bg
  x, y <- draw-text-wrapping-right-then-down screen, "from ",      0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/fg, 0/bg
  x, y <- draw-text-wrapping-right-then-down screen, "baremetal ", 0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/fg, 0/bg
  x, y <- draw-text-wrapping-right-then-down screen, "Mu!",        0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/fg, 0/bg

  # drawing at the cursor in multiple directions
  draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen, "abc", 0xa/fg, 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "def", 0xa/fg, 0/bg

  # test drawing near the edge
  x <- draw-text-rightward screen, "R", 0x7f/x, 0x80/xmax=screen-width, 0x18/y, 0xa/fg, 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "wrapped from R", 0xa/fg, 0/bg

  x <- draw-text-downward screen, "D", 0x20/x, 0x2f/y, 0x30/ymax=screen-height, 0xa/fg, 0/bg
  draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen, "wrapped from D", 0xa/fg, 0/bg
}

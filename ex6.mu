# Drawing ASCII text incrementally.
#
# To build a disk image:
#   ./translate ex6.mu             # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f bochsrc               # bochsrc loads disk.img
#
# Expected output: a box and text that doesn't overflow it

fn main screen: (addr screen), keyboard: (addr keyboard) {
  # drawing text within a bounding box
  draw-box-on-real-screen 0xf, 0x1f, 0x79, 0x51, 0x4
  var x/eax: int <- copy 0x20
  var y/ecx: int <- copy 0x20
  x, y <- draw-text-wrapping-right-then-down screen, "hello ",     0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/color
  x, y <- draw-text-wrapping-right-then-down screen, "from ",      0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/color
  x, y <- draw-text-wrapping-right-then-down screen, "baremetal ", 0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/color
  x, y <- draw-text-wrapping-right-then-down screen, "Mu!",        0x10/xmin, 0x20/ymin, 0x78/xmax, 0x50/ymax, x, y, 0xa/color

  # drawing at the cursor in multiple directions
  draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen, "abc", 0xa
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "def", 0xa

  # test drawing near the edge
  x <- draw-text-rightward screen, "R", 0x3f8/x, 0x400/xmax=screen-width, 0x100/y, 0xa/color
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "wrapped from R", 0xa

  x <- draw-text-downward screen, "D", 0x100/x, 0x2f0/y, 0x300/ymax=screen-height, 0xa/color
  draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen, "wrapped from D", 0xa
}

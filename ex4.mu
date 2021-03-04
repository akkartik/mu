# Draw a character using the built-in font (GNU unifont)
#
# To build a disk image:
#   ./translate ex4.mu                            # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f baremetal/boot.bochsrc               # boot.bochsrc loads disk.img
#
# Expected output: letter 'A' in green near the top-left corner of screen

fn main {
  draw-codepoint 0/screen, 0x41/A, 2/row, 1/col, 0xa/fg, 0/bg
}

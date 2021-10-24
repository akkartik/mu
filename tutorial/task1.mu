# Draw a single line of ASCII text.
#
# To build a disk image:
#   ./translate tutorial/task1.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img

fn main screen: (addr screen) {
  var dummy/eax: int <- draw-text-rightward screen, "hello from baremetal Mu!", 0x10/x, 0x400/xmax, 0x10/y, 0xa/fg, 0/bg
}

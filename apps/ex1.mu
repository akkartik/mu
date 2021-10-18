# The simplest possible bare-metal program.
#
# To build a disk image:
#   ./translate apps/ex1.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img
#
# Expected output: blank screen with no errors

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
}

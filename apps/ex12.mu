# Checking the timer.
#
# To build a disk image:
#   ./translate apps/ex12.mu       # emits code.img
# To run:
#   qemu-system-i386 code.img
#
# Expected output: text with slowly updating colors

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var fg/ecx: int <- copy 0
  var prev-timer-counter/edx: int <- copy 0
  {
    var dummy/eax: int <- draw-text-rightward screen, "hello from baremetal Mu!", 0x10/x, 0x400/xmax, 0x10/y, fg, 0/bg
    # wait for timer to bump
    {
      var curr-timer-counter/eax: int <- timer-counter
      compare curr-timer-counter, prev-timer-counter
      loop-if-=
      prev-timer-counter <- copy curr-timer-counter
    }
    # switch color
    fg <- increment
    loop
  }
}

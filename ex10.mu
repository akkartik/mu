# Demo of mouse, showing deltas in x and y position for every event.
#
# To build a disk image:
#   ./translate ex10.mu            # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f bochsrc               # bochsrc loads disk.img
#
# Expected output:
#   Values between -256 and +255 as you move the mouse over the window.
#   You might need to click on the window once.

fn main screen: (addr screen), keyboard: (addr keyboard) {
  # repeatedly print out mouse driver results if non-zero
  $main:event-loop: {
    var dx/eax: int <- copy 0
    var dy/ecx: int <- copy 0
    dx, dy <- read-mouse-event
    {
      compare dx, 0
      break-if-!=
      compare dy, 0
      break-if-!=
      loop $main:event-loop
    }
    {
      var dummy1/eax: int <- copy 0
      var dummy2/ecx: int <- copy 0
      dummy1, dummy2 <- draw-text-wrapping-right-then-down-over-full-screen screen, "         ", 0/x, 0x10/y, 0x31/fg, 0/bg
    }
    {
      var dummy/ecx: int <- copy 0
      dx, dummy <- draw-int32-decimal-wrapping-right-then-down-over-full-screen screen, dx, 0/x, 0x10/y, 0x31/fg, 0/bg
    }
    {
      var dummy/eax: int <- copy 0
      dummy, dy <- draw-int32-decimal-wrapping-right-then-down-over-full-screen screen, dy, 5/x, 0x10/y, 0x31/fg, 0/bg
    }
    loop
  }
}

# Counter app
#   https://eugenkiss.github.io/7guis/tasks/#counter
#
# To build:
#   $ ./translate counter.mu
# To run:
#   $ qemu-system-i386 code.img

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var count/ecx: int <- copy 0
  # widget title
  set-cursor-position screen, 0x1f/x 0xe/y
  draw-text-rightward-from-cursor-over-full-screen screen, " Counter                         ", 0xf/fg 0x16/bg
  # event loop
  {
    # draw current state to screen
    clear-rect screen, 0x1f/xmin 0xf/ymin, 0x40/xmax 0x14/ymax, 0xc5/color
    set-cursor-position screen, 0x20/x 0x10/y
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, count, 7/fg 0xc5/bg
    # render a menu bar
    set-cursor-position screen, 0x24/x 0x12/y
    draw-text-rightward-from-cursor-over-full-screen screen, " enter ", 0/fg 0x5c/bg=highlight
    draw-text-rightward-from-cursor-over-full-screen screen, " increment ", 7/fg 0xc5/bg
    # process a single keystroke
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      compare key, 0xa/newline
      break-if-!=
      count <- increment
    }
    loop
  }
}

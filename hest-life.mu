# Conway's Game of Life in a Hestified way
#   https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life
#   https://ivanish.ca/hest-podcast
#
# To build:
#   $ ./translate life.mu
# To run:
#   $ qemu-system-i386 -enable-kvm code.img

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  {
    render screen, env
    pause env
    edit keyboard, env
    loop
  }
}

type environment {
  zoom: int  # 0 = 1024 px per cell; 5 = 4px per cell; each step adjusts by a factor of 4
  tick: int
}

fn render screen: (addr screen), _self: (addr environment) {
  clear-screen screen
  var self/esi: (addr environment) <- copy _self
  var zoom/eax: (addr int) <- get self, zoom
  compare *zoom, 0
  {
    break-if-!=
    render0 screen, self
    return
  }
}

fn render0 screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  # cell border
  draw-vertical-line   screen, 0xc0/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-vertical-line   screen, 0x340/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-horizontal-line screen, 0x40/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  draw-horizontal-line screen, 0x2c0/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  # neighboring inputs, corners
  draw-rect screen, 0x90/xmin, 0x10/ymin, 0xb0/xmax, 0x30/ymax, 0xf/alive
  draw-rect screen, 0x350/xmin, 0x10/ymin, 0x370/xmax, 0x30/ymax, 0x1a/dead
  draw-rect screen, 0x90/xmin, 0x2d0/ymin, 0xb0/xmax, 0x2f0/ymax, 0xf/alive
  draw-rect screen, 0x350/xmin, 0x2d0/ymin, 0x370/xmax, 0x2f0/ymax, 0xf/alive
  # neighboring inputs, edges
  draw-rect screen, 0x1f0/xmin, 0x10/ymin, 0x210/xmax, 0x30/ymax, 0xf/alive
  draw-rect screen, 0x90/xmin, 0x170/ymin, 0xb0/xmax, 0x190/ymax, 0x1a/dead
  draw-rect screen, 0x1f0/xmin, 0x2d0/ymin, 0x210/xmax, 0x2f0/ymax, 0xf/alive
  draw-rect screen, 0x350/xmin, 0x170/ymin, 0x370/xmax, 0x190/ymax, 0xf/alive
  # sum node
  draw-rect screen, 0x170/xmin, 0x150/ymin, 0x190/xmax, 0x170/ymax, 0x40/color
  set-cursor-position screen, 0x2c/col, 0x14/row
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "+", 0xf/color, 0/bg
  # conveyers from neighboring inputs to sum node
  draw-monotonic-bezier screen, 0xa0/x0 0x20/y0, 0x100/x1 0x160/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0xa0/x0 0x180/y0, 0x110/x1 0x160/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0xa0/x0 0x2e0/y0, 0x100/x1 0x160/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0x200/x0 0x20/y0, 0x180/x1 0x90/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0x200/x0 0x2e0/y0, 0x180/x1 0x200/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0x360/x0 0x20/y0, 0x180/x1 0xc0/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0x360/x0 0x180/y0, 0x300/x1 0x160/y1, 0x180/x2 0x160/y2, 4/color
  draw-monotonic-bezier screen, 0x360/x0 0x2e0/y0, 0x180/x1 0x200/y1, 0x180/x2 0x160/y2, 4/color
  # filter node
  draw-rect screen, 0x200/xmin, 0x180/ymin, 0x220/xmax, 0x1a0/ymax, 0x31/color
  set-cursor-position screen, 0x3f/col, 0x17/row
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "?", 0xf/color, 0/bg
  # conveyer from sum node to filter node
  draw-line screen 0x180/x0, 0x160/y0, 0x210/x1, 0x190/y1, 0xa2/color
  # cell outputs at corners
  draw-rect screen, 0xd0/xmin, 0x50/ymin, 0xf0/xmax, 0x70/ymax, 0xf/alive
  draw-rect screen, 0x310/xmin, 0x50/ymin, 0x330/xmax, 0x70/ymax, 0x1a/dead
  draw-rect screen, 0xd0/xmin, 0x290/ymin, 0xf0/xmax, 0x2b0/ymax, 0xf/alive
  draw-rect screen, 0x310/xmin, 0x290/ymin, 0x330/xmax, 0x2b0/ymax, 0xf/alive
  # cell outputs at edges
  draw-rect screen, 0x1f0/xmin, 0x50/ymin, 0x210/xmax, 0x70/ymax, 0xf/alive
  draw-rect screen, 0xd0/xmin, 0x170/ymin, 0xf0/xmax, 0x190/ymax, 0x1a/dead
  draw-rect screen, 0x1f0/xmin, 0x290/ymin, 0x210/xmax, 0x2b0/ymax, 0xf/alive
  draw-rect screen, 0x310/xmin, 0x170/ymin, 0x330/xmax, 0x190/ymax, 0xf/alive
  # clock
  var tick/eax: (addr int) <- get self, tick
  set-cursor-position screen, 0x78/x, 0/y
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, *tick, 7/fg 0/bg
}

fn edit keyboard: (addr keyboard), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var key/eax: byte <- read-key keyboard
  # TODO: hotkeys
  var dest/eax: (addr int) <- get self, tick
  increment *dest
}

fn pause _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var i/ecx: int <- copy 0
  {
    compare i, 0x10000000
    break-if->=
    i <- increment
    loop
  }
}

fn initialize-environment _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
}

# Conway's Game of Life in a Hestified way
#   https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life
#   https://ivanish.ca/hest-podcast
#
# To build:
#   $ ./translate hest-life.mu
# I run it on my 2.5GHz Linux laptop like this:
#   $ qemu-system-i386 -enable-kvm code.img
#
# If things seem too fast or too slow on your computer, adjust the loop bounds
# in the function `linger` at the bottom. Its value will depend on how you
# accelerate Qemu. Mu will eventually get a clock to obviate the need for this
# tuning.
#
# Keyboard shortcuts:
#   space: pause/resume
#   0: restart time
#   l: start looping from 0 to curren time
#   L: stop looping
#   +: zoom in
#   -: zoom out

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  var second-buffer: screen
  var second-screen/edi: (addr screen) <- address second-buffer
  initialize-screen second-screen, 0x80, 0x30, 1/include-pixels
  render second-screen, env
  copy-screen second-screen, screen
  {
    edit keyboard, env
    var play?/eax: (addr boolean) <- get env, play?
    compare *play?, 0/false
    {
      break-if-=
      step env
      render second-screen, env
      copy-pixels second-screen, screen
    }
    linger env
    loop
  }
}

type environment {
  data: (handle array handle array cell)
  zoom: int  # 0 = 1024 px per cell; 5 = 4px per cell; each step adjusts by a factor of 4
  tick: int
  play?: boolean
  loop: int  # if non-zero, return tick to 0 after this point
}

type cell {
  curr: boolean
  next: boolean
}

fn render screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var zoom/eax: (addr int) <- get self, zoom
  compare *zoom, 0
  {
    break-if-!=
    clear-screen screen
    render0 screen, self
  }
  compare *zoom, 1
  {
    break-if-!=
    clear-screen screen
    render1 screen, self
  }
  compare *zoom, 4
  {
    break-if-!=
    render4 screen, self
  }
  # clock
  var tick-a/eax: (addr int) <- get self, tick
  set-cursor-position screen, 0x78/x, 0/y
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, *tick-a, 7/fg 0/bg
}

# Lots of hardcoded constants for now.
# TODO: split this up into a primitive to render a single cell and its
# incoming edges (but not the neighboring nodes they emanate from)
fn render0 screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  # cell border
  draw-vertical-line   screen,  0xc0/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-vertical-line   screen, 0x340/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-horizontal-line screen,  0x40/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  draw-horizontal-line screen, 0x2c0/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  # neighboring inputs, corners
  var color/eax: int <- state-color self, 0x7f/cur-topleftx, 0x5f/cur-toplefty
  draw-rect screen,  0x90/xmin   0x10/ymin,    0xb0/xmax   0x30/ymax,  color
  color <- state-color self, 0x81/cur-toprightx, 0x5f/cur-toprighty
  draw-rect screen, 0x350/xmin   0x10/ymin,   0x370/xmax   0x30/ymax,  color
  color <- state-color self, 0x7f/cur-botleftx, 0x61/cur-botlefty
  draw-rect screen,  0x90/xmin  0x2d0/ymin,    0xb0/xmax  0x2f0/ymax,  color
  color <- state-color self, 0x81/cur-botrightx, 0x61/cur-botrighty
  draw-rect screen, 0x350/xmin  0x2d0/ymin,   0x370/xmax  0x2f0/ymax,  color
  # neighboring inputs, edges
  color <- state-color self, 0x80/cur-topx, 0x5f/cur-topy
  draw-rect screen, 0x1f0/xmin   0x10/ymin,   0x210/xmax   0x30/ymax,  color
  color <- state-color self, 0x7f/cur-leftx, 0x60/cur-lefty
  draw-rect screen,  0x90/xmin  0x170/ymin,    0xb0/xmax  0x190/ymax,  color
  color <- state-color self, 0x80/cur-botx, 0x61/cur-boty
  draw-rect screen, 0x1f0/xmin  0x2d0/ymin,   0x210/xmax  0x2f0/ymax,  color
  color <- state-color self, 0x81/cur-rightx, 0x60/cur-righty
  draw-rect screen, 0x350/xmin  0x170/ymin,   0x370/xmax  0x190/ymax,  color
  # sum node
  draw-rect screen, 0x170/xsmin 0x140/ysmin,  0x190/xsmax 0x160/ysmax, 0x40/color
  set-cursor-position screen, 0x2d/scol, 0x13/srow
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "+", 0xf/color, 0/bg
  # conveyors from neighboring inputs to sum node
  draw-monotonic-bezier screen,  0xa0/x0  0x20/y0,  0x100/x1 0x150/ys,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen,  0xa0/x0 0x180/y0,   0xc0/x1 0x150/ys,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen,  0xa0/x0 0x2e0/y0,  0x100/x1 0x150/ys,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen, 0x200/x0  0x20/y0,  0x180/x1  0x90/y1,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen, 0x200/x0 0x2e0/y0,  0x180/x1 0x200/y1,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen, 0x360/x0  0x20/y0,  0x180/x1  0xc0/y1,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen, 0x360/x0 0x180/y0,  0x35c/x1 0x150/ys,  0x180/xs 0x150/ys,  4/color
  draw-monotonic-bezier screen, 0x360/x0 0x2e0/y0,  0x180/x1 0x200/y1,  0x180/xs 0x150/ys,  4/color
  # filter node
  draw-rect screen, 0x200/xfmin 0x1c0/yfmin, 0x220/xfmax 0x1e0/yfmax, 0x31/color
  set-cursor-position screen, 0x40/fcol, 0x1b/frow
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "?", 0xf/color, 0/bg
  # conveyor from sum node to filter node
  draw-line screen 0x180/xs, 0x150/ys, 0x210/xf, 0x1d0/yf, 0xa2/color
  # cell outputs at corners
  var color/eax: int <- state-color self, 0x80/curx, 0x60/cury
  draw-rect screen,  0xd0/xmin  0x50/ymin,  0xf0/xmax  0x70/ymax, color
  draw-rect screen, 0x310/xmin  0x50/ymin, 0x330/xmax  0x70/ymax, color
  draw-rect screen,  0xd0/xmin 0x290/ymin,  0xf0/xmax 0x2b0/ymax, color
  draw-rect screen, 0x310/xmin 0x290/ymin, 0x330/xmax 0x2b0/ymax, color
  # cell outputs at edges
  draw-rect screen, 0x1f0/xmin  0x50/ymin, 0x210/xmax  0x70/ymax, color
  draw-rect screen,  0xd0/xmin 0x170/ymin,  0xf0/xmax 0x190/ymax, color
  draw-rect screen, 0x1f0/xmin 0x290/ymin, 0x210/xmax 0x2b0/ymax, color
  draw-rect screen, 0x310/xmin 0x170/ymin, 0x330/xmax 0x190/ymax, color
  # conveyors from filter to outputs
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x1c0/x1  0x60/y1,  0xe0/x2   0x60/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,   0xe0/x1 0x1c0/y1,  0xe0/x2  0x180/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x1c0/x1 0x2a0/y1,  0xe0/x2  0x2a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x210/x1  0x60/y1, 0x200/x2   0x60/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x210/x1 0x230/y1, 0x200/x2  0x2a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x320/x1 0x120/y1, 0x320/x2   0x60/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x320/x1 0x1c0/y1  0x320/x2  0x180/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x210/xf 0x1d0/yf,  0x320/x1 0x230/y1, 0x320/x2  0x2a0/y2,  0x2a/color
  # time-variant portion: 16 repeating steps
  var tick-a/eax: (addr int) <- get self, tick
  var progress/eax: int <- copy *tick-a
  progress <- and 0xf
  # 7 time steps for getting inputs to sum
  {
    compare progress, 7
    break-if->=
    var u/xmm7: float <- convert progress
    var six/eax: int <- copy 6
    var six-f/xmm0: float <- convert six
    u <- divide six-f
    # points on conveyors from neighboring cells
    draw-bezier-point screen, u,  0xa0/x0  0x20/y0, 0x100/x1 0x150/ys, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u,  0xa0/x0 0x180/y0,  0xc0/x1 0x150/ys, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u,  0xa0/x0 0x2e0/y0, 0x100/x1 0x150/ys, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u, 0x200/x0  0x20/y0, 0x180/x1  0x90/y1, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u, 0x200/x0 0x2e0/y0, 0x180/x1 0x200/y1, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u, 0x360/x0  0x20/y0, 0x180/x1  0xc0/y1, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u, 0x360/x0 0x180/y0, 0x35c/x1 0x150/ys, 0x180/xs 0x150/ys, 7/color, 4/radius
    draw-bezier-point screen, u, 0x360/x0 0x2e0/y0, 0x180/x1 0x200/y1, 0x180/xs 0x150/ys, 7/color, 4/radius
    return
  }
  # two time steps for getting count to filter
  progress <- subtract 7
  {
    compare progress, 2
    break-if->=
    progress <- increment  # (0, 1) => (1, 2)
    var u/xmm7: float <- convert progress
    var three/eax: int <- copy 3
    var three-f/xmm0: float <- convert three
    u <- divide three-f
    draw-linear-point screen, u, 0x180/xs, 0x150/ys, 0x210/xf, 0x1d0/yf, 7/color, 4/radius
    set-cursor-position screen, 0x3a/scol, 0x18/srow
    var n/eax: int <- num-live-neighbors self, 0x80/curx, 0x60/cury
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, n, 0xf/fg 0/bg
    return
  }
  # final 7 time steps for updating output
  progress <- subtract 2
  # points on conveyors to outputs
  var u/xmm7: float <- convert progress
  var six/eax: int <- copy 6
  var six-f/xmm0: float <- convert six
  u <- divide six-f
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x1c0/x1  0x60/y1,  0xe0/x2   0x60/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,   0xe0/x1 0x1c0/y1,  0xe0/x2  0x180/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x1c0/x1 0x2a0/y1,  0xe0/x2  0x2a0/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x210/xf  0x60/y1, 0x200/x2   0x60/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x210/xf 0x230/y1, 0x200/x2  0x2a0/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x320/x1 0x120/y1, 0x320/x2   0x60/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x320/x1 0x1c0/y1, 0x320/x2  0x180/y2, 7/color, 4/radius
  draw-bezier-point screen, u, 0x210/xf 0x1d0/yf,  0x320/x1 0x230/y1, 0x320/x2  0x2a0/y2, 7/color, 4/radius
}

fn render1 screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  # cell borders
  draw-vertical-line   screen,  0xe0/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-vertical-line   screen, 0x200/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-vertical-line   screen, 0x320/x, 0/ymin, 0x300/ymax, 0x16/color=dark-grey
  draw-horizontal-line screen,  0x60/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  draw-horizontal-line screen, 0x180/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  draw-horizontal-line screen, 0x2a0/y, 0/xmin, 0x400/xmax, 0x16/color=dark-grey
  # cell 0: outputs
  var color/eax: int <- state-color self, 0x80/curx, 0x60/cury
  draw-rect screen,  0xe8/xmin  0x68/ymin, 0x118/xmax   0x98/ymax, color
  draw-rect screen,  0xe8/xmin  0xd0/ymin, 0x118/xmax  0x100/ymax, color
  draw-rect screen,  0xe8/xmin 0x148/ymin, 0x118/xmax  0x178/ymax, color
  draw-rect screen, 0x158/xmin  0x68/ymin, 0x188/xmax   0x98/ymax, color
  draw-rect screen, 0x158/xmin 0x148/ymin, 0x188/xmax  0x178/ymax, color
  draw-rect screen, 0x1c8/xmin  0x68/ymin, 0x1f8/xmax   0x98/ymax, color
  draw-rect screen, 0x1c8/xmin  0xd0/ymin, 0x1f8/xmax  0x100/ymax, color
  draw-rect screen, 0x1c8/xmin 0x148/ymin, 0x1f8/xmax  0x178/ymax, color
  # cell 1: outputs
  var color/eax: int <- state-color self, 0x81/curx, 0x60/cury
  draw-rect screen, 0x208/xmin  0x68/ymin, 0x238/xmax   0x98/ymax, color
  draw-rect screen, 0x208/xmin  0xd0/ymin, 0x238/xmax  0x100/ymax, color
  draw-rect screen, 0x208/xmin 0x148/ymin, 0x238/xmax  0x178/ymax, color
  draw-rect screen, 0x278/xmin  0x68/ymin, 0x2a8/xmax   0x98/ymax, color
  draw-rect screen, 0x278/xmin 0x148/ymin, 0x2a8/xmax  0x178/ymax, color
  draw-rect screen, 0x2e8/xmin  0x68/ymin, 0x318/xmax   0x98/ymax, color
  draw-rect screen, 0x2e8/xmin  0xd0/ymin, 0x318/xmax  0x100/ymax, color
  draw-rect screen, 0x2e8/xmin 0x148/ymin, 0x318/xmax  0x178/ymax, color
  # cell 2: outputs
  var color/eax: int <- state-color self, 0x80/curx, 0x61/cury
  draw-rect screen,  0xe8/xmin 0x188/ymin, 0x118/xmax  0x1b8/ymax, color
  draw-rect screen,  0xe8/xmin 0x1f0/ymin, 0x118/xmax  0x220/ymax, color
  draw-rect screen,  0xe8/xmin 0x268/ymin, 0x118/xmax  0x298/ymax, color
  draw-rect screen, 0x158/xmin 0x188/ymin, 0x188/xmax  0x1b8/ymax, color
  draw-rect screen, 0x158/xmin 0x268/ymin, 0x188/xmax  0x298/ymax, color
  draw-rect screen, 0x1c8/xmin 0x188/ymin, 0x1f8/xmax  0x1b8/ymax, color
  draw-rect screen, 0x1c8/xmin 0x1f0/ymin, 0x1f8/xmax  0x220/ymax, color
  draw-rect screen, 0x1c8/xmin 0x268/ymin, 0x1f8/xmax  0x298/ymax, color
  # cell 3: outputs
  var color/eax: int <- state-color self, 0x81/curx, 0x61/cury
  draw-rect screen, 0x208/xmin 0x188/ymin, 0x238/xmax  0x1b8/ymax, color
  draw-rect screen, 0x208/xmin 0x1f0/ymin, 0x238/xmax  0x220/ymax, color
  draw-rect screen, 0x208/xmin 0x268/ymin, 0x238/xmax  0x298/ymax, color
  draw-rect screen, 0x278/xmin 0x188/ymin, 0x2a8/xmax  0x1b8/ymax, color
  draw-rect screen, 0x278/xmin 0x268/ymin, 0x2a8/xmax  0x298/ymax, color
  draw-rect screen, 0x2e8/xmin 0x188/ymin, 0x318/xmax  0x1b8/ymax, color
  draw-rect screen, 0x2e8/xmin 0x1f0/ymin, 0x318/xmax  0x220/ymax, color
  draw-rect screen, 0x2e8/xmin 0x268/ymin, 0x318/xmax  0x298/ymax, color
  # neighboring nodes
  var color/eax: int <- state-color self, 0x7f/curx, 0x5f/cury
  draw-rect screen,  0xa8/xmin  0x28/ymin,  0xd8/xmax   0x58/ymax, color
  var color/eax: int <- state-color self, 0x80/curx, 0x5f/cury
  draw-rect screen, 0x158/xmin  0x28/ymin, 0x188/xmax   0x58/ymax, color
  draw-rect screen, 0x1c8/xmin  0x28/ymin, 0x1f8/xmax   0x58/ymax, color
  var color/eax: int <- state-color self, 0x81/curx, 0x5f/cury
  draw-rect screen, 0x208/xmin  0x28/ymin, 0x238/xmax   0x58/ymax, color
  draw-rect screen, 0x278/xmin  0x28/ymin, 0x2a8/xmax   0x58/ymax, color
  var color/eax: int <- state-color self, 0x82/curx, 0x5f/cury
  draw-rect screen, 0x328/xmin  0x28/ymin, 0x358/xmax   0x58/ymax, color
  var color/eax: int <- state-color self, 0x7f/curx, 0x60/cury
  draw-rect screen,  0xa8/xmin  0xd0/ymin,  0xd8/xmax  0x100/ymax, color
  draw-rect screen,  0xa8/xmin 0x148/ymin,  0xd8/xmax  0x178/ymax, color
  var color/eax: int <- state-color self, 0x82/curx, 0x60/cury
  draw-rect screen, 0x328/xmin  0xd0/ymin, 0x358/xmax  0x100/ymax, color
  draw-rect screen, 0x328/xmin 0x148/ymin, 0x358/xmax  0x178/ymax, color
  var color/eax: int <- state-color self, 0x7f/curx, 0x61/cury
  draw-rect screen,  0xa8/xmin 0x188/ymin,  0xd8/xmax  0x1b8/ymax, color
  draw-rect screen,  0xa8/xmin 0x1f0/ymin,  0xd8/xmax  0x220/ymax, color
  var color/eax: int <- state-color self, 0x82/curx, 0x61/cury
  draw-rect screen, 0x328/xmin 0x188/ymin, 0x358/xmax  0x1b8/ymax, color
  draw-rect screen, 0x328/xmin 0x1f0/ymin, 0x358/xmax  0x220/ymax, color
  var color/eax: int <- state-color self, 0x7f/curx, 0x62/cury
  draw-rect screen,  0xa8/xmin 0x2a8/ymin,  0xd8/xmax  0x2d8/ymax, color
  var color/eax: int <- state-color self, 0x80/curx, 0x62/cury
  draw-rect screen, 0x158/xmin 0x2a8/ymin, 0x188/xmax  0x2d8/ymax, color
  draw-rect screen, 0x1c8/xmin 0x2a8/ymin, 0x1f8/xmax  0x2d8/ymax, color
  var color/eax: int <- state-color self, 0x81/curx, 0x62/cury
  draw-rect screen, 0x208/xmin 0x2a8/ymin, 0x238/xmax  0x2d8/ymax, color
  draw-rect screen, 0x278/xmin 0x2a8/ymin, 0x2a8/xmax  0x2d8/ymax, color
  var color/eax: int <- state-color self, 0x82/curx, 0x62/cury
  draw-rect screen, 0x328/xmin 0x2a8/ymin, 0x358/xmax  0x2d8/ymax, color
  # cell 0: sum and filter nodes
  draw-rect screen, 0x148/xsmin  0xc8/ysmin, 0x158/xsmax  0xd8/ysmax, 0x40/color
  draw-rect screen, 0x180/xfmin  0xf8/yfmin, 0x190/xfmax 0x108/yfmax, 0x31/color
  # cell 1: sum and filter nodes
  draw-rect screen, 0x268/xsmin  0xc8/ysmin, 0x278/xsmax  0xd8/ysmax, 0x40/color
  draw-rect screen, 0x2a0/xfmin  0xf8/yfmin, 0x2b0/xfmax 0x108/yfmax, 0x31/color
  # cell 2: sum and filter nodes
  draw-rect screen, 0x148/xsmin 0x1e8/ysmin, 0x158/xsmax 0x1f8/ysmax, 0x40/color
  draw-rect screen, 0x180/xfmin 0x218/yfmin, 0x190/xfmax 0x228/yfmax, 0x31/color
  # cell 3: sum and filter nodes
  draw-rect screen, 0x268/xsmin 0x1e8/ysmin, 0x278/xsmax 0x1f8/ysmax, 0x40/color
  draw-rect screen, 0x2a0/xfmin 0x218/yfmin, 0x2b0/xfmax 0x228/yfmax, 0x31/color
  # neighbor counts
  var n/eax: int <- num-live-neighbors self, 0x80/curx, 0x60/cury
  set-cursor-position screen, 0x2d, 0xe
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, n, 0xf/fg 0/bg
  var n/eax: int <- num-live-neighbors self, 0x81/curx, 0x60/cury
  set-cursor-position screen, 0x52, 0xe
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, n, 0xf/fg 0/bg
  var n/eax: int <- num-live-neighbors self, 0x80/curx, 0x61/cury
  set-cursor-position screen, 0x2d, 0x20
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, n, 0xf/fg 0/bg
  var n/eax: int <- num-live-neighbors self, 0x81/curx, 0x61/cury
  set-cursor-position screen, 0x52, 0x20
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, n, 0xf/fg 0/bg
  # cell 0: conveyors from neighboring inputs to sum node
  draw-monotonic-bezier screen,  0xc0/x0  0x40/y0,  0x100/x1  0xd0/ys, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen,  0xc0/x0  0xe8/y0,   0xc0/x1  0xd0/ys, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen,  0xc0/x0 0x1a0/y0,   0xe0/x1  0xd0/ys, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x170/x0  0x40/y0,  0x150/x1  0x80/y1, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x170/x0 0x1a0/y0,  0x150/x1 0x1a0/y1, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x220/x0  0x40/y0,  0x150/x1  0x80/y1, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x220/x0  0xe8/y0,  0x220/x1  0xd0/y1, 0x150/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x220/x0 0x1a0/y0,  0x180/x1 0x1a0/y1, 0x150/xs  0xd0/ys,  4/color
  # cell 0: conveyors from filter to outputs
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x160/x1  0x8c/y1, 0x100/x2  0x80/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x100/x1 0x100/y1, 0x100/x2  0xe8/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x100/x1 0x100/y1, 0x100/x2 0x160/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x188/x1  0x80/y1, 0x170/x2  0x80/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x188/x1 0x160/y1, 0x170/x2 0x160/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x1e0/x1 0x100/y1, 0x1e0/x2  0x80/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x1e0/x1 0x100/y1  0x1e0/x2  0xe8/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x100/yf,  0x1e0/x1 0x100/y1, 0x1e0/x2 0x160/y2,  0x2a/color
  # cell 0: time-variant portion: 16 repeating steps
  $render1:cell0: {
    var tick-a/eax: (addr int) <- get self, tick
    var progress/eax: int <- copy *tick-a
    progress <- and 0xf
    # cell 0: 7 time steps for getting inputs to sum
    {
      compare progress, 7
      break-if->=
      var u/xmm7: float <- convert progress
      var six/eax: int <- copy 6
      var six-f/xmm0: float <- convert six
      u <- divide six-f
      # points on conveyors from neighboring cells
      draw-bezier-point screen, u,  0xc0/x0  0x40/y0, 0x100/x1  0xd0/ys, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u,  0xc0/x0  0xe8/y0,  0xc0/x1  0xd0/ys, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u,  0xc0/x0 0x1a0/y0,  0xe0/x1  0xd0/ys, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x170/x0  0x40/y0, 0x150/x1  0x80/y1, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x170/x0 0x1a0/y0, 0x150/x1 0x1a0/y1, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x220/x0  0x40/y0, 0x150/x1  0x80/y1, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x220/x0  0xe8/y0, 0x220/x1  0xd0/y1, 0x150/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x220/x0 0x1a0/y0, 0x180/x1 0x1a0/y1, 0x150/xs  0xd0/ys, 7/color, 4/radius
      break $render1:cell0
    }
    # cell 0: two time steps for getting count to filter
    progress <- subtract 7
    {
      compare progress, 2
      break-if->=
      break $render1:cell0
    }
    # cell 0: final 7 time steps for updating output
    progress <- subtract 2
    # cell 0: points on conveyors to outputs
    var u/xmm7: float <- convert progress
    var six/eax: int <- copy 6
    var six-f/xmm0: float <- convert six
    u <- divide six-f
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x160/x1  0x8c/y1, 0x100/x2  0x80/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x100/x1 0x100/y1, 0x100/x2  0xe8/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x100/x1 0x100/y1, 0x100/x2 0x160/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x188/xf  0x80/y1, 0x170/x2  0x80/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x188/xf 0x160/y1, 0x170/x2 0x160/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x1e0/x1 0x100/y1, 0x1e0/x2  0x80/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x1e0/x1 0x100/y1, 0x1e0/x2  0xe8/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x100/yf,  0x1e0/x1 0x100/y1, 0x1e0/x2 0x160/y2, 7/color, 4/radius
  }
  # cell 1: conveyors from neighboring inputs to sum node
  draw-monotonic-bezier screen, 0x1e0/x0  0x40/y0,  0x220/x1  0xd0/ys, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x1e0/x0  0xe8/y0,  0x1e0/x1  0xd0/ys, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x1e0/x0 0x1a0/y0,  0x200/x1  0xd0/ys, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x290/x0  0x40/y0,  0x270/x1  0x80/y1, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x290/x0 0x1a0/y0,  0x270/x1 0x1a0/y1, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x340/x0  0x40/y0,  0x270/x1  0x80/y1, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x340/x0  0xe8/y0,  0x340/x1  0xd0/y1, 0x270/xs  0xd0/ys,  4/color
  draw-monotonic-bezier screen, 0x340/x0 0x1a0/y0,  0x2a0/x1 0x1a0/y1, 0x270/xs  0xd0/ys,  4/color
  # cell 1: conveyors from filter to outputs
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x280/x1  0x8c/y1, 0x220/x2  0x80/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x220/x1 0x100/y1, 0x220/x2  0xe8/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x220/x1 0x100/y1, 0x220/x2 0x160/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x2a8/x1  0x80/y1, 0x290/x2  0x80/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x2a8/x1 0x160/y1, 0x290/x2 0x160/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x300/x1 0x100/y1, 0x300/x2  0x80/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x300/x1 0x100/y1  0x300/x2  0xe8/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x100/yf,  0x300/x1 0x100/y1, 0x300/x2 0x160/y2,  0x2a/color
  # cell 1: time-variant portion: 16 repeating steps
  $render1:cell1: {
    var tick-a/eax: (addr int) <- get self, tick
    var progress/eax: int <- copy *tick-a
    progress <- and 0xf
    # cell 1: 7 time steps for getting inputs to sum
    {
      compare progress, 7
      break-if->=
      var u/xmm7: float <- convert progress
      var six/eax: int <- copy 6
      var six-f/xmm0: float <- convert six
      u <- divide six-f
      # points on conveyors from neighboring cells
      draw-bezier-point screen, u, 0x1e0/x0  0x40/y0, 0x220/x1  0xd0/ys, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x1e0/x0  0xe8/y0, 0x1e0/x1  0xd0/ys, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x1e0/x0 0x1a0/y0, 0x200/x1  0xd0/ys, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x290/x0  0x40/y0, 0x270/x1  0x80/y1, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x290/x0 0x1a0/y0, 0x270/x1 0x1a0/y1, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x340/x0  0x40/y0, 0x270/x1  0x80/y1, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x340/x0  0xe8/y0, 0x340/x1  0xd0/y1, 0x270/xs  0xd0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x340/x0 0x1a0/y0, 0x2a0/x1 0x1a0/y1, 0x270/xs  0xd0/ys, 7/color, 4/radius
      break $render1:cell1
    }
    # cell 1: two time steps for getting count to filter
    progress <- subtract 7
    {
      compare progress, 2
      break-if->=
      break $render1:cell1
    }
    # cell 1: final 7 time steps for updating output
    progress <- subtract 2
    # cell 1: points on conveyors to outputs
    var u/xmm7: float <- convert progress
    var six/eax: int <- copy 6
    var six-f/xmm0: float <- convert six
    u <- divide six-f
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x280/x1  0x8c/y1, 0x220/x2  0x80/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x220/x1 0x100/y1, 0x220/x2  0xe8/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x220/x1 0x100/y1, 0x220/x2 0x160/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x2a8/xf  0x80/y1, 0x290/x2  0x80/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x2a8/xf 0x160/y1, 0x290/x2 0x160/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x300/x1 0x100/y1, 0x300/x2  0x80/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x300/x1 0x100/y1, 0x300/x2  0xe8/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x100/yf,  0x300/x1 0x100/y1, 0x300/x2 0x160/y2, 7/color, 4/radius
  }
  # cell 2: conveyors from neighboring inputs to sum node
  draw-monotonic-bezier screen,  0xc0/x0 0x160/y0,  0x100/x1 0x1f0/ys, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen,  0xc0/x0 0x208/y0,   0xc0/x1 0x1f0/ys, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen,  0xc0/x0 0x2c0/y0,   0xe0/x1 0x1f0/ys, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x170/x0 0x160/y0,  0x150/x1 0x1a0/y1, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x170/x0 0x2c0/y0,  0x150/x1 0x2c0/y1, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x220/x0 0x160/y0,  0x150/x1 0x1a0/y1, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x220/x0 0x208/y0,  0x220/x1 0x1f0/y1, 0x150/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x220/x0 0x2c0/y0,  0x180/x1 0x2c0/y1, 0x150/xs 0x1f0/ys,  4/color
  # cell 2: conveyors from filter to outputs
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x160/x1 0x1ac/y1, 0x100/x2 0x1a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x100/x1 0x220/y1, 0x100/x2 0x208/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x100/x1 0x220/y1, 0x100/x2 0x280/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x188/x1 0x1a0/y1, 0x170/x2 0x1a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x188/x1 0x280/y1, 0x170/x2 0x280/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x1e0/x1 0x220/y1, 0x1e0/x2 0x1a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x1e0/x1 0x220/y1  0x1e0/x2 0x208/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x188/xf 0x220/yf,  0x1e0/x1 0x220/y1, 0x1e0/x2 0x280/y2,  0x2a/color
  # cell 2: time-variant portion: 16 repeating steps
  $render1:cell2: {
    var tick-a/eax: (addr int) <- get self, tick
    var progress/eax: int <- copy *tick-a
    progress <- and 0xf
    # cell 2: 7 time steps for getting inputs to sum
    {
      compare progress, 7
      break-if->=
      var u/xmm7: float <- convert progress
      var six/eax: int <- copy 6
      var six-f/xmm0: float <- convert six
      u <- divide six-f
      # points on conveyors from neighboring cells
      draw-bezier-point screen, u,  0xc0/x0 0x160/y0, 0x100/x1 0x1f0/ys, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u,  0xc0/x0 0x208/y0,  0xc0/x1 0x1f0/ys, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u,  0xc0/x0 0x2c0/y0,  0xe0/x1 0x1f0/ys, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x170/x0 0x160/y0, 0x150/x1 0x1a0/y1, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x170/x0 0x2c0/y0, 0x150/x1 0x2c0/y1, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x220/x0 0x160/y0, 0x150/x1 0x1a0/y1, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x220/x0 0x208/y0, 0x220/x1 0x1f0/y1, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x220/x0 0x2c0/y0, 0x180/x1 0x2c0/y1, 0x150/xs 0x1f0/ys, 7/color, 4/radius
      break $render1:cell2
    }
    # cell 2: two time steps for getting count to filter
    progress <- subtract 7
    {
      compare progress, 2
      break-if->=
      break $render1:cell2
    }
    # cell 2: final 7 time steps for updating output
    progress <- subtract 2
    # cell 2: points on conveyors to outputs
    var u/xmm7: float <- convert progress
    var six/eax: int <- copy 6
    var six-f/xmm0: float <- convert six
    u <- divide six-f
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x160/x1 0x1ac/y1, 0x100/x2 0x1a0/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x100/x1 0x220/y1, 0x100/x2 0x208/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x100/x1 0x220/y1, 0x100/x2 0x280/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x188/xf 0x1a0/y1, 0x170/x2 0x1a0/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x188/xf 0x280/y1, 0x170/x2 0x280/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x1e0/x1 0x220/y1, 0x1e0/x2 0x1a0/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x1e0/x1 0x220/y1, 0x1e0/x2 0x208/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x188/xf 0x220/yf,  0x1e0/x1 0x220/y1, 0x1e0/x2 0x280/y2, 7/color, 4/radius
  }
  # cell 3: conveyors from neighboring inputs to sum node
  draw-monotonic-bezier screen, 0x1e0/x0 0x160/y0,  0x220/x1 0x1f0/ys, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x1e0/x0 0x208/y0,  0x1e0/x1 0x1f0/ys, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x1e0/x0 0x2c0/y0,  0x200/x1 0x1f0/ys, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x290/x0 0x160/y0,  0x270/x1 0x1a0/y1, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x290/x0 0x2c0/y0,  0x270/x1 0x2c0/y1, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x340/x0 0x160/y0,  0x270/x1 0x1a0/y1, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x340/x0 0x208/y0,  0x340/x1 0x1f0/y1, 0x270/xs 0x1f0/ys,  4/color
  draw-monotonic-bezier screen, 0x340/x0 0x2c0/y0,  0x2a0/x1 0x2c0/y1, 0x270/xs 0x1f0/ys,  4/color
  # cell 3: conveyors from filter to outputs
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x280/x1 0x1ac/y1, 0x220/x2 0x1a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x220/x1 0x220/y1, 0x220/x2 0x208/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x220/x1 0x220/y1, 0x220/x2 0x280/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x2a8/x1 0x1a0/y1, 0x290/x2 0x1a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x2a8/x1 0x280/y1, 0x290/x2 0x280/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x300/x1 0x220/y1, 0x300/x2 0x1a0/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x300/x1 0x220/y1  0x300/x2 0x208/y2,  0x2a/color
  draw-monotonic-bezier screen, 0x2a8/xf 0x220/yf,  0x300/x1 0x220/y1, 0x300/x2 0x280/y2,  0x2a/color
  # cell 3: time-variant portion: 16 repeating steps
  $render1:cell3: {
    var tick-a/eax: (addr int) <- get self, tick
    var progress/eax: int <- copy *tick-a
    progress <- and 0xf
    # cell 3: 7 time steps for getting inputs to sum
    {
      compare progress, 7
      break-if->=
      var u/xmm7: float <- convert progress
      var six/eax: int <- copy 6
      var six-f/xmm0: float <- convert six
      u <- divide six-f
      # points on conveyors from neighboring cells
      draw-bezier-point screen, u, 0x1e0/x0 0x160/y0, 0x220/x1 0x1f0/ys, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x1e0/x0 0x208/y0, 0x1e0/x1 0x1f0/ys, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x1e0/x0 0x2c0/y0, 0x200/x1 0x1f0/ys, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x290/x0 0x160/y0, 0x270/x1 0x1a0/y1, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x290/x0 0x2c0/y0, 0x270/x1 0x2c0/y1, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x340/x0 0x160/y0, 0x270/x1 0x1a0/y1, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x340/x0 0x208/y0, 0x340/x1 0x1f0/y1, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      draw-bezier-point screen, u, 0x340/x0 0x2c0/y0, 0x2a0/x1 0x2c0/y1, 0x270/xs 0x1f0/ys, 7/color, 4/radius
      break $render1:cell3
    }
    # cell 3: two time steps for getting count to filter
    progress <- subtract 7
    {
      compare progress, 2
      break-if->=
      break $render1:cell3
    }
    # cell 3: final 7 time steps for updating output
    progress <- subtract 2
    # cell 3: points on conveyors to outputs
    var u/xmm7: float <- convert progress
    var six/eax: int <- copy 6
    var six-f/xmm0: float <- convert six
    u <- divide six-f
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x280/x1 0x1ac/y1, 0x220/x2 0x1a0/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x220/x1 0x220/y1, 0x220/x2 0x208/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x220/x1 0x220/y1, 0x220/x2 0x280/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x2a8/xf 0x1a0/y1, 0x290/x2 0x1a0/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x2a8/xf 0x280/y1, 0x290/x2 0x280/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x300/x1 0x220/y1, 0x300/x2 0x1a0/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x300/x1 0x220/y1, 0x300/x2 0x208/y2, 7/color, 4/radius
    draw-bezier-point screen, u, 0x2a8/xf 0x220/yf,  0x300/x1 0x220/y1, 0x300/x2 0x280/y2, 7/color, 4/radius
  }
}

fn draw-bezier-point screen: (addr screen), u: float, x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: int, radius: int {
  var _cy/eax: int <- bezier-point u, y0, y1, y2
  var cy/ecx: int <- copy _cy
  var cx/eax: int <- bezier-point u, x0, x1, x2
  draw-disc screen, cx, cy, radius, color, 0xf/border-color=white
}

fn draw-linear-point screen: (addr screen), u: float, x0: int, y0: int, x1: int, y1: int, color: int, radius: int {
  var _cy/eax: int <- line-point u, y0, y1
  var cy/ecx: int <- copy _cy
  var cx/eax: int <- line-point u, x0, x1
  draw-disc screen, cx, cy, radius, color, 0xf/border-color=white
}

fn edit keyboard: (addr keyboard), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var key/eax: byte <- read-key keyboard
  # space: play/pause
  {
    compare key, 0x20/space
    break-if-!=
    var play?/eax: (addr boolean) <- get self, play?
    compare *play?, 0/false
    {
      break-if-=
      copy-to *play?, 0/false
      return
    }
    copy-to *play?, 1/true
    return
  }
  # 0: back to start
  {
    compare key, 0x30/0
    break-if-!=
    clear-environment self
    return
  }
  # l: loop from here to start
  {
    compare key, 0x6c/l
    break-if-!=
    var tick-a/eax: (addr int) <- get self, tick
    var tick/eax: int <- copy *tick-a
    var loop/ecx: (addr int) <- get self, loop
    copy-to *loop, tick
    return
  }
  # L: reset loop
  {
    compare key, 0x4c/L
    break-if-!=
    var loop/eax: (addr int) <- get self, loop
    copy-to *loop, 0
    return
  }
  # -: zoom out
  {
    compare key, 0x2d/-
    break-if-!=
    var zoom/eax: (addr int) <- get self, zoom
    compare *zoom, 1
    {
      break-if-!=
      copy-to *zoom, 4
    }
    compare *zoom, 0
    {
      break-if-!=
      copy-to *zoom, 1
    }
    # set tick to a multiple of zoom
    var tick-a/edx: (addr int) <- get self, tick
    clear-lowest-bits tick-a, *zoom
    return
  }
  # +: zoom in
  {
    compare key, 0x2b/+
    break-if-!=
    var zoom/eax: (addr int) <- get self, zoom
    compare *zoom, 1
    {
      break-if-!=
      copy-to *zoom, 0
    }
    compare *zoom, 4
    {
      break-if-!=
      copy-to *zoom, 1
    }
    # set tick to a multiple of zoom
    var tick-a/edx: (addr int) <- get self, tick
    clear-lowest-bits tick-a, *zoom
    return
  }
}

fn step _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var tick-a/ecx: (addr int) <- get self, tick
  var zoom/edx: (addr int) <- get self, zoom
  compare *zoom, 0
  {
    break-if-!=
    increment *tick-a
  }
  compare *zoom, 1
  {
    break-if-!=
    # I wanted to speed up time, but that doesn't seem very usable.
#?     add-to *tick-a, 2
    increment *tick-a
  }
  compare *zoom, 4
  {
    break-if-!=
    add-to *tick-a, 0x10
  }
  var tick/eax: int <- copy *tick-a
  tick <- and 0xf
  compare tick, 0
  {
    break-if-!=
    step4 self
  }
  var loop-a/eax: (addr int) <- get self, loop
  compare *loop-a, 0
  {
    break-if-=
    var loop/eax: int <- copy *loop-a
    compare *tick-a, loop
    break-if-<
    clear-environment self
  }
}

fn initialize-environment _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var zoom/eax: (addr int) <- get self, zoom
  copy-to *zoom, 0
  var play?/eax: (addr boolean) <- get self, play?
  copy-to *play?, 1/true
  var data-ah/eax: (addr handle array handle array cell) <- get self, data
  populate data-ah, 0x100
  var data/eax: (addr array handle array cell) <- lookup *data-ah
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0
    break-if->=
    var dest-ah/eax: (addr handle array cell) <- index data, y
    populate dest-ah, 0x100
    y <- increment
    loop
  }
  set self, 0x80, 0x5f, 1/alive
  set self, 0x81, 0x5f, 1/alive
  set self, 0x7f, 0x60, 1/alive
  set self, 0x80, 0x60, 1/alive
  set self, 0x80, 0x61, 1/alive
  flush self
}

fn clear-environment _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var tick/eax: (addr int) <- get self, tick
  copy-to *tick, 0
  # don't touch zoom or play settings
  var data-ah/eax: (addr handle array handle array cell) <- get self, data
  var data/eax: (addr array handle array cell) <- lookup *data-ah
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0
    break-if->=
    var row-ah/eax: (addr handle array cell) <- index data, y
    var row/eax: (addr array cell) <- lookup *row-ah
    var x/edx: int <- copy 0
    {
      compare x, 0x100
      break-if->=
      var dest/eax: (addr cell) <- index row, x
      clear-object dest
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  set self, 0x80, 0x5f, 1/alive
  set self, 0x81, 0x5f, 1/alive
  set self, 0x7f, 0x60, 1/alive
  set self, 0x80, 0x60, 1/alive
  set self, 0x80, 0x61, 1/alive
  flush self
}

fn set _self: (addr environment), _x: int, _y: int, _val: boolean {
  var self/esi: (addr environment) <- copy _self
  var data-ah/eax: (addr handle array handle array cell) <- get self, data
  var data/eax: (addr array handle array cell) <- lookup *data-ah
  var y/ecx: int <- copy _y
  var row-ah/eax: (addr handle array cell) <- index data, y
  var row/eax: (addr array cell) <- lookup *row-ah
  var x/ecx: int <- copy _x
  var cell/eax: (addr cell) <- index row, x
  var dest/eax: (addr boolean) <- get cell, next
  var val/ecx: boolean <- copy _val
  copy-to *dest, val
}

fn state _self: (addr environment), _x: int, _y: int -> _/eax: boolean {
  var self/esi: (addr environment) <- copy _self
  var x/ecx: int <- copy _x
  var y/edx: int <- copy _y
  # clip at the edge
  compare x, 0
  {
    break-if->=
    return 0/false
  }
  compare y, 0
  {
    break-if->=
    return 0/false
  }
  compare x, 0x100/width
  {
    break-if-<
    return 0/false
  }
  compare y, 0xc0/height
  {
    break-if-<
    return 0/false
  }
  var data-ah/eax: (addr handle array handle array cell) <- get self, data
  var data/eax: (addr array handle array cell) <- lookup *data-ah
  var row-ah/eax: (addr handle array cell) <- index data, y
  var row/eax: (addr array cell) <- lookup *row-ah
  var cell/eax: (addr cell) <- index row, x
  var src/eax: (addr boolean) <- get cell, curr
  return *src
}

fn state-color _self: (addr environment), x: int, y: int -> _/eax: int {
  var self/esi: (addr environment) <- copy _self
  var color/ecx: int <- copy 0x1a/dead
  {
    var state/eax: boolean <- state self, x, y
    compare state, 0/dead
    break-if-=
    color <- copy 0xf/alive
  }
  return color
}

fn flush  _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var data-ah/eax: (addr handle array handle array cell) <- get self, data
  var _data/eax: (addr array handle array cell) <- lookup *data-ah
  var data/esi: (addr array handle array cell) <- copy _data
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0/height
    break-if->=
    var row-ah/eax: (addr handle array cell) <- index data, y
    var _row/eax: (addr array cell) <- lookup *row-ah
    var row/ebx: (addr array cell) <- copy _row
    var x/edx: int <- copy 0
    {
      compare x, 0x100/width
      break-if->=
      var cell-a/eax: (addr cell) <- index row, x
      var curr-a/edi: (addr boolean) <- get cell-a, curr
      var next-a/esi: (addr boolean) <- get cell-a, next
      var val/eax: boolean <- copy *next-a
      copy-to *curr-a, val
      copy-to *next-a, 0/dead
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn render4 screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0/height
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x100/width
      break-if->=
      var state/eax: boolean <- state self, x, y
      compare state, 0/false
      {
        break-if-=
        render4-cell screen, x, y, 0xf/alive
      }
      compare state, 0/false
      {
        break-if-!=
        render4-cell screen, x, y, 0x1a/dead
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn render4-cell screen: (addr screen), x: int, y: int, color: int {
  var xmin/eax: int <- copy x
  xmin <- shift-left 2
  var xmax/ecx: int <- copy xmin
  xmax <- add 4
  var ymin/edx: int <- copy y
  ymin <- shift-left 2
  var ymax/ebx: int <- copy ymin
  ymax <- add 4
  draw-rect screen, xmin ymin, xmax ymax, color
}

fn step4 _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0/height
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x100/width
      break-if->=
      var n/eax: int <- num-live-neighbors self, x, y
      # if neighbors < 2, die of loneliness
      {
        compare n, 2
        break-if->=
        set self, x, y, 0/dead
      }
      # if neighbors > 3, die of overcrowding
      {
        compare n, 3
        break-if-<=
        set self, x, y, 0/dead
      }
      # if neighbors = 2, preserve state
      {
        compare n, 2
        break-if-!=
        var old-state/eax: boolean <- state self, x, y
        set self, x, y, old-state
      }
      # if neighbors = 3, cell quickens to life
      {
        compare n, 3
        break-if-!=
        set self, x, y, 1/live
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  flush self
}

fn num-live-neighbors _self: (addr environment), x: int, y: int -> _/eax: int {
  var self/esi: (addr environment) <- copy _self
  var result/edi: int <- copy 0
  # row above: zig
  decrement y
  decrement x
  var s/eax: boolean <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  # curr row: zag
  increment y
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  subtract-from x, 2
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  # row below: zig
  increment y
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state self, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  return result
}

fn linger _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var i/ecx: int <- copy 0
  {
    compare i, 0x10000000  # Kartik's Linux with -enable-kvm
#?     compare i, 0x8000000  # Kartik's Mac with -accel tcg
    break-if->=
    i <- increment
    loop
  }
}

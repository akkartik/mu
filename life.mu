# Conway's Game of Life
#
# To build:
#   $ ./translate life.mu
# To run:
#   $ qemu-system-i386 disk.img

fn state _grid: (addr array boolean), x: int, y: int -> _/eax: boolean {
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
  var idx/eax: int <- copy y
  idx <- shift-left 8/log2width
  idx <- add x
  var grid/esi: (addr array boolean) <- copy _grid
  var result/eax: (addr boolean) <- index grid, idx
  return *result
}

fn set-state _grid: (addr array boolean), x: int, y: int, val: boolean {
  # don't bother checking bounds
  var idx/eax: int <- copy y
  idx <- shift-left 8/log2width
  idx <- add x
  var grid/esi: (addr array boolean) <- copy _grid
  var result/eax: (addr boolean) <- index grid, idx
  var src/ecx: boolean <- copy val
  copy-to *result, src
}

fn num-live-neighbors grid: (addr array boolean), x: int, y: int -> _/eax: int {
  var result/edi: int <- copy 0
  # row above: zig
  decrement y
  decrement x
  var s/eax: boolean <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  # curr row: zag
  increment y
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  subtract-from x, 2
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  # row below: zig
  increment y
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  increment x
  s <- state grid, x, y
  {
    compare s, 0/false
    break-if-=
    result <- increment
  }
  return result
}

fn step old-grid: (addr array boolean), new-grid: (addr array boolean) {
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0/height
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x100/width
      break-if->=
      var n/eax: int <- num-live-neighbors old-grid, x, y
      # if neighbors < 2, die of loneliness
      {
        compare n, 2
        break-if->=
        set-state new-grid, x, y, 0/dead
      }
      # if neighbors > 3, die of overcrowding
      {
        compare n, 3
        break-if-<=
        set-state new-grid, x, y, 0/dead
      }
      # if neighbors = 2, preserve state
      {
        compare n, 2
        break-if-!=
        var old-state/eax: boolean <- state old-grid, x, y
        set-state new-grid, x, y, old-state
      }
      # if neighbors = 3, cell quickens to life
      {
        compare n, 3
        break-if-!=
        set-state new-grid, x, y, 1/live
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

# color a square of size 'side' starting at x*side, y*side
fn render-square _x: int, _y: int, color: int {
  var y/edx: int <- copy _y
  y <- shift-left 2/log2side
  var side/ebx: int <- copy 1
  side <- shift-left 2/log2side
  var ymax/ecx: int <- copy y
  ymax <- add side
  {
    compare y, ymax
    break-if->=
    {
      var x/eax: int <- copy _x
      x <- shift-left 2/log2side
      var xmax/ecx: int <- copy x
      xmax <- add side
      {
        compare x, xmax
        break-if->=
        pixel-on-real-screen x, y, color
        x <- increment
        loop
      }
    }
    y <- increment
    loop
  }
}

fn render grid: (addr array boolean) {
  var y/ecx: int <- copy 0
  {
    compare y, 0xc0/height
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x100/width
      break-if->=
      var state/eax: boolean <- state grid, x, y
      compare state, 0/false
      {
        break-if-=
        render-square x, y, 3/cyan
      }
      compare state, 0/false
      {
        break-if-!=
        render-square x, y, 0/black
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn main {
#?   # allocate on the stack
#?   var grid1-storage: (array boolean 0xc000)  # width * height
#?   var grid1/esi: (addr array boolean) <- address grid1-storage
#?   var grid2-storage: (array boolean 0xc000)  # width * height
#?   var grid2/edi: (addr array boolean) <- address grid2-storage
  # allocate on the heap
  var grid1-storage: (handle array boolean)
  var grid1-ah/eax: (addr handle array boolean) <- address grid1-storage
  populate grid1-ah, 0xc000  # width * height
  var _grid1/eax: (addr array boolean) <- lookup *grid1-ah
  var grid1/esi: (addr array boolean) <- copy _grid1
  var grid2-storage: (handle array boolean)
  var grid2-ah/eax: (addr handle array boolean) <- address grid2-storage
  populate grid2-ah, 0xc000  # width * height
  var _grid2/eax: (addr array boolean) <- lookup *grid2-ah
  var grid2/edi: (addr array boolean) <- copy _grid2
  # initialize grid1
  set-state grid1, 0x80, 0x5f, 1/live
  set-state grid1, 0x81, 0x5f, 1/live
  set-state grid1, 0x7f, 0x60, 1/live
  set-state grid1, 0x80, 0x60, 1/live
  set-state grid1, 0x80, 0x61, 1/live
  # render grid1
  render grid1
  {
    var key/eax: byte <- read-key 0/keyboard
    compare key, 0
#?     loop-if-=  # press key to step
    break-if-!=  # press key to quit  # comment this out to run under bochs; I'm not sure why there's a newline in the keyboard buffer
    # iter: grid1 -> grid2
    step grid1, grid2
    render grid2
    # iter: grid2 -> grid1
    step grid2, grid1
    render grid1
    loop
  }
}

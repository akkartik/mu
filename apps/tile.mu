# Randomly tile from a given set of tiles

type tile {
  data: (handle array handle array int)
}

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # basic maze
  # 10 PRINT CHR$(205.5 + RND(1))
  # GOTO 10
#?   var tiles-storage: (array tile 2)
#?   var tiles/esi: (addr array tile) <- address tiles-storage
#?   set-tile tiles, 0/idx, 1 0 0, 0 1 0, 0 0 1
#?   set-tile tiles, 1/idx, 0 0 1, 0 1 0, 1 0 0

  # https://post.lurk.org/@paul/107425083075253587
  var tiles-storage: (array tile 0x62)
  var tiles/esi: (addr array tile) <- address tiles-storage
  set-tile tiles, 0x00/idx, 1 1 1, 0 1 0, 0 0 0
  set-tile tiles, 0x01/idx, 0 1 1, 1 1 0, 0 0 0
  set-tile tiles, 0x02/idx, 1 1 1, 1 0 1, 0 0 0
  set-tile tiles, 0x03/idx, 1 1 0, 0 1 1, 0 0 0
  set-tile tiles, 0x04/idx, 0 0 0, 1 1 1, 0 0 0
  set-tile tiles, 0x05/idx, 1 0 0, 1 1 1, 0 0 0
  set-tile tiles, 0x06/idx, 0 1 0, 1 1 1, 0 0 0
  set-tile tiles, 0x07/idx, 0 0 1, 1 1 1, 0 0 0
  set-tile tiles, 0x08/idx, 1 0 1, 1 1 1, 0 0 0
  set-tile tiles, 0x09/idx, 0 1 1, 1 1 0, 1 0 0
  set-tile tiles, 0x0a/idx, 0 1 1, 0 0 1, 1 0 0
  set-tile tiles, 0x0b/idx, 1 1 1, 0 0 1, 1 0 0
  set-tile tiles, 0x0c/idx, 1 1 1, 1 0 1, 1 0 0
  set-tile tiles, 0x0d/idx, 0 0 0, 1 1 1, 1 0 0
  set-tile tiles, 0x0e/idx, 1 0 0, 1 1 1, 1 0 0
  set-tile tiles, 0x0f/idx, 0 1 0, 1 1 1, 1 0 0
  set-tile tiles, 0x10/idx, 0 0 1, 1 1 1, 1 0 0
  set-tile tiles, 0x11/idx, 1 0 1, 1 1 1, 1 0 0
  set-tile tiles, 0x12/idx, 1 0 1, 0 0 0, 0 1 0
  set-tile tiles, 0x13/idx, 1 1 1, 0 0 0, 0 1 0
  set-tile tiles, 0x14/idx, 1 1 1, 0 1 0, 0 1 0
  set-tile tiles, 0x15/idx, 0 1 1, 1 1 0, 0 1 0
  set-tile tiles, 0x16/idx, 1 1 0, 0 1 1, 0 1 0
  set-tile tiles, 0x17/idx, 0 0 0, 1 1 1, 0 1 0
  set-tile tiles, 0x18/idx, 1 0 0, 1 1 1, 0 1 0
  set-tile tiles, 0x19/idx, 0 1 0, 1 1 1, 0 1 0
  set-tile tiles, 0x1a/idx, 0 0 1, 1 1 1, 0 1 0
  set-tile tiles, 0x1b/idx, 1 0 1, 1 1 1, 0 1 0
  set-tile tiles, 0x1c/idx, 1 0 1, 0 0 0, 1 1 0
  set-tile tiles, 0x1d/idx, 0 1 1, 0 0 0, 1 1 0
  set-tile tiles, 0x1e/idx, 1 1 1, 0 0 0, 1 1 0
  set-tile tiles, 0x1f/idx, 0 0 1, 1 0 0, 1 1 0
  set-tile tiles, 0x20/idx, 1 0 1, 1 0 0, 1 1 0
  set-tile tiles, 0x21/idx, 1 1 1, 1 0 0, 1 1 0
  set-tile tiles, 0x22/idx, 0 1 1, 0 1 0, 1 1 0
  set-tile tiles, 0x23/idx, 1 1 1, 0 1 0, 1 1 0
  set-tile tiles, 0x24/idx, 0 0 0, 0 1 1, 1 1 0
  set-tile tiles, 0x25/idx, 0 1 0, 0 1 1, 1 1 0
  set-tile tiles, 0x26/idx, 1 1 0, 0 1 1, 1 1 0
  set-tile tiles, 0x27/idx, 0 0 1, 0 1 1, 1 1 0
  set-tile tiles, 0x28/idx, 1 1 0, 1 0 0, 0 0 1
  set-tile tiles, 0x29/idx, 1 1 1, 1 0 0, 0 0 1
  set-tile tiles, 0x2a/idx, 1 1 1, 1 0 1, 0 0 1
  set-tile tiles, 0x2b/idx, 1 1 0, 0 1 1, 0 0 1
  set-tile tiles, 0x2c/idx, 0 0 0, 1 1 1, 0 0 1
  set-tile tiles, 0x2d/idx, 1 0 0, 1 1 1, 0 0 1
  set-tile tiles, 0x2e/idx, 0 1 0, 1 1 1, 0 0 1
  set-tile tiles, 0x2f/idx, 0 0 1, 1 1 1, 0 0 1
  set-tile tiles, 0x30/idx, 1 0 1, 1 1 1, 0 0 1
  set-tile tiles, 0x31/idx, 0 1 0, 0 0 0, 1 0 1
  set-tile tiles, 0x32/idx, 1 1 0, 0 0 0, 1 0 1
  set-tile tiles, 0x33/idx, 0 1 1, 0 0 0, 1 0 1
  set-tile tiles, 0x34/idx, 1 1 1, 0 0 0, 1 0 1
  set-tile tiles, 0x35/idx, 1 1 0, 1 0 0, 1 0 1
  set-tile tiles, 0x36/idx, 1 1 1, 1 0 0, 1 0 1
  set-tile tiles, 0x37/idx, 0 1 1, 0 0 1, 1 0 1
  set-tile tiles, 0x38/idx, 1 1 1, 0 0 1, 1 0 1
  set-tile tiles, 0x39/idx, 1 1 1, 1 0 1, 1 0 1
  set-tile tiles, 0x3a/idx, 0 0 0, 1 1 1, 1 0 1
  set-tile tiles, 0x3b/idx, 1 0 0, 1 1 1, 1 0 1
  set-tile tiles, 0x3c/idx, 0 1 0, 1 1 1, 1 0 1
  set-tile tiles, 0x3d/idx, 0 0 1, 1 1 1, 1 0 1
  set-tile tiles, 0x3e/idx, 1 0 1, 1 1 1, 1 0 1
  set-tile tiles, 0x3f/idx, 1 1 0, 0 0 0, 0 1 1
  set-tile tiles, 0x40/idx, 1 0 1, 0 0 0, 0 1 1
  set-tile tiles, 0x41/idx, 1 1 1, 0 0 0, 0 1 1
  set-tile tiles, 0x42/idx, 1 1 0, 0 1 0, 0 1 1
  set-tile tiles, 0x43/idx, 1 1 1, 0 1 0, 0 1 1
  set-tile tiles, 0x44/idx, 0 0 0, 1 1 0, 0 1 1
  set-tile tiles, 0x45/idx, 1 0 0, 1 1 0, 0 1 1
  set-tile tiles, 0x46/idx, 0 1 0, 1 1 0, 0 1 1
  set-tile tiles, 0x47/idx, 0 1 1, 1 1 0, 0 1 1
  set-tile tiles, 0x48/idx, 1 0 0, 0 0 1, 0 1 1
  set-tile tiles, 0x49/idx, 1 0 1, 0 0 1, 0 1 1
  set-tile tiles, 0x4a/idx, 1 1 1, 0 0 1, 0 1 1
  set-tile tiles, 0x4b/idx, 0 1 0, 0 0 0, 1 1 1
  set-tile tiles, 0x4c/idx, 1 1 0, 0 0 0, 1 1 1
  set-tile tiles, 0x4d/idx, 1 0 1, 0 0 0, 1 1 1
  set-tile tiles, 0x4e/idx, 0 1 1, 0 0 0, 1 1 1
  set-tile tiles, 0x4f/idx, 1 1 1, 0 0 0, 1 1 1
  set-tile tiles, 0x50/idx, 1 1 0, 1 0 0, 1 1 1
  set-tile tiles, 0x51/idx, 0 0 1, 1 0 0, 1 1 1
  set-tile tiles, 0x52/idx, 1 0 1, 1 0 0, 1 1 1
  set-tile tiles, 0x53/idx, 1 1 1, 1 0 0, 1 1 1
  set-tile tiles, 0x54/idx, 0 0 0, 0 1 0, 1 1 1
  set-tile tiles, 0x55/idx, 0 1 0, 0 1 0, 1 1 1
  set-tile tiles, 0x56/idx, 1 1 0, 0 1 0, 1 1 1
  set-tile tiles, 0x57/idx, 0 1 1, 0 1 0, 1 1 1
  set-tile tiles, 0x58/idx, 1 1 1, 0 1 0, 1 1 1
  set-tile tiles, 0x59/idx, 1 0 0, 0 0 1, 1 1 1
  set-tile tiles, 0x5a/idx, 1 0 1, 0 0 1, 1 1 1
  set-tile tiles, 0x5b/idx, 0 1 1, 0 0 1, 1 1 1
  set-tile tiles, 0x5c/idx, 1 1 1, 0 0 1, 1 1 1
  set-tile tiles, 0x5d/idx, 0 0 0, 1 0 1, 1 1 1
  set-tile tiles, 0x5e/idx, 1 0 0, 1 0 1, 1 1 1
  set-tile tiles, 0x5f/idx, 0 0 1, 1 0 1, 1 1 1
  set-tile tiles, 0x60/idx, 1 0 1, 1 0 1, 1 1 1
  set-tile tiles, 0x61/idx, 1 1 1, 1 0 1, 1 1 1

  render-tiles screen, tiles
  {
    var key/eax: byte <- read-key keyboard
    compare key, 0
    loop-if-=
  }
  var step/eax: int <- copy 0
  {
    render-random screen, tiles, 0xc/pixels-per-tile, step
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
    }
    step <- increment
    loop
  }
}

fn set-tile _tiles: (addr array tile), _idx: int, n0: int, n1: int, n2: int, n3: int, n4: int, n5: int, n6: int, n7: int, n8: int {
  var tiles/eax: (addr array tile) <- copy _tiles
  var idx/ecx: int <- copy _idx
  var tile/edi: (addr tile) <- index tiles, idx
  var rows-ah/eax: (addr handle array handle array int) <- get tile, data
  populate rows-ah, 3
  var _rows/eax: (addr array handle array int) <- lookup *rows-ah
  var rows/edi: (addr array handle array int) <- copy _rows
  var row0-ah/eax: (addr handle array int) <- index rows, 0
  populate row0-ah, 3
  var row0/eax: (addr array int) <- lookup *row0-ah
  var x0/ecx: (addr int) <- index row0, 0
  var src/esi: int <- copy n0
  copy-to *x0, src
  var x1/ecx: (addr int) <- index row0, 1
  var src/esi: int <- copy n1
  copy-to *x1, src
  var x2/ecx: (addr int) <- index row0, 2
  var src/esi: int <- copy n2
  copy-to *x2, src
  var row1-ah/eax: (addr handle array int) <- index rows, 1
  populate row1-ah, 3
  var row1/eax: (addr array int) <- lookup *row1-ah
  var x3/ecx: (addr int) <- index row1, 0
  var src/esi: int <- copy n3
  copy-to *x3, src
  var x4/ecx: (addr int) <- index row1, 1
  var src/esi: int <- copy n4
  copy-to *x4, src
  var x5/ecx: (addr int) <- index row1, 2
  var src/esi: int <- copy n5
  copy-to *x5, src
  var row2-ah/eax: (addr handle array int) <- index rows, 2
  populate row2-ah, 3
  var row2/eax: (addr array int) <- lookup *row2-ah
  var x6/ecx: (addr int) <- index row2, 0
  var src/esi: int <- copy n6
  copy-to *x6, src
  var x7/ecx: (addr int) <- index row2, 1
  var src/esi: int <- copy n7
  copy-to *x7, src
  var x8/ecx: (addr int) <- index row2, 2
  var src/esi: int <- copy n8
  copy-to *x8, src
}

fn render-tiles screen: (addr screen), _tiles: (addr array tile) {
  draw-rect screen, 0 0, 0x400 0x300, 8
  var tiles/esi: (addr array tile) <- copy _tiles
  var num-tiles: int
  var tmp/eax: int <- length tiles
  copy-to num-tiles, tmp
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, num-tiles, 0x31, 0
  var i/ecx: int <- copy 0
  {
    compare i, num-tiles
    break-if->=
#?     draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, i, 0x31, 0
    var tile/eax: (addr tile) <- index tiles, i
    var start-x/edx: int <- copy i
    start-x <- and 0xf  # 16 cells per row
    start-x <- shift-left 4/pixels-per-cell
    start-x <- add 0x20/left-margin
    var start-y/ebx: int <- copy i
    start-y <- shift-right 4  # 16 cells per row
    start-y <- shift-left 4/pixels-per-cell
    start-y <- add 0x20/top-margin
#?     draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, start-x, 0x31, 0
    render-tile screen, tile, start-x, start-y, 4/pixels-per-cell  # 4 * 3 + 4 = 16 pixels wide
    i <- increment
    loop
  }
}

fn render-tile screen: (addr screen), _tile: (addr tile), start-x: int, start-y: int, n: int {
  var tile/esi: (addr tile) <- copy _tile
  var y/ecx: int <- copy start-y
  y <- add 4/margin-top
  var rows-ah/eax: (addr handle array handle array int) <- get tile, data
  var rows/eax: (addr array handle array int) <- lookup *rows-ah
  var i/ebx: int <- copy 0
  {
    compare i, 3
    break-if->=
    var x/edx: int <- copy start-x
    x <- add 4/margin-left
    var curr-row-ah/eax: (addr handle array int) <- index rows, i
    var curr-row/eax: (addr array int) <- lookup *curr-row-ah
    var j/edi: int <- copy 0
    {
      compare j, 3
      break-if->=
      var curr/eax: (addr int) <- index curr-row, j
      var color/eax: int <- copy *curr
      color <- shift-left 1
      draw-rect2 screen, x y, n n, color
      j <- increment
      x <- add n
      loop
    }
    i <- increment
    y <- add n
    loop
  }
}

fn render-random screen: (addr screen), _tiles: (addr array tile), n: int, seed: int {
  draw-rect screen, 0 0, 0x400 0x300, 8
  var tiles/esi: (addr array tile) <- copy _tiles
  var rand/edi: int <- next-random seed
  var num-tiles/ebx: int <- length tiles
  var y/ecx: int <- copy 0
  {
    compare y, 0x300
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x400
      break-if->=
      var i/eax: int <- remainder rand, num-tiles
      var tile/eax: (addr tile) <- index tiles, i
      render-tile-without-margin screen, tile, x, y, 4/pixels-per-cell
      x <- add n
      rand <- next-random rand
      loop
    }
    y <- add n
    loop
  }
}

fn render-tile-without-margin screen: (addr screen), _tile: (addr tile), start-x: int, start-y: int, n: int {
  var tile/esi: (addr tile) <- copy _tile
  var y/ecx: int <- copy start-y
  var rows-ah/eax: (addr handle array handle array int) <- get tile, data
  var rows/eax: (addr array handle array int) <- lookup *rows-ah
  var i/ebx: int <- copy 0
  {
    compare i, 3
    break-if->=
    var x/edx: int <- copy start-x
    var curr-row-ah/eax: (addr handle array int) <- index rows, i
    var curr-row/eax: (addr array int) <- lookup *curr-row-ah
    var j/edi: int <- copy 0
    {
      compare j, 3
      break-if->=
      var curr/eax: (addr int) <- index curr-row, j
      var color/eax: int <- copy *curr
      color <- shift-left 1
      draw-rect2 screen, x y, n n, color
      j <- increment
      x <- add n
      loop
    }
    i <- increment
    y <- add n
    loop
  }
}

fn remainder a: int, b: int -> _/eax: int {
  var q/eax: int <- copy 0
  var r/edx: int <- copy 0
  q, r <- integer-divide a, b
  return r
}

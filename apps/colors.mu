# Return colors 'near' a given r/g/b value (expressed in hex)
# If we did this rigorously we'd need to implement cosines. So we won't.
#
# To build:
#   $ ./translate apps/colors.mu
#
# Example session:
#   $ qemu-system-i386 code.img
#   Enter 3 hex bytes for r, g, b (lowercase; no 0x prefix) separated by a single space> aa 0 aa
#   5
# This means only color 5 in the default palette is similar to #aa00aa.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var in-storage: (stream byte 0x10)
  var in/esi: (addr stream byte) <- address in-storage
  {
    # print prompt
    var x/eax: int <- draw-text-rightward screen, "Enter 3 hex bytes for r, g, b (lowercase; no 0x prefix) separated by a single space> ", 0x10/x, 0x80/xmax, 0x28/y, 3/fg/cyan, 0/bg
    # read line from keyboard
    clear-stream in
    {
      draw-cursor screen, 0x20/space
      var key/eax: byte <- read-key keyboard
      compare key, 0xa/newline
      break-if-=
      compare key, 0
      loop-if-=
      var key2/eax: int <- copy key
      append-byte in, key2
      var c/eax: code-point <- copy key2  # TODO: unicode input
      draw-code-point-at-cursor-over-full-screen screen, c, 0xf/fg, 0/bg
      loop
    }
    clear-screen screen
    # parse
    var a/ecx: int <- copy 0
    var b/edx: int <- copy 0
    var c/ebx: int <- copy 0
    # a, b, c = r, g, b
    a, b, c <- parse in
#?     set-cursor-position screen, 0x10/x, 0x1a/y
#?     draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, a, 7/fg, 0/bg
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?     draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, b, 7/fg, 0/bg
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?     draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, c, 7/fg, 0/bg
    a, b, c <- hsl a, b, c
    # return all colors in the same quadrant in h, s and l
    print-nearby-colors screen, a, b, c
    # another metric
    var color/eax: int <- nearest-color-euclidean-hsl a, b, c
    set-cursor-position screen, 0x10/x, 0x26/y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "nearest (euclidean, h/s/l): ", 0xf/fg, 0/bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, color, 7/fg, 0/bg
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 0xf/fg, 0/bg
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "               ", 0/fg, color
    #
    loop
  }
}

# read exactly 3 words in a single line
# Each word consists of exactly 1 or 2 hex bytes. No hex prefix.
fn parse in: (addr stream byte) -> _/ecx: int, _/edx: int, _/ebx: int {
  # read first byte of r
  var tmp/eax: byte <- read-byte in
  {
    var valid?/eax: boolean <- hex-digit? tmp
    compare valid?, 0/false
    break-if-!=
    abort "invalid byte 0 of r"
  }
  tmp <- fast-hex-digit-value tmp
  var r/ecx: int <- copy tmp
#?   set-cursor-position 0/screen, 0x10/x, 0x10/y
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, r, 7/fg, 0/bg
  # read second byte of r
  tmp <- read-byte in
  {
    {
      var valid?/eax: boolean <- hex-digit? tmp
      compare valid?, 0/false
    }
    break-if-=
    r <- shift-left 4
    tmp <- fast-hex-digit-value tmp
#?     {
#?       var foo/eax: int <- copy tmp
#?       set-cursor-position 0/screen, 0x10/x, 0x11/y
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 7/fg, 0/bg
#?     }
    r <- add tmp
#?     {
#?       set-cursor-position 0/screen, 0x10/x, 0x12/y
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, r, 7/fg, 0/bg
#?     }
    tmp <- read-byte in  # skip space
  }
  # read first byte of g
  var tmp/eax: byte <- read-byte in
  {
    var valid?/eax: boolean <- hex-digit? tmp
    compare valid?, 0/false
    break-if-!=
    abort "invalid byte 0 of g"
  }
  tmp <- fast-hex-digit-value tmp
  var g/edx: int <- copy tmp
#?   set-cursor-position 0/screen, 0x10/x, 0x13/y
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, g, 7/fg, 0/bg
  # read second byte of g
  tmp <- read-byte in
  {
    {
      var valid?/eax: boolean <- hex-digit? tmp
      compare valid?, 0/false
    }
    break-if-=
    g <- shift-left 4
    tmp <- fast-hex-digit-value tmp
#?     {
#?       var foo/eax: int <- copy tmp
#?       set-cursor-position 0/screen, 0x10/x, 0x14/y
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 7/fg, 0/bg
#?     }
    g <- add tmp
#?     {
#?       set-cursor-position 0/screen, 0x10/x, 0x15/y
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, g, 7/fg, 0/bg
#?     }
    tmp <- read-byte in  # skip space
  }
  # read first byte of b
  var tmp/eax: byte <- read-byte in
  {
    var valid?/eax: boolean <- hex-digit? tmp
    compare valid?, 0/false
    break-if-!=
    abort "invalid byte 0 of b"
  }
  tmp <- fast-hex-digit-value tmp
  var b/ebx: int <- copy tmp
#?   set-cursor-position 0/screen, 0x10/x, 0x16/y
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, b, 7/fg, 0/bg
  # read second byte of b
  {
    {
      var done?/eax: boolean <- stream-empty? in
      compare done?, 0/false
    }
    break-if-!=
    tmp <- read-byte in
    {
      var valid?/eax: boolean <- hex-digit? tmp
      compare valid?, 0/false
    }
    break-if-=
    b <- shift-left 4
    tmp <- fast-hex-digit-value tmp
#?     {
#?       var foo/eax: int <- copy tmp
#?       set-cursor-position 0/screen, 0x10/x, 0x17/y
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 7/fg, 0/bg
#?     }
    b <- add tmp
#?     {
#?       set-cursor-position 0/screen, 0x10/x, 0x18/y
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, b, 7/fg, 0/bg
#?     }
  }
  return r, g, b
}

# no error checking
fn fast-hex-digit-value in: byte -> _/eax: byte {
  var result/eax: byte <- copy in
  compare result, 0x39
  {
    break-if->
    result <- subtract 0x30/0
    return result
  }
  result <- subtract 0x61/a
  result <- add 0xa/10
  return result
}

fn print-nearby-colors screen: (addr screen), h: int, s: int, l: int {
#?   set-cursor-position screen, 0x10/x, 0x1c/y
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, h, 7/fg, 0/bg
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, s, 7/fg, 0/bg
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, l, 7/fg, 0/bg
  # save just top 2 bits of each, so that we narrow down to 1/64th of the volume
  shift-right h, 6
  shift-right s, 6
  shift-right l, 6
#?   set-cursor-position screen, 0x10/x, 0x1/y
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, h, 7/fg, 0/bg
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, s, 7/fg, 0/bg
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?   draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, l, 7/fg, 0/bg
  var a/ecx: int <- copy 0
  var b/edx: int <- copy 0
  var c/ebx: int <- copy 0
  var color/eax: int <- copy 0
  var y/esi: int <- copy 2
  {
    compare color, 0x100
    break-if->=
    a, b, c <- color-rgb color
    a, b, c <- hsl a, b, c
    a <- shift-right 6
    b <- shift-right 6
    c <- shift-right 6
    {
      compare a, h
      break-if-!=
      compare b, s
      break-if-!=
      compare c, l
      break-if-!=
      set-cursor-position screen, 0x10/x, y
      draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, color, 7/fg, 0/bg
      set-cursor-position screen, 0x14/x, y
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "               ", 0/fg, color
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, a, 7/fg, 0/bg
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, b, 7/fg, 0/bg
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, " ", 7/fg, 0/bg
#?       draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen, c, 7/fg, 0/bg
      y <- increment
    }
    color <- increment
    loop
  }
}

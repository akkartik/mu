# load an image from disk and display it on screen

type image {
  width: int
  height: int
  data: (handle array byte)
}

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var img-storage: image
  var img/esi: (addr image) <- address img-storage
  load-image img, data-disk
  render-image screen, img, 0x20/x 0x80/y
}

fn load-image self: (addr image), data-disk: (addr disk) {
  # data-disk -> stream
  var s-storage: (stream byte 0x40000)  # 512 sectors
  var s/ebx: (addr stream byte) <- address s-storage
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sectors from data disk", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  load-sectors data-disk, 0/lba, 0x100/sectors, s
  load-sectors data-disk, 0x100/lba, 0x100/sectors, s
  # stream -> gap-buffer (HACK: we temporarily cannibalize the sandbox's gap-buffer)
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "parsing", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  initialize-image-from-pgm self, s
}

# import a black-and-white ascii bitmap
fn initialize-image-from-pbm _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var curr-word-storage: slice
  var curr-word/ecx: (addr slice) <- address curr-word-storage
  next-word in, curr-word   # skip 'P1'
  next-word in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
  var dest/eax: (addr int) <- get self, width
  copy-to *dest, width
  dest <- get self, height
  copy-to *dest, height
  var capacity/edx: int <- copy width
  capacity <- multiply height
  var data-ah/edi: (addr handle array byte) <- get self, data
  populate data-ah, capacity
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data/edi: (addr array byte) <- copy _data
  var i/ebx: int <- copy 0
  {
    compare i, capacity
    break-if->=
    next-word in, curr-word
    var src/eax: int <- parse-decimal-int-from-slice curr-word
    {
      var dest/ecx: (addr byte) <- index data, i
      copy-byte-to *dest, src
    }
    i <- increment
    loop
  }
}

# import a greyscale ascii bitmap
fn initialize-image-from-pgm _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var curr-word-storage: slice
  var curr-word/ecx: (addr slice) <- address curr-word-storage
  next-word in, curr-word   # skip 'P2'
  next-word in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, width, 3/fg 0/bg
  next-word in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, height, 4/fg 0/bg
  next-word in, curr-word   # skip levels of grey
  var dest/eax: (addr int) <- get self, width
  copy-to *dest, width
  dest <- get self, height
  copy-to *dest, height
  var capacity/edx: int <- copy width
  capacity <- multiply height
  var data-ah/edi: (addr handle array byte) <- get self, data
  populate data-ah, capacity
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data/edi: (addr array byte) <- copy _data
  var i/ebx: int <- copy 0
  {
    compare i, capacity
    break-if->=
    next-word in, curr-word
    var src/eax: int <- parse-decimal-int-from-slice curr-word
    {
      var dest/ecx: (addr byte) <- index data, i
      copy-byte-to *dest, src
    }
    i <- increment
    loop
  }
}

fn render-image screen: (addr screen), _self: (addr image), xmin: int, ymin: int {
  var self/esi: (addr image) <- copy _self
  var width-a/ecx: (addr int) <- get self, width
  var data-ah/eax: (addr handle array byte) <- get self, data
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data/esi: (addr array byte) <- copy _data
  var y/edx: int <- copy ymin
  var i/edi: int <- copy 0
  var max/eax: int <- length data
  {
    compare i, max
    break-if->=
    var x/ebx: int <- copy xmin
    var i2/eax: int <- copy 0
    {
      compare i2, *width-a
      break-if->=
      {
        var src-a/eax: (addr byte) <- index data, i
        var src/eax: byte <- copy-byte *src-a
        var src-int/eax: int <- copy src
#?         set-cursor-position-on-real-screen 0x40/x 0/y
#?         draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, src-int, 4/fg 0/bg
        pixel screen, x, y, src-int
      }
      x <- increment
      i <- increment
      i2 <- increment
      loop
    }
    y <- increment
    loop
  }
}

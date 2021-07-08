# load an image from disk and display it on screen

type image {
  type: int  # supported types:
             #  1: portable bitmap (P1) - pixels 0 or 1
             #  2: portable greymap (P2) - pixels 1-byte greyscale values
             #  3: portable pixmap (P3) - pixels 3-byte rgb values
  max: int
  width: int
  height: int
  data: (handle array byte)
}

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var img-storage: image
  var img/esi: (addr image) <- address img-storage
  load-image img, data-disk
  render-image screen, img, 0x20/x 0x80/y, 0x100/width, 0x100/height
  render-image screen, img, 0x120/x 0x180/y, 0x12c/width=300, 0xc8/height=200
  render-image screen, img, 0x320/x 0x280/y, 0x60/width=96, 0x1c/height=28
}

fn load-image self: (addr image), data-disk: (addr disk) {
  # data-disk -> stream
  var s-storage: (stream byte 0xc0000)  # 512*3 sectors
  var s/ebx: (addr stream byte) <- address s-storage
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sectors from data disk", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  load-sectors data-disk, 0/lba, 0x100/sectors, s
  load-sectors data-disk, 0x100/lba, 0x100/sectors, s
  load-sectors data-disk, 0x200/lba, 0x100/sectors, s
  load-sectors data-disk, 0x300/lba, 0x100/sectors, s
  load-sectors data-disk, 0x400/lba, 0x100/sectors, s
  load-sectors data-disk, 0x500/lba, 0x100/sectors, s
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "parsing", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  initialize-image self, s
}

fn initialize-image _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var mode-storage: slice
  var mode/ecx: (addr slice) <- address mode-storage
  next-word in, mode
  {
    var P1?/eax: boolean <- slice-equal? mode, "P1"
    compare P1?, 0/false
    break-if-=
    var type-a/eax: (addr int) <- get self, type
    copy-to *type-a, 1/ppm
    initialize-image-from-pbm self, in
    return
  }
  {
    var P2?/eax: boolean <- slice-equal? mode, "P2"
    compare P2?, 0/false
    break-if-=
    var type-a/eax: (addr int) <- get self, type
    copy-to *type-a, 2/pgm
    initialize-image-from-pgm self, in
    return
  }
  {
    var P3?/eax: boolean <- slice-equal? mode, "P3"
    compare P3?, 0/false
    break-if-=
    var type-a/eax: (addr int) <- get self, type
    copy-to *type-a, 3/ppm
    initialize-image-from-ppm self, in
    return
  }
  abort "initialize-image: unrecognized image type"
}

# import a black-and-white ascii bitmap
fn initialize-image-from-pbm _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var curr-word-storage: slice
  var curr-word/ecx: (addr slice) <- address curr-word-storage
  # load width, height
  next-word in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
  # save width, height
  var dest/eax: (addr int) <- get self, width
  copy-to *dest, width
  dest <- get self, height
  copy-to *dest, height
  # initialize data
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

# import a greyscale ascii "greymap"
fn initialize-image-from-pgm _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var curr-word-storage: slice
  var curr-word/ecx: (addr slice) <- address curr-word-storage
  # load width, height
  next-word in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
  # check and save color levels
  next-word in, curr-word
  {
    tmp <- parse-decimal-int-from-slice curr-word
    compare tmp, 0xff
    break-if-<=
    abort "initialize-image-from-pgm: no more than 255 levels of grey"
  }
  var dest/edi: (addr int) <- get self, max
  copy-to *dest, tmp
  # save width, height
  dest <- get self, width
  copy-to *dest, width
  dest <- get self, height
  copy-to *dest, height
  # initialize data
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

# import a color ascii "pixmap"
fn initialize-image-from-ppm _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var curr-word-storage: slice
  var curr-word/ecx: (addr slice) <- address curr-word-storage
  # load width, height
  next-word in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
  next-word in, curr-word
  # check color levels
  {
    tmp <- parse-decimal-int-from-slice curr-word
    compare tmp, 0xff
    break-if-=
    abort "initialize-image-from-ppm: supports exactly 255 levels per rgb channel"
  }
  var dest/edi: (addr int) <- get self, max
  copy-to *dest, tmp
  # save width, height
  dest <- get self, width
  copy-to *dest, width
  dest <- get self, height
  copy-to *dest, height
  # initialize data
  var capacity/edx: int <- copy width
  capacity <- multiply height
  # . multiply by 3 for the r/g/b channels
  var tmp/eax: int <- copy capacity
  tmp <- shift-left 1
  capacity <- add tmp
  #
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

# dispatch to a few variants with mostly identical boilerplate
fn render-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int {
  var img/esi: (addr image) <- copy _img
  var type-a/eax: (addr int) <- get img, type
  {
    compare *type-a, 1/pbm
    break-if-!=
    render-pbm-image screen, img, xmin, ymin, width, height
    return
  }
  {
    compare *type-a, 2/pgm
    break-if-!=
    render-pgm-image screen, img, xmin, ymin, width, height
    return
  }
  {
    compare *type-a, 3/ppm
    break-if-!=
    render-ppm-image screen, img, xmin, ymin, width, height
    return
  }
  abort "render-image: unrecognized image type"
}

# portable bitmap: each pixel is 0 or 1
fn render-pbm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int {
  var img/esi: (addr image) <- copy _img
  # yratio = height/img->height
  var img-height-a/eax: (addr int) <- get img, height
  var img-height/xmm0: float <- convert *img-height-a
  var yratio/xmm1: float <- convert height
  yratio <- divide img-height
  # xratio = width/img->width
  var img-width-a/eax: (addr int) <- get img, width
  var img-width/ebx: int <- copy *img-width-a
  var img-width-f/xmm0: float <- convert img-width
  var xratio/xmm2: float <- convert width
  xratio <- divide img-width-f
  # esi = img->data
  var img-data-ah/eax: (addr handle array byte) <- get img, data
  var _img-data/eax: (addr array byte) <- lookup *img-data-ah
  var img-data/esi: (addr array byte) <- copy _img-data
  var len/edi: int <- length img-data
  #
  var one/eax: int <- copy 1
  var one-f/xmm3: float <- convert one
  var width-f/xmm4: float <- convert width
  var height-f/xmm5: float <- convert height
  var zero/eax: int <- copy 0
  var zero-f/xmm0: float <- convert zero
  var y/xmm6: float <- copy zero-f
  set-cursor-position 0/screen, 0x20/x 0x20/y
  {
    compare y, height-f
    break-if-float>=
    var imgy-f/xmm5: float <- copy y
    imgy-f <- divide yratio
    var imgy/edx: int <- truncate imgy-f
    var x/xmm7: float <- copy zero-f
    {
      compare x, width-f
      break-if-float>=
      var imgx-f/xmm5: float <- copy x
      imgx-f <- divide xratio
      var imgx/ecx: int <- truncate imgx-f
      var idx/eax: int <- copy imgy
      {
        compare idx, 0
        break-if-<=
        idx <- decrement
        idx <- multiply img-width
      }
      idx <- add imgx
      # error info in case we rounded wrong and 'index' will fail bounds-check
      compare idx, len
      {
        break-if-<
        set-cursor-position 0/screen, 0x20/x 0x20/y
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, imgx, 3/fg 0/bg
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, imgy, 4/fg 0/bg
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, idx, 5/fg 0/bg
      }
      var src-a/eax: (addr byte) <- index img-data, idx
      var src/eax: byte <- copy-byte *src-a
      var color-int/eax: int <- copy src
      {
        compare color-int, 0/black
        break-if-=
        color-int <- copy 0xf/white
      }
      var screenx/ecx: int <- convert x
      screenx <- add xmin
      var screeny/edx: int <- convert y
      screeny <- add ymin
      pixel screen, screenx, screeny, color-int
      x <- add one-f
      loop
    }
    y <- add one-f
    loop
  }
}

# portable greymap: each pixel is a shade of grey from 0 to 255
fn render-pgm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int {
  var img/esi: (addr image) <- copy _img
  # yratio = height/img->height
  var img-height-a/eax: (addr int) <- get img, height
  var img-height/xmm0: float <- convert *img-height-a
  var yratio/xmm1: float <- convert height
  yratio <- divide img-height
  # xratio = width/img->width
  var img-width-a/eax: (addr int) <- get img, width
  var img-width/ebx: int <- copy *img-width-a
  var img-width-f/xmm0: float <- convert img-width
  var xratio/xmm2: float <- convert width
  xratio <- divide img-width-f
  # esi = img->data
  var img-data-ah/eax: (addr handle array byte) <- get img, data
  var _img-data/eax: (addr array byte) <- lookup *img-data-ah
  var img-data/esi: (addr array byte) <- copy _img-data
  var len/edi: int <- length img-data
  #
  var one/eax: int <- copy 1
  var one-f/xmm3: float <- convert one
  var width-f/xmm4: float <- convert width
  var height-f/xmm5: float <- convert height
  var zero/eax: int <- copy 0
  var zero-f/xmm0: float <- convert zero
  var y/xmm6: float <- copy zero-f
  set-cursor-position 0/screen, 0x20/x 0x20/y
  {
    compare y, height-f
    break-if-float>=
    var imgy-f/xmm5: float <- copy y
    imgy-f <- divide yratio
    var imgy/edx: int <- truncate imgy-f
    var x/xmm7: float <- copy zero-f
    {
      compare x, width-f
      break-if-float>=
      var imgx-f/xmm5: float <- copy x
      imgx-f <- divide xratio
      var imgx/ecx: int <- truncate imgx-f
      var idx/eax: int <- copy imgy
      {
        compare idx, 0
        break-if-<=
        idx <- decrement
        idx <- multiply img-width
      }
      idx <- add imgx
      # error info in case we rounded wrong and 'index' will fail bounds-check
      compare idx, len
      {
        break-if-<
        set-cursor-position 0/screen, 0x20/x 0x20/y
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, imgx, 3/fg 0/bg
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, imgy, 4/fg 0/bg
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, idx, 5/fg 0/bg
      }
      var src-a/eax: (addr byte) <- index img-data, idx
      var src/eax: byte <- copy-byte *src-a
      var color-int/eax: int <- nearest-grey src
      var screenx/ecx: int <- convert x
      screenx <- add xmin
      var screeny/edx: int <- convert y
      screeny <- add ymin
      pixel screen, screenx, screeny, color-int
      x <- add one-f
      loop
    }
    y <- add one-f
    loop
  }
}

fn nearest-grey level-255: byte -> _/eax: int {
  var result/eax: int <- copy level-255
  result <- shift-right 4
  result <- add 0x10
  return result
}

fn render-ppm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int {
  var img/esi: (addr image) <- copy _img
  var img-width-a/ecx: (addr int) <- get img, width
  var data-ah/eax: (addr handle array byte) <- get img, data
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data/esi: (addr array byte) <- copy _data
  var y/edx: int <- copy ymin
  var i/edi: int <- copy 0
  var max/eax: int <- length data
  {
    compare i, max
    break-if->=
    var x/ebx: int <- copy xmin
    var img-x/eax: int <- copy 0
    {
      compare img-x, *img-width-a
      break-if->=
      # r channel
      var r: int
      {
        var src-a/eax: (addr byte) <- index data, i
        var src/eax: byte <- copy-byte *src-a
        copy-to r, src
      }
      i <- increment
      # g channel
      var g: int
      {
        var src-a/eax: (addr byte) <- index data, i
        var src/eax: byte <- copy-byte *src-a
        copy-to g, src
      }
      i <- increment
      # b channel
      var b: int
      {
        var src-a/eax: (addr byte) <- index data, i
        var src/eax: byte <- copy-byte *src-a
        copy-to b, src
      }
      i <- increment
      #
      var color: int
      {
        var h/ecx: int <- copy 0
        var s/edx: int <- copy 0
        var l/ebx: int <- copy 0
        h, s, l <- hsl r, g, b
        var tmp/eax: int <- nearest-color-euclidean-hsl h, s, l
        copy-to color, tmp
      }
      pixel screen, x, y, color
      #
      x <- increment
      img-x <- increment
      loop
    }
    y <- increment
    loop
  }
}

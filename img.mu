# load an image from disk and display it on screen
#
# To build:
#   $ ./translate shell/*.mu                        # generates code.img
# Load a pbm, pgm or ppm image (no more than 255 levels)
#   $ dd if=/dev/zero of=data.img count=20160
#   $ cat x.pbm |dd of=data.img conv=notrunc
# or
#   $ cat t.pgm |dd of=data.img conv=notrunc
# or
#   $ cat snail.ppm |dd of=data.img conv=notrunc
# To run:
#   $ qemu-system-i386 -hda code.img -hdb data.img

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
  render-image screen, img, 0/x, 0xd0/y, 0x12c/width=300, 0xc8/height=200
  render-pgm-image screen, img, 0x140/x, 0/y, 0x12c/width=300, 0xc8/height=200
}

fn load-image self: (addr image), data-disk: (addr disk) {
  # data-disk -> stream
  var s-storage: (stream byte 0x200000)  # 512* 0x1000 sectors
  var s/ebx: (addr stream byte) <- address s-storage
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sectors from data disk", 3/fg, 0/bg
#?   move-cursor-to-left-margin-of-next-line 0/screen
  load-sectors data-disk, 0/lba, 0x100/sectors, s
  load-sectors data-disk, 0x100/lba, 0x100/sectors, s
  load-sectors data-disk, 0x200/lba, 0x100/sectors, s
  load-sectors data-disk, 0x300/lba, 0x100/sectors, s
  load-sectors data-disk, 0x400/lba, 0x100/sectors, s
  load-sectors data-disk, 0x500/lba, 0x100/sectors, s
  load-sectors data-disk, 0x600/lba, 0x100/sectors, s
  load-sectors data-disk, 0x700/lba, 0x100/sectors, s
  load-sectors data-disk, 0x800/lba, 0x100/sectors, s
  load-sectors data-disk, 0x900/lba, 0x100/sectors, s
  load-sectors data-disk, 0xa00/lba, 0x100/sectors, s
  load-sectors data-disk, 0xb00/lba, 0x100/sectors, s
  load-sectors data-disk, 0xc00/lba, 0x100/sectors, s
  load-sectors data-disk, 0xd00/lba, 0x100/sectors, s
  load-sectors data-disk, 0xe00/lba, 0x100/sectors, s
  load-sectors data-disk, 0xf00/lba, 0x100/sectors, s
#?   draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "parsing", 3/fg, 0/bg
#?   move-cursor-to-left-margin-of-next-line 0/screen
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
    var img2-storage: image
    var img2/edi: (addr image) <- address img2-storage
    dither-pgm-unordered img, img2
    render-raw-image screen, img2, xmin, ymin, width, height
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

## helpers

# import a black-and-white ascii bitmap (each pixel is 0 or 1)
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

# render a black-and-white ascii bitmap (each pixel is 0 or 1)
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
      idx <- multiply img-width
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

# import a greyscale ascii "greymap" (each pixel is a shade of grey from 0 to 255)
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

# render a greyscale ascii "greymap" (each pixel is a shade of grey from 0 to 255) by quantizing the shades
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
      idx <- multiply img-width
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

fn dither-pgm-unordered-monochrome _src: (addr image), _dest: (addr image) {
  var src/esi: (addr image) <- copy _src
  var dest/edi: (addr image) <- copy _dest
  # copy 'width'
  var src-width-a/eax: (addr int) <- get src, width
  var tmp/eax: int <- copy *src-width-a
  var src-width: int
  copy-to src-width, tmp
  {
    var dest-width-a/edx: (addr int) <- get dest, width
    copy-to *dest-width-a, tmp
  }
  # copy 'height'
  var src-height-a/eax: (addr int) <- get src, height
  var tmp/eax: int <- copy *src-height-a
  var src-height: int
  copy-to src-height, tmp
  {
    var dest-height-a/ecx: (addr int) <- get dest, height
    copy-to *dest-height-a, tmp
  }
  # transform 'data'
  var capacity/ebx: int <- copy src-width
  capacity <- multiply src-height
  var dest/edi: (addr image) <- copy _dest
  var dest-data-ah/eax: (addr handle array byte) <- get dest, data
  populate dest-data-ah, capacity
  var _dest-data/eax: (addr array byte) <- lookup *dest-data-ah
  var dest-data/edi: (addr array byte) <- copy _dest-data
  # needs a buffer to temporarily hold more than 256 levels of precision
  var errors-storage: (array int 0xc0000)
  var errors/ebx: (addr array int) <- address errors-storage
  var src-data-ah/eax: (addr handle array byte) <- get src, data
  var _src-data/eax: (addr array byte) <- lookup *src-data-ah
  var src-data/esi: (addr array byte) <- copy _src-data
  var y/edx: int <- copy 0
  {
    compare y, src-height
    break-if->=
#?     psd "y", y, 9/fg, 0/x, y
    var x/ecx: int <- copy 0
    {
      compare x, src-width
      break-if->=
#?       psd "x", x, 3/fg, x, y
      var curr/eax: byte <- _read-pgm-buffer src-data, x, y, src-width
      var curr-int/eax: int <- copy curr
      curr-int <- shift-left 0x10  # we have 32 bits; we'll use 16 bits for the fraction and leave 8 for unanticipated overflow
      var error/esi: int <- _read-dithering-error errors, x, y, src-width
      error <- add curr-int
      $_dither-pgm-unordered-monochrome:update-error: {
#?         psd "e", error, 5/fg, x, y
        compare error, 0x800000
        {
          break-if->=
#?           psd "p", 0, 0x14/fg, x, y
          _write-raw-buffer dest-data, x, y, src-width, 0/black
          break $_dither-pgm-unordered-monochrome:update-error
        }
#?         psd "p", 1, 0xf/fg, x, y
        _write-raw-buffer dest-data, x, y, src-width, 1/white
        error <- subtract 0xff0000
      }
      _diffuse-dithering-error-floyd-steinberg errors, x, y, src-width, src-height, error
      x <- increment
      loop
    }
    move-cursor-to-left-margin-of-next-line 0/screen
    y <- increment
    loop
  }
}

fn dither-pgm-unordered _src: (addr image), _dest: (addr image) {
  var src/esi: (addr image) <- copy _src
  var dest/edi: (addr image) <- copy _dest
  # copy 'width'
  var src-width-a/eax: (addr int) <- get src, width
  var tmp/eax: int <- copy *src-width-a
  var src-width: int
  copy-to src-width, tmp
  {
    var dest-width-a/edx: (addr int) <- get dest, width
    copy-to *dest-width-a, tmp
  }
  # copy 'height'
  var src-height-a/eax: (addr int) <- get src, height
  var tmp/eax: int <- copy *src-height-a
  var src-height: int
  copy-to src-height, tmp
  {
    var dest-height-a/ecx: (addr int) <- get dest, height
    copy-to *dest-height-a, tmp
  }
  # transform 'data'
  var capacity/ebx: int <- copy src-width
  capacity <- multiply src-height
  var dest/edi: (addr image) <- copy _dest
  var dest-data-ah/eax: (addr handle array byte) <- get dest, data
  populate dest-data-ah, capacity
  var _dest-data/eax: (addr array byte) <- lookup *dest-data-ah
  var dest-data/edi: (addr array byte) <- copy _dest-data
  # needs a buffer to temporarily hold more than 256 levels of precision
  var errors-storage: (array int 0xc0000)
  var errors/ebx: (addr array int) <- address errors-storage
  var src-data-ah/eax: (addr handle array byte) <- get src, data
  var _src-data/eax: (addr array byte) <- lookup *src-data-ah
  var src-data/esi: (addr array byte) <- copy _src-data
  var y/edx: int <- copy 0
  {
    compare y, src-height
    break-if->=
#?     set-cursor-position 0/screen, 0 0
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "y ", 3/fg 0/bg
#?     draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 3/fg 0/bg
    var x/ecx: int <- copy 0
    {
      compare x, src-width
      break-if->=
#?       psd "x", x, 3/fg, x, y
      var initial-color/eax: byte <- _read-pgm-buffer src-data, x, y, src-width
#?       {
#?         var foo/eax: int <- copy initial-color
#?         psd "r", foo, 7/fg, x, y
#?       }
      var error/esi: int <- _read-dithering-error errors, x, y, src-width
#?       {
#?         var foo/eax: int <- copy error
#?         foo <- shift-right-signed 0x10
#?         compare foo, 0xff
#?         break-if-<=
#?         pixel 0/screen x, y, 4/red
#?         set-cursor-position 0/screen, 0x28/x 0x10/y
#?         draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg 0/bg
#?         draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 4/fg 0/bg
#?         draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 5/fg 0/bg
#?         abort "error too high"
#?       }
#?       {
#?         var foo/eax: int <- copy error
#?         foo <- shift-right-signed 0x10
#?         psd "e", foo, 5/fg, x, y
#?       }
      # error += (initial-color << 16)
      {
        var tmp/eax: int <- copy initial-color
        tmp <- shift-left 0x10  # we have 32 bits; we'll use 16 bits for the fraction and leave 8 for unanticipated overflow
        error <- add tmp
      }
#?       {
#?         var foo/eax: int <- copy error
#?         foo <- shift-right-signed 0x10
#?         psd "f", foo, 5/fg, x, y
#?       }
      # nearest-color = nearest(error >> 16)
      var nearest-color/eax: int <- copy error
      nearest-color <- shift-right-signed 0x10
      {
        compare nearest-color, 0
        break-if->=
        nearest-color <- copy 0
      }
      {
        compare nearest-color, 0xff
        break-if-<=
        nearest-color <- copy 0xf0
      }
#?       {
#?         var foo/eax: int <- copy nearest-color
#?         psd "m", foo, 2/fg, x, y
#?       }
      # . round to nearest multiple of 0x10
      {
        var tmp/ecx: int <- copy nearest-color
        tmp <- and 0xf
        compare tmp, 8
        break-if-<
        nearest-color <- add 8
      }
      nearest-color <- and 0xf0
#?       {
#?         var foo/eax: int <- copy nearest-color
#?         psd "n", foo, 2/fg, x, y
#?       }
      # error -= (nearest-color << 16)
      {
        var tmp/eax: int <- copy nearest-color
        tmp <- shift-left 0x10
        error <- subtract tmp
      }
#?       {
#?         var foo/eax: int <- copy error
#?         foo <- shift-right-signed 0x10
#?         psd "g", foo, 3/fg, x, y
#?       }
      # color-index = (nearest-color >> 4 + 16)
      var color-index/eax: int <- copy nearest-color
      color-index <- shift-right 4
      color-index <- add 0x10
#?       psd "p", color-index, 4/fg, x, y
      var color-index-byte/eax: byte <- copy-byte color-index
      _write-raw-buffer dest-data, x, y, src-width, color-index-byte
      _diffuse-dithering-error-floyd-steinberg errors, x, y, src-width, src-height, error
      x <- increment
      loop
    }
    {
      compare y, 0x18
      break-if-<
      move-cursor-to-left-margin-of-next-line 0/screen
    }
#?     {
#?       var key/eax: byte <- read-key 0/keyboard
#?       compare key, 0
#?       loop-if-=
#?     }
    y <- increment
    loop
  }
}

# Use Floyd-Steinberg algorithm for diffusing error at x, y in a 2D grid of
# dimensions (width, height)
#
# https://tannerhelland.com/2012/12/28/dithering-eleven-algorithms-source-code.html
#
# Error is currently a fixed-point number with 16-bit fraction. But
# interestingly this function doesn't care about that.
fn _diffuse-dithering-error-floyd-steinberg errors: (addr array int), x: int, y: int, width: int, height: int, error: int {
  {
    compare error, 0
    break-if-!=
    return
  }
  var width-1/esi: int <- copy width
  width-1 <- decrement
  var height-1/edi: int <- copy height
  height-1 <- decrement
  # delta = error/16
#?   show-errors errors, width, height, x, y
  var delta/ecx: int <- copy error
  delta <- shift-right-signed 4
  # In Floyd-Steinberg, each pixel X transmits its errors to surrounding
  # pixels in the following proportion:
  #           X     7/16
  #     3/16  5/16  1/16
  var x/edx: int <- copy x
  {
    compare x, width-1
    break-if->=
    var tmp/eax: int <- copy 7
    tmp <- multiply delta
    var xright/edx: int <- copy x
    xright <- increment
    _accumulate-dithering-error errors, xright, y, width, tmp
  }
  var y/ebx: int <- copy y
  {
    compare y, height-1
    break-if-<
    return
  }
  var ybelow: int
  copy-to ybelow, y
  increment ybelow
  {
    compare x, 0
    break-if-<=
    var tmp/eax: int <- copy 3
    tmp <- multiply delta
    var xleft/edx: int <- copy x
    xleft <- decrement
    _accumulate-dithering-error errors, xleft, ybelow, width, tmp
  }
  {
    var tmp/eax: int <- copy 5
    tmp <- multiply delta
    _accumulate-dithering-error errors, x, ybelow, width, tmp
  }
  {
    compare x, width-1
    break-if->=
    var xright/edx: int <- copy x
    xright <- increment
    _accumulate-dithering-error errors, xright, ybelow, width, delta
  }
#?   show-errors errors, width, height, x, y
}

fn _accumulate-dithering-error errors: (addr array int), x: int, y: int, width: int, error: int {
  var curr/esi: int <- _read-dithering-error errors, x, y, width
  curr <- add error
  _write-dithering-error errors, x, y, width, curr
}

fn _read-dithering-error _errors: (addr array int), x: int, y: int, width: int -> _/esi: int {
  var errors/esi: (addr array int) <- copy _errors
  var idx/ecx: int <- copy y
  idx <- multiply width
  idx <- add x
#?   psd "i", idx, 5/fg, x, y
  var result-a/eax: (addr int) <- index errors, idx
  return *result-a
}

fn _write-dithering-error _errors: (addr array int), x: int, y: int, width: int, val: int {
  var errors/esi: (addr array int) <- copy _errors
  var idx/ecx: int <- copy y
  idx <- multiply width
  idx <- add x
#?   draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, idx, 7/fg 0/bg
#?   move-cursor-to-left-margin-of-next-line 0/screen
  var src/eax: int <- copy val
  var dest-a/edi: (addr int) <- index errors, idx
  copy-to *dest-a, src
}

fn _read-pgm-buffer _buf: (addr array byte), x: int, y: int, width: int -> _/eax: byte {
  var buf/esi: (addr array byte) <- copy _buf
  var idx/ecx: int <- copy y
  idx <- multiply width
  idx <- add x
  var result-a/eax: (addr byte) <- index buf, idx
  var result/eax: byte <- copy-byte *result-a
  return result
}

fn _write-raw-buffer _buf: (addr array byte), x: int, y: int, width: int, val: byte {
  var buf/esi: (addr array byte) <- copy _buf
  var idx/ecx: int <- copy y
  idx <- multiply width
  idx <- add x
  var src/eax: byte <- copy val
  var dest-a/edi: (addr byte) <- index buf, idx
  copy-byte-to *dest-a, src
}

fn show-errors errors: (addr array int), width: int, height: int, x: int, y: int {
  compare y, 1
  {
    break-if-=
    return
  }
  compare x, 0
  {
    break-if-=
    return
  }
  var y/edx: int <- copy 0
  {
    compare y, height
    break-if->=
    var x/ecx: int <- copy 0
    {
      compare x, width
      break-if->=
      var error/esi: int <- _read-dithering-error errors, x, y, width
      psd "e", error, 5/fg, x, y
      x <- increment
      loop
    }
    move-cursor-to-left-margin-of-next-line 0/screen
    y <- increment
    loop
  }
}

fn psd s: (addr array byte), d: int, fg: int, x: int, y: int {
  {
    compare y, 0x18
    break-if->=
    return
  }
  {
    compare y, 0x1c
    break-if-<=
    return
  }
  {
    compare x, 0x40
    break-if->=
    return
  }
#?   {
#?     compare x, 0x48
#?     break-if-<=
#?     return
#?   }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, s, 7/fg 0/bg
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, d, fg 0/bg
}

fn psx s: (addr array byte), d: int, fg: int, x: int, y: int {
#?   {
#?     compare y, 0x60
#?     break-if->=
#?     return
#?   }
#?   {
#?     compare y, 0x6c
#?     break-if-<=
#?     return
#?   }
  {
    compare x, 0x20
    break-if->=
    return
  }
#?   {
#?     compare x, 0x6c
#?     break-if-<=
#?     return
#?   }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, s, 7/fg 0/bg
  draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, d, fg 0/bg
}

# import a color ascii "pixmap" (each pixel consists of 3 shades of r/g/b from 0 to 255)
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

# import a color ascii "pixmap" (each pixel consists of 3 shades of r/g/b from 0 to 255)
fn render-ppm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int {
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
      idx <- multiply img-width
      idx <- add imgx
      # . multiply by 3 for the r/g/b channels
      {
        var tmp/ecx: int <- copy idx
        tmp <- shift-left 1
        idx <- add tmp
      }
      # error info in case we rounded wrong and 'index' will fail bounds-check
      compare idx, len
      {
        break-if-<
        set-cursor-position 0/screen, 0x20/x 0x20/y
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, imgx, 3/fg 0/bg
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, imgy, 4/fg 0/bg
        draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, idx, 5/fg 0/bg
      }
      # r channel
      var r: int
      {
        var src-a/eax: (addr byte) <- index img-data, idx
        var src/eax: byte <- copy-byte *src-a
        copy-to r, src
      }
      idx <- increment
      # g channel
      var g: int
      {
        var src-a/eax: (addr byte) <- index img-data, idx
        var src/eax: byte <- copy-byte *src-a
        copy-to g, src
      }
      idx <- increment
      # b channel
      var b: int
      {
        var src-a/eax: (addr byte) <- index img-data, idx
        var src/eax: byte <- copy-byte *src-a
        copy-to b, src
      }
      idx <- increment
      # plot nearest color
      var color/eax: int <- nearest-color-euclidean r, g, b
      var screenx/ecx: int <- convert x
      screenx <- add xmin
      var screeny/edx: int <- convert y
      screeny <- add ymin
      pixel screen, screenx, screeny, color
      x <- add one-f
      loop
    }
    y <- add one-f
    loop
  }
}

fn render-raw-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int {
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
      idx <- multiply img-width
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
      var color-a/eax: (addr byte) <- index img-data, idx
      var color/eax: byte <- copy-byte *color-a
      var color-int/eax: int <- copy color
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

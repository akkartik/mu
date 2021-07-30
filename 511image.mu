# Loading images from disk, rendering images to screen.
#
# Currently supports ASCII Netpbm formats.
#   https://en.wikipedia.org/wiki/Netpbm#File_formats

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

fn initialize-image _self: (addr image), in: (addr stream byte) {
  var self/esi: (addr image) <- copy _self
  var mode-storage: slice
  var mode/ecx: (addr slice) <- address mode-storage
  next-word-skipping-comments in, mode
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
# TODO: if we have more resolution we could actually use it to improve
# dithering
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
    var img2-storage: image
    var img2/edi: (addr image) <- address img2-storage
    dither-ppm-unordered img, img2
    render-raw-image screen, img2, xmin, ymin, width, height
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
  next-word-skipping-comments in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word-skipping-comments in, curr-word
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
    next-word-skipping-comments in, curr-word
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
  next-word-skipping-comments in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word-skipping-comments in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
  # check and save color levels
  next-word-skipping-comments in, curr-word
  {
    tmp <- parse-decimal-int-from-slice curr-word
    compare tmp, 0xff
    break-if-=
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "levels of grey is not 255; continuing and hoping for the best", 0x2b/fg 0/bg
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
    next-word-skipping-comments in, curr-word
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
    var x/ecx: int <- copy 0
    {
      compare x, src-width
      break-if->=
      var curr/eax: byte <- _read-pgm-buffer src-data, x, y, src-width
      var curr-int/eax: int <- copy curr
      curr-int <- shift-left 0x10  # we have 32 bits; we'll use 16 bits for the fraction and leave 8 for unanticipated overflow
      var error/esi: int <- _read-dithering-error errors, x, y, src-width
      error <- add curr-int
      $_dither-pgm-unordered-monochrome:update-error: {
        compare error, 0x800000
        {
          break-if->=
          _write-raw-buffer dest-data, x, y, src-width, 0/black
          break $_dither-pgm-unordered-monochrome:update-error
        }
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
  # compute scaling factor 255/max
  var target-scale/eax: int <- copy 0xff
  var scale-f/xmm7: float <- convert target-scale
  var src-max-a/eax: (addr int) <- get src, max
  var tmp-f/xmm0: float <- convert *src-max-a
  scale-f <- divide tmp-f
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
    var x/ecx: int <- copy 0
    {
      compare x, src-width
      break-if->=
      var initial-color/eax: byte <- _read-pgm-buffer src-data, x, y, src-width
      # . scale to 255 levels
      var initial-color-int/eax: int <- copy initial-color
      var initial-color-f/xmm0: float <- convert initial-color-int
      initial-color-f <- multiply scale-f
      initial-color-int <- convert initial-color-f
      var error/esi: int <- _read-dithering-error errors, x, y, src-width
      # error += (initial-color << 16)
      {
        var tmp/eax: int <- copy initial-color-int
        tmp <- shift-left 0x10  # we have 32 bits; we'll use 16 bits for the fraction and leave 8 for unanticipated overflow
        error <- add tmp
      }
      # nearest-color = nearest(error >> 16)
      var nearest-color/eax: int <- copy error
      nearest-color <- shift-right-signed 0x10
      {
        compare nearest-color, 0
        break-if->=
        nearest-color <- copy 0
      }
      {
        compare nearest-color, 0xf0
        break-if-<=
        nearest-color <- copy 0xf0
      }
      # . truncate last 4 bits
      nearest-color <- and 0xf0
      # error -= (nearest-color << 16)
      {
        var tmp/eax: int <- copy nearest-color
        tmp <- shift-left 0x10
        error <- subtract tmp
      }
      # color-index = (nearest-color >> 4 + 16)
      var color-index/eax: int <- copy nearest-color
      color-index <- shift-right 4
      color-index <- add 0x10
      var color-index-byte/eax: byte <- copy-byte color-index
      _write-raw-buffer dest-data, x, y, src-width, color-index-byte
      _diffuse-dithering-error-floyd-steinberg errors, x, y, src-width, src-height, error
      x <- increment
      loop
    }
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

# some debugging helpers
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
  next-word-skipping-comments in, curr-word
  var tmp/eax: int <- parse-decimal-int-from-slice curr-word
  var width/edx: int <- copy tmp
  next-word-skipping-comments in, curr-word
  tmp <- parse-decimal-int-from-slice curr-word
  var height/ebx: int <- copy tmp
  next-word-skipping-comments in, curr-word
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
    next-word-skipping-comments in, curr-word
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

fn dither-ppm-unordered _src: (addr image), _dest: (addr image) {
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
  # compute scaling factor 255/max
  var target-scale/eax: int <- copy 0xff
  var scale-f/xmm7: float <- convert target-scale
  var src-max-a/eax: (addr int) <- get src, max
  var tmp-f/xmm0: float <- convert *src-max-a
  scale-f <- divide tmp-f
  # allocate 'data'
  var capacity/ebx: int <- copy src-width
  capacity <- multiply src-height
  var dest/edi: (addr image) <- copy _dest
  var dest-data-ah/eax: (addr handle array byte) <- get dest, data
  populate dest-data-ah, capacity
  var _dest-data/eax: (addr array byte) <- lookup *dest-data-ah
  var dest-data/edi: (addr array byte) <- copy _dest-data
  # error buffers per r/g/b channel
  var red-errors-storage: (array int 0xc0000)
  var tmp/eax: (addr array int) <- address red-errors-storage
  var red-errors: (addr array int)
  copy-to red-errors, tmp
  var green-errors-storage: (array int 0xc0000)
  var tmp/eax: (addr array int) <- address green-errors-storage
  var green-errors: (addr array int)
  copy-to green-errors, tmp
  var blue-errors-storage: (array int 0xc0000)
  var tmp/eax: (addr array int) <- address blue-errors-storage
  var blue-errors: (addr array int)
  copy-to blue-errors, tmp
  # transform 'data'
  var src-data-ah/eax: (addr handle array byte) <- get src, data
  var _src-data/eax: (addr array byte) <- lookup *src-data-ah
  var src-data/esi: (addr array byte) <- copy _src-data
  var y/edx: int <- copy 0
  {
    compare y, src-height
    break-if->=
    var x/ecx: int <- copy 0
    {
      compare x, src-width
      break-if->=
      # - update errors and compute color levels for current pixel in each channel
      # update red-error with current image pixel
      var red-error: int
      {
        var tmp/esi: int <- _read-dithering-error red-errors, x, y, src-width
        copy-to red-error, tmp
      }
      {
        var tmp/eax: int <- _ppm-error src-data, x, y, src-width, 0/red, scale-f
        add-to red-error, tmp
      }
      # recompute red channel for current pixel
      var red-level: int
      {
        var tmp/eax: int <- _error-to-ppm-channel red-error
        copy-to red-level, tmp
      }
      # update green-error with current image pixel
      var green-error: int
      {
        var tmp/esi: int <- _read-dithering-error green-errors, x, y, src-width
        copy-to green-error, tmp
      }
      {
        var tmp/eax: int <- _ppm-error src-data, x, y, src-width, 1/green, scale-f
        add-to green-error, tmp
      }
      # recompute green channel for current pixel
      var green-level: int
      {
        var tmp/eax: int <- _error-to-ppm-channel green-error
        copy-to green-level, tmp
      }
      # update blue-error with current image pixel
      var blue-error: int
      {
        var tmp/esi: int <- _read-dithering-error blue-errors, x, y, src-width
        copy-to blue-error, tmp
      }
      {
        var tmp/eax: int <- _ppm-error src-data, x, y, src-width, 2/blue, scale-f
        add-to blue-error, tmp
      }
      # recompute blue channel for current pixel
      var blue-level: int
      {
        var tmp/eax: int <- _error-to-ppm-channel blue-error
        copy-to blue-level, tmp
      }
      # - figure out the nearest color
      var nearest-color-index/eax: int <- nearest-color-euclidean red-level, green-level, blue-level
      {
        var nearest-color-index-byte/eax: byte <- copy-byte nearest-color-index
        _write-raw-buffer dest-data, x, y, src-width, nearest-color-index-byte
      }
      # - diffuse errors
      var red-level: int
      var green-level: int
      var blue-level: int
      {
        var tmp-red-level/ecx: int <- copy 0
        var tmp-green-level/edx: int <- copy 0
        var tmp-blue-level/ebx: int <- copy 0
        tmp-red-level, tmp-green-level, tmp-blue-level <- color-rgb nearest-color-index
        copy-to red-level, tmp-red-level
        copy-to green-level, tmp-green-level
        copy-to blue-level, tmp-blue-level
      }
      # update red-error
      var red-level-error/eax: int <- copy red-level
      red-level-error <- shift-left 0x10
      subtract-from red-error, red-level-error
      _diffuse-dithering-error-floyd-steinberg red-errors, x, y, src-width, src-height, red-error
      # update green-error
      var green-level-error/eax: int <- copy green-level
      green-level-error <- shift-left 0x10
      subtract-from green-error, green-level-error
      _diffuse-dithering-error-floyd-steinberg green-errors, x, y, src-width, src-height, green-error
      # update blue-error
      var blue-level-error/eax: int <- copy blue-level
      blue-level-error <- shift-left 0x10
      subtract-from blue-error, blue-level-error
      _diffuse-dithering-error-floyd-steinberg blue-errors, x, y, src-width, src-height, blue-error
      #
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

# convert a single channel for a single image pixel to error space
fn _ppm-error buf: (addr array byte), x: int, y: int, width: int, channel: int, _scale-f: float -> _/eax: int {
  # current image pixel
  var initial-level/eax: byte <- _read-ppm-buffer buf, x, y, width, channel
  # scale to 255 levels
  var initial-level-int/eax: int <- copy initial-level
  var initial-level-f/xmm0: float <- convert initial-level-int
  var scale-f/xmm1: float <- copy _scale-f
  initial-level-f <- multiply scale-f
  initial-level-int <- convert initial-level-f
  # switch to fixed-point with 16 bits of precision
  initial-level-int <- shift-left 0x10
  return initial-level-int
}

fn _error-to-ppm-channel error: int -> _/eax: int {
  # clamp(error >> 16)
  var result/esi: int <- copy error
  result <- shift-right-signed 0x10
  {
    compare result, 0
    break-if->=
    result <- copy 0
  }
  {
    compare result, 0xff
    break-if-<=
    result <- copy 0xff
  }
  return result
}

# read from a buffer containing alternating bytes from r/g/b channels
fn _read-ppm-buffer _buf: (addr array byte), x: int, y: int, width: int, channel: int -> _/eax: byte {
  var buf/esi: (addr array byte) <- copy _buf
  var idx/ecx: int <- copy y
  idx <- multiply width
  idx <- add x
  var byte-idx/edx: int <- copy 3
  byte-idx <- multiply idx
  byte-idx <- add channel
  var result-a/eax: (addr byte) <- index buf, byte-idx
  var result/eax: byte <- copy-byte *result-a
  return result
}

# each byte in the image data is a color of the current palette
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

fn scale-image-height _img: (addr image), width: int -> _/ebx: int {
  var img/esi: (addr image) <- copy _img
  var img-height/eax: (addr int) <- get img, height
  var result-f/xmm0: float <- convert *img-height
  var img-width/eax: (addr int) <- get img, width
  var img-width-f/xmm1: float <- convert *img-width
  result-f <- divide img-width-f
  var width-f/xmm1: float <- convert width
  result-f <- multiply width-f
  var result/ebx: int <- convert result-f
  return result
}

fn next-word-skipping-comments line: (addr stream byte), out: (addr slice) {
  next-word line, out
  var retry?/eax: boolean <- slice-starts-with? out, "#"
  compare retry?, 0/false
  loop-if-!=
}

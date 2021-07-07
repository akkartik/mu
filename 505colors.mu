# Hue/saturation/luminance for an rgb triple.
# rgb are in [0, 256)
# hsl are also returned in [0, 256)
# from https://www.niwa.nu/2013/05/math-behind-colorspace-conversions-rgb-hsl
fn hsl r: int, g: int, b: int -> _/ecx: int, _/edx: int, _/ebx: int {
  var _max/eax: int <- maximum r, g
  _max <- maximum _max, b
  var max/ecx: int <- copy _max
  var _min/eax: int <- minimum r, g
  _min <- minimum _min, b
  var min/edx: int <- copy _min
  var luminance/ebx: int <- copy min
  luminance <- add max
  luminance <- shift-right 1  # TODO: round up instead of down
  # if rgb are all equal, it's a shade of grey
  compare min, max
  {
    break-if-!=
    return 0, 0, luminance
  }
  # saturation =
  #   luminance < 128 | 255*(max-min)/         (max+min)
  #   otherwise       | 255*(max-min)/(2*255 - (max+min))
  var nr/esi: int <- copy max
  nr <- subtract min
  var dr/eax: int <- copy 0
  compare luminance, 0x80
  {
    break-if->=
    dr <- copy max
    dr <- add min
  }
  {
    break-if-<
    dr <- copy 0xff
    dr <- shift-left 1
    dr <- subtract max
    dr <- subtract min
  }
  var q/xmm0: float <- convert nr
  var tmp/xmm1: float <- convert dr
  q <- divide tmp
  var int-255/eax: int <- copy 0xff
  tmp <- convert int-255
  q <- multiply tmp
  var saturation/esi: int <- convert q
  # hue = 
  #   red is max   | 256.0/6*       (g-b)/(max-min)
  #   green is max | 256.0/6*(2.0 + (b-r)/(max-min))
  #   blue is max  | 256.0/6*(4.0 + (r-g)/(max-min))
  var zero/eax: int <- copy 0
  var hue-f/xmm0: float <- convert zero
  var dr/eax: int <- copy max
  dr <- subtract min
  var dr-f/xmm1: float <- convert dr
  $hsl:compute-hue-normalized: {
    compare r, max
    {
      break-if-!=
      var nr/eax: int <- copy g
      nr <- subtract b
      hue-f <- convert nr
      hue-f <- divide dr-f
      break $hsl:compute-hue-normalized
    }
    compare g, max
    {
      break-if-!=
      var nr/eax: int <- copy b
      nr <- subtract r
      var f/xmm2: float <- convert nr
      f <- divide dr-f
      var two/ecx: int <- copy 2
      hue-f <- convert two
      hue-f <- add f
      break $hsl:compute-hue-normalized
    }
    compare b, max
    {
      break-if-!=
      var nr/eax: int <- copy r
      nr <- subtract g
      var f/xmm2: float <- convert nr
      f <- divide dr-f
      var two/ecx: int <- copy 4
      hue-f <- convert two
      hue-f <- add f
      break $hsl:compute-hue-normalized
    }
  }
  var int-256/eax: int <- copy 0x100
  var scaling-factor/xmm1: float <- convert int-256
  var int-6/eax: int <- copy 6
  var six-f/xmm2: float <- convert int-6
  scaling-factor <- divide six-f
  hue-f <- multiply scaling-factor
  var hue/eax: int <- convert hue-f
  # if hue < 0, hue = 256 - hue
  compare hue, 0
  {
    break-if->=
    var tmp/ecx: int <- copy 0x100
    tmp <- subtract hue
    hue <- copy tmp
  }
  return hue, saturation, luminance
}

fn test-hsl-black {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0, 0, 0
  check-ints-equal h, 0, "F - test-hsl-black/hue"
  check-ints-equal s, 0, "F - test-hsl-black/saturation"
  check-ints-equal l, 0, "F - test-hsl-black/luminance"
}

fn test-hsl-white {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0xff, 0xff, 0xff
  check-ints-equal h, 0, "F - test-hsl-white/hue"
  check-ints-equal s, 0, "F - test-hsl-white/saturation"
  check-ints-equal l, 0xff, "F - test-hsl-white/luminance"
}

fn test-hsl-grey {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0x30, 0x30, 0x30
  check-ints-equal h, 0, "F - test-hsl-grey/hue"
  check-ints-equal s, 0, "F - test-hsl-grey/saturation"
  check-ints-equal l, 0x30, "F - test-hsl-grey/luminance"
}

# red hues: 0-0x54
fn test-hsl-slightly-red {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0xff, 0xfe, 0xfe
  check-ints-equal h, 0, "F - test-hsl-slightly-red/hue"
  check-ints-equal s, 0xff, "F - test-hsl-slightly-red/saturation"
  check-ints-equal l, 0xfe, "F - test-hsl-slightly-red/luminance"  # TODO: should round up
}

fn test-hsl-extremely-red {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0xff, 0, 0
  check-ints-equal h, 0, "F - test-hsl-extremely-red/hue"
  check-ints-equal s, 0xff, "F - test-hsl-extremely-red/saturation"
  check-ints-equal l, 0x7f, "F - test-hsl-extremely-red/luminance"  # TODO: should round up
}

# green hues: 0x55-0xaa
fn test-hsl-slightly-green {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0xfe, 0xff, 0xfe
  check-ints-equal h, 0x55, "F - test-hsl-slightly-green/hue"
  check-ints-equal s, 0xff, "F - test-hsl-slightly-green/saturation"
  check-ints-equal l, 0xfe, "F - test-hsl-slightly-green/luminance"  # TODO: should round up
}

fn test-hsl-extremely-green {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0, 0xff, 0
  check-ints-equal h, 0x55, "F - test-hsl-extremely-green/hue"
  check-ints-equal s, 0xff, "F - test-hsl-extremely-green/saturation"
  check-ints-equal l, 0x7f, "F - test-hsl-extremely-green/luminance"  # TODO: should round up
}

# blue hues: 0xab-0xff
fn test-hsl-slightly-blue {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0xfe, 0xfe, 0xff
  check-ints-equal h, 0xab, "F - test-hsl-slightly-blue/hue"
  check-ints-equal s, 0xff, "F - test-hsl-slightly-blue/saturation"
  check-ints-equal l, 0xfe, "F - test-hsl-slightly-blue/luminance"  # TODO: should round up
}

fn test-hsl-extremely-blue {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0, 0, 0xff
  check-ints-equal h, 0xab, "F - test-hsl-extremely-blue/hue"
  check-ints-equal s, 0xff, "F - test-hsl-extremely-blue/saturation"
  check-ints-equal l, 0x7f, "F - test-hsl-extremely-blue/luminance"  # TODO: should round up
}

# cyan: 0x7f

fn test-hsl-cyan {
  var h/ecx: int <- copy 0
  var s/edx: int <- copy 0
  var l/ebx: int <- copy 0
  h, s, l <- hsl 0, 0xff, 0xff
  check-ints-equal h, 0x80, "F - test-hsl-cyan/hue"
  check-ints-equal s, 0xff, "F - test-hsl-cyan/saturation"
  check-ints-equal l, 0x7f, "F - test-hsl-cyan/luminance"  # TODO: should round up
}

fn nearest-color-euclidean-hsl h: int, s: int, l: int -> _/eax: int {
  var result/edi: int <- copy 0x100/invalid
  var max-distance/esi: int <- copy 0x30000/max  # 3 * 0x100*0x100
  var a/ecx: int <- copy 0
  var b/edx: int <- copy 0
  var c/ebx: int <- copy 0
  var color/eax: int <- copy 0
  {
    compare color, 0x100
    break-if->=
    $nearest-color-euclidean-hsl:body: {
      a, b, c <- color-rgb color
      a, b, c <- hsl a, b, c
      {
        var curr-distance/eax: int <- euclidean-hsl-squared a, b, c, h, s, l
        compare curr-distance, max-distance
        break-if->= $nearest-color-euclidean-hsl:body
        max-distance <- copy curr-distance
      }
      result <- copy color
    }
    color <- increment
    loop
  }
  return result
}

fn euclidean-hsl-squared h1: int, s1: int, l1: int, h2: int, s2: int, l2: int -> _/eax: int {
  var result/edi: int <- copy 0
  # hue
  var tmp/eax: int <- copy h1
  tmp <- subtract h2
  tmp <- multiply tmp
  # hue is a cylindrical space; distance can't be greater than 0x80
  {
    compare tmp, 0x4000  # 0x80*0x80
    break-if-<=
    tmp <- subtract 0x4000
    tmp <- negate
  }
  result <- add tmp
  # saturation
  tmp <- copy s1
  tmp <- subtract s2
  tmp <- multiply tmp
  result <- add tmp
  # luminance
  tmp <- copy l1
  tmp <- subtract l2
  tmp <- multiply tmp
  result <- add tmp
  return result
}

###

fn maximum a: int, b: int -> _/eax: int {
  var a2/eax: int <- copy a
  compare a2, b
  {
    break-if-<
    return a
  }
  return b
}

fn minimum a: int, b: int -> _/eax: int {
  var a2/eax: int <- copy a
  compare a2, b
  {
    break-if->
    return a
  }
  return b
}

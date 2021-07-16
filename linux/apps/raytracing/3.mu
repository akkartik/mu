# Listing 9 of https://raytracing.github.io/books/RayTracingInOneWeekend.html
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu/linux
#   $ ./translate apps/raytracing/3.mu
#   $ ./a.elf > 3.ppm

fn ray-color _in: (addr ray), _out: (addr rgb) {
  var in/esi: (addr ray) <- copy _in
  var out/edi: (addr rgb) <- copy _out
  var dir/eax: (addr vec3) <- get in, dir
#?   print-string 0, "r.dir: "
#?   print-vec3 0, dir
#?   print-string 0, "\n"
  var unit-storage: vec3
  var unit/ecx: (addr vec3) <- address unit-storage
  vec3-unit dir, unit
#?   print-string 0, "r.dir normalized: "
#?   print-vec3 0, unit
#?   print-string 0, "\n"
  var y-addr/eax: (addr float) <- get unit, y
  # t = (dir.y + 1.0) / 2.0
  var t/xmm0: float <- copy *y-addr
  var one/eax: int <- copy 1
  var one-f/xmm1: float <- convert one
  t <- add one-f
  var two/eax: int <- copy 2
  var two-f/xmm2: float <- convert two
  t <- divide two-f
#?   print-string 0, "t: "
#?   print-float-hex 0, t
#?   print-string 0, "\n"
  # whitening = (1.0 - t) * white
  var whitening-storage: rgb
  var whitening/ecx: (addr rgb) <- address whitening-storage
  rgb-white whitening
  var one-minus-t/xmm3: float <- copy one-f
  one-minus-t <- subtract t
  rgb-scale-up whitening, one-minus-t
#?   print-string 0, "whitening: "
#?   print-rgb-raw 0, whitening
#?   print-string 0, "\n"
  # out = t * (0.5, 0.7, 1.0)
  var dest/eax: (addr float) <- get out, r
  fill-in-rational dest, 5, 0xa
  dest <- get out, g
  fill-in-rational dest, 7, 0xa
  dest <- get out, b
  copy-to *dest, one-f
  rgb-scale-up out, t
#?   print-string 0, "base: "
#?   print-rgb-raw 0, out
#?   print-string 0, "\n"
  # blend with whitening
  rgb-add-to out, whitening
#?   print-string 0, "result: "
#?   print-rgb-raw 0, out
#?   print-string 0, "\n"
}

fn main -> _/ebx: int {

  # image
  #   width = 400
  #   height = 400 * 9/16 = 225
  var aspect: float
  var aspect-addr/eax: (addr float) <- address aspect
  fill-in-rational aspect-addr, 0x10, 9  # 16/9
#?   print-string 0, "aspect ratio: "
#?   print-float-hex 0, aspect
#?   print-string 0, " "
#?   {
#?     var foo2/ebx: int <- reinterpret aspect
#?     print-int32-hex 0, foo2
#?   }
#?   print-string 0, "\n"

  # camera

  # viewport-height = 2.0
  var tmp/eax: int <- copy 2
  var two-f/xmm4: float <- convert tmp
  var viewport-height/xmm7: float <- copy two-f
#?   print-string 0, "viewport height: "
#?   print-float-hex 0, viewport-height
#?   print-string 0, " "
#?   {
#?     var foo: float
#?     copy-to foo, viewport-height
#?     var foo2/ebx: int <- reinterpret foo
#?     print-int32-hex 0, foo2
#?   }
#?   print-string 0, "\n"
  # viewport-width = aspect * viewport-height
  var viewport-width/xmm6: float <- convert tmp
  viewport-width <- multiply aspect
#?   print-string 0, "viewport width: "
#?   print-float-hex 0, viewport-width
#?   print-string 0, " "
#?   {
#?     var foo: float
#?     copy-to foo, viewport-width
#?     var foo2/ebx: int <- reinterpret foo
#?     print-int32-hex 0, foo2
#?   }
#?   print-string 0, "\n"
  # focal-length = 1.0
  tmp <- copy 1
  var focal-length/xmm5: float <- convert tmp

  # origin = point3(0, 0, 0)
  var origin-storage: vec3
  var origin/edi: (addr vec3) <- address origin-storage
  # horizontal = vec3(viewport-width, 0, 0)
  var horizontal-storage: vec3
  var dest/eax: (addr float) <- get horizontal-storage, x
  copy-to *dest, viewport-width
  var horizontal/ebx: (addr vec3) <- address horizontal-storage
  # vertical = vec3(0, viewport-height, 0)
  var vertical-storage: vec3
  dest <- get vertical-storage, y
  copy-to *dest, viewport-height
  var vertical/edx: (addr vec3) <- address vertical-storage
  # lower-left-corner = origin - horizontal/2 - vertical/2 - vec3(0, 0, focal-length)
  # . lower-left-corner = origin
  var lower-left-corner-storage: vec3
  var lower-left-corner/esi: (addr vec3) <- address lower-left-corner-storage
  copy-object origin, lower-left-corner
  # . lower-left-corner -= horizontal/2
  var tmp2: vec3
  var tmp2-addr/eax: (addr vec3) <- address tmp2
  copy-object horizontal, tmp2-addr
  vec3-scale-down tmp2-addr, two-f
  vec3-subtract-from lower-left-corner, tmp2-addr
  # . lower-left-corner -= vertical/2
  copy-object vertical, tmp2-addr
  vec3-scale-down tmp2-addr, two-f
  vec3-subtract-from lower-left-corner, tmp2-addr
  # . lower-left-corner -= vec3(0, 0, focal-length)
  var dest2/ecx: (addr float) <- get lower-left-corner, z
  var tmp3/xmm0: float <- copy *dest2
  tmp3 <- subtract focal-length
  copy-to *dest2, tmp3
  # phew!

  # render

  # live variables at this point:
  #   origin (edi)
  #   lower-left-corner (esi)
  #   horizontal (ebx)
  #   vertical (edx)
  # floating-point registers are all free
  print-string 0, "P3\n400 225\n255\n"  # 225 = image height
  var tmp/eax: int <- copy 0x18f # image width - 1
  var image-width-1/xmm7: float <- convert tmp
  tmp <- copy 0xe0  # image height - 1
  var image-height-1/xmm6: float <- convert tmp
  #
  var j/ecx: int <- copy 0xe0  # 224
  {
    compare j, 0
    break-if-<
    var i/eax: int <- copy 0
    {
      compare i, 0x190  # 400 = image width
      break-if->=
      # u = i / (image-width - 1)
      var u/xmm0: float <- convert i
      u <- divide image-width-1
#?       print-string 0, "u: "
#?       print-float-hex 0, u
#?       print-string 0, "\n"
      # v = j / (image-height - 1)
      var v/xmm1: float <- convert j
      v <- divide image-height-1
      # r = ray(origin, lower-left-corner + u*horizontal + v*vertical - origin)
      var r-storage: ray
      # . . we're running out of int registers now,
      # . . but luckily we don't need i and j in the rest of this loop iteration,
      # . . so we'll just spill them in a block
      {
        # . r.orig = origin
        var r/eax: (addr ray) <- address r-storage
        var dest/ecx: (addr vec3) <- get r, orig
        copy-object origin, dest
        # . r.dir = lower-left-corner
        dest <- get r, dir
        copy-object lower-left-corner, dest
        # . r.dir += horizontal*u
        var tmp-vec3: vec3
        var tmp/eax: (addr vec3) <- address tmp-vec3
        copy-object horizontal, tmp
        vec3-scale-up tmp, u
        vec3-add-to dest, tmp
        # . r.dir += vertical*v
        copy-object vertical, tmp
        vec3-scale-up tmp, v
        vec3-add-to dest, tmp
        # . r.dir -= origin
        vec3-subtract-from dest, origin
#?         print-string 0, "ray direction: "
#?         print-vec3 0, dest
#?         print-string 0, "\n"
      }
      # pixel-color = ray-color(r)
      var c-storage: rgb
      var c/ecx: (addr rgb) <- address c-storage
      {
        var r/eax: (addr ray) <- address r-storage
        ray-color r, c
        # write color
        print-rgb 0, c
#?         print-rgb-raw 0, c
#?         print-string 0, "\n"
      }
      i <- increment
      loop
    }
    j <- decrement
    loop
  }
  return 0
}

type ray {
  orig: vec3  # point
  dir: vec3
}

# A little different from the constructor at https://raytracing.github.io/books/RayTracingInOneWeekend.html
# We immediately normalize the direction vector so we don't have to keep doing
# so.
fn initialize-ray _self: (addr ray), o: (addr vec3), d: (addr vec3) {
  var self/esi: (addr ray) <- copy _self
  var dest/eax: (addr vec3) <- get self, orig
  copy-object o, dest
  dest <- get self, dir
  vec3-unit d, dest
}

fn ray-at _self: (addr ray), t: float, out: (addr vec3) {
  var self/esi: (addr ray) <- copy _self
  var src/eax: (addr vec3) <- get self, dir
  copy-object src, out
  vec3-scale-up out, t
  src <- get self, orig
  vec3-add-to out, src
}

type rgb {
  # components normalized to within [0.0, 1.0]
  r: float
  g: float
  b: float
}

# print translating to [0, 256)
fn print-rgb screen: (addr screen), _c: (addr rgb) {
  var c/esi: (addr rgb) <- copy _c
  var xn: float
  var xn-addr/ecx: (addr float) <- address xn
  fill-in-rational xn-addr, 0x3e7ff, 0x3e8  # 255999 / 1000
  # print 255.999 * c->r
  var result/xmm0: float <- copy xn
  var src-addr/eax: (addr float) <- get c, r
  result <- multiply *src-addr
  var result-int/edx: int <- truncate result
  print-int32-decimal screen, result-int
  print-string screen, " "
  # print 255.999 * c->g
  src-addr <- get c, g
  result <- copy xn
  result <- multiply *src-addr
  result-int <- truncate result
  print-int32-decimal screen, result-int
  print-string screen, " "
  # print 255.999 * c->b
  src-addr <- get c, b
  result <- copy xn
  result <- multiply *src-addr
  result-int <- truncate result
  print-int32-decimal screen, result-int
  print-string screen, "\n"
}

fn print-rgb-raw screen: (addr screen), _v: (addr rgb) {
  var v/esi: (addr rgb) <- copy _v
  print-string screen, "("
  var tmp/eax: (addr float) <- get v, r
  print-float-hex screen, *tmp
  print-string screen, ", "
  tmp <- get v, g
  print-float-hex screen, *tmp
  print-string screen, ", "
  tmp <- get v, b
  print-float-hex screen, *tmp
  print-string screen, ")"
}

fn rgb-white _c: (addr rgb) {
  var c/esi: (addr rgb) <- copy _c
  var one/eax: int <- copy 1
  var one-f/xmm0: float <- convert one
  var dest/edi: (addr float) <- get c, r
  copy-to *dest, one-f
  dest <- get c, g
  copy-to *dest, one-f
  dest <- get c, b
  copy-to *dest, one-f
}

fn rgb-add-to _c1: (addr rgb), _c2: (addr rgb) {
  var c1/edi: (addr rgb) <- copy _c1
  var c2/esi: (addr rgb) <- copy _c2
  # c1.r += c2.r
  var arg1/eax: (addr float) <- get c1, r
  var arg2/ecx: (addr float) <- get c2, r
  var result/xmm0: float <- copy *arg1
  result <- add *arg2
  copy-to *arg1, result
  # c1.g += c2.g
  arg1 <- get c1, g
  arg2 <- get c2, g
  result <- copy *arg1
  result <- add *arg2
  copy-to *arg1, result
  # c1.b += c2.b
  arg1 <- get c1, b
  arg2 <- get c2, b
  result <- copy *arg1
  result <- add *arg2
  copy-to *arg1, result
}

fn rgb-scale-up _c1: (addr rgb), f: float {
  var c1/edi: (addr rgb) <- copy _c1
  # c1.r *= f
  var dest/eax: (addr float) <- get c1, r
  var result/xmm0: float <- copy *dest
  result <- multiply f
  copy-to *dest, result
  # c1.g *= f
  dest <- get c1, g
  result <- copy *dest
  result <- multiply f
  copy-to *dest, result
  # c1.b *= f
  dest <- get c1, b
  result <- copy *dest
  result <- multiply f
  copy-to *dest, result
}

type vec3 {
  x: float
  y: float
  z: float
}

fn print-vec3 screen: (addr screen), _v: (addr vec3) {
  var v/esi: (addr vec3) <- copy _v
  print-string screen, "("
  var tmp/eax: (addr float) <- get v, x
  print-float-hex screen, *tmp
  print-string screen, ", "
  tmp <- get v, y
  print-float-hex screen, *tmp
  print-string screen, ", "
  tmp <- get v, z
  print-float-hex screen, *tmp
  print-string screen, ")"
}

fn vec3-add-to _v1: (addr vec3), _v2: (addr vec3) {
  var v1/edi: (addr vec3) <- copy _v1
  var v2/esi: (addr vec3) <- copy _v2
  # v1.x += v2.x
  var arg1/eax: (addr float) <- get v1, x
  var arg2/ecx: (addr float) <- get v2, x
  var result/xmm0: float <- copy *arg1
  result <- add *arg2
  copy-to *arg1, result
  # v1.y += v2.y
  arg1 <- get v1, y
  arg2 <- get v2, y
  result <- copy *arg1
  result <- add *arg2
  copy-to *arg1, result
  # v1.z += v2.z
  arg1 <- get v1, z
  arg2 <- get v2, z
  result <- copy *arg1
  result <- add *arg2
  copy-to *arg1, result
}

fn vec3-subtract-from v1: (addr vec3), v2: (addr vec3) {
  var tmp-storage: vec3
  var tmp/eax: (addr vec3) <- address tmp-storage
  copy-object v2, tmp
  vec3-negate tmp
  vec3-add-to v1, tmp
}

fn vec3-negate v: (addr vec3) {
  var negative-one/eax: int <- copy -1
  var negative-one-f/xmm0: float <- convert negative-one
  vec3-scale-up v, negative-one-f
}

fn vec3-scale-up _v: (addr vec3), f: float {
  var v/edi: (addr vec3) <- copy _v
  # v.x *= f
  var dest/eax: (addr float) <- get v, x
  var result/xmm0: float <- copy *dest
  result <- multiply f
  copy-to *dest, result
  # v.y *= f
  dest <- get v, y
  result <- copy *dest
  result <- multiply f
  copy-to *dest, result
  # v.z *= f
  dest <- get v, z
  result <- copy *dest
  result <- multiply f
  copy-to *dest, result
}

fn vec3-scale-down _v: (addr vec3), f: float {
  var v/edi: (addr vec3) <- copy _v
  # v.x /= f
  var dest/eax: (addr float) <- get v, x
  var result/xmm0: float <- copy *dest
  result <- divide f
  copy-to *dest, result
  # v.y /= f
  dest <- get v, y
  result <- copy *dest
  result <- divide f
  copy-to *dest, result
  # v.z /= f
  dest <- get v, z
  result <- copy *dest
  result <- divide f
  copy-to *dest, result
}

fn vec3-unit in: (addr vec3), out: (addr vec3) {
  var len/xmm0: float <- vec3-length in
#?   print-string 0, "len: "
#?   print-float-hex 0, len
#?   print-string 0, "\n"
  copy-object in, out
  vec3-scale-down out, len
}

fn vec3-length v: (addr vec3) -> _/xmm0: float {
  var result/xmm0: float <- vec3-length-squared v
  result <- square-root result
  return result
}

fn vec3-length-squared _v: (addr vec3) -> _/xmm0: float {
  var v/esi: (addr vec3) <- copy _v
  # result = v.x * v.x
  var src/eax: (addr float) <- get v, x
  var tmp/xmm1: float <- copy *src
  tmp <- multiply tmp
  var result/xmm0: float <- copy tmp
  # result += v.y * v.y
  src <- get v, y
  tmp <- copy *src
  tmp <- multiply tmp
  result <- add tmp
  # result += v.z * v.z
  src <- get v, z
  tmp <- copy *src
  tmp <- multiply tmp
  result <- add tmp
  return result
}

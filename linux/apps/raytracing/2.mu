# Listing 7 of https://raytracing.github.io/books/RayTracingInOneWeekend.html
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu/linux
#   $ ./translate apps/raytracing/2.mu
#   $ ./a.elf > 2.ppm

fn main -> _/ebx: int {
  print-string 0, "P3\n256 256\n255\n"
  var _four/edx: int <- copy 4
  var four/xmm1: float <- convert _four
  var one-fourth/xmm1: float <- reciprocal four
  var max/edx: int <- copy 0xff
  var image-size/xmm2: float <- convert max
  var j/ecx: int <- copy 0xff
  {
    compare j, 0
    break-if-<
    var i/eax: int <- copy 0
    {
      compare i, 0xff
      break-if->
      var c: rgb
      # compute r
      var tmp/xmm0: float <- convert i
      tmp <- divide image-size
      var r-addr/edx: (addr float) <- get c, r
      copy-to *r-addr, tmp
#?       var tmp2/ebx: int <- reinterpret *r-addr
#?       print-int32-hex 0, tmp2
#?       print-string 0, "\n"
      # compute g
      tmp <- convert j
      tmp <- divide image-size
      var g-addr/edx: (addr float) <- get c, g
      copy-to *g-addr, tmp
      # compute b
      var b-addr/edx: (addr float) <- get c, b
      copy-to *b-addr, one-fourth
      # emit
      var c-addr/edx: (addr rgb) <- address c
      print-rgb 0, c-addr
      i <- increment
      loop
    }
    j <- decrement
    loop
  }
  return 0
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
  var n/ecx: int <- copy 0xff  # turns out 255 works just as well as 255.999, which is lucky because we don't have floating-point literals
  var xn/xmm1: float <- convert n
  # print 255 * c->r
  var result/xmm0: float <- copy xn
  var src-addr/eax: (addr float) <- get c, r
  result <- multiply *src-addr
  var result-int/edx: int <- convert result
  print-int32-decimal screen, result-int
  print-string screen, " "
  # print 255 * c->g
  src-addr <- get c, g
  result <- copy xn
  result <- multiply *src-addr
  result-int <- convert result
  print-int32-decimal screen, result-int
  print-string screen, " "
  # print 255 * c->b
  src-addr <- get c, b
  result <- copy xn
  result <- multiply *src-addr
  result-int <- convert result
  print-int32-decimal screen, result-int
  print-string screen, "\n"
}

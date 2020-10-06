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

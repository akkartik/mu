type rgb {
  # components normalized to within [0.0, 1.0]
  r: float
  g: float
  b: float
}

# print translating to [0, 256)
fn print-rgb screen: (addr screen), _c: (addr rgb) {
  var c/esi: (addr rgb) <- copy _c
  var n/ecx: int <- copy 0xff
  var xn/xmm1: float <- convert n
  var tmp/xmm0: float <- copy xn
  var tmp-a/eax: (addr float) <- get c, r
  tmp <- multiply *tmp-a
  var tmp2/edx: int <- convert tmp
  print-int32-decimal screen, tmp2
  print-string screen, " "
  tmp-a <- get c, g
  tmp <- copy xn
  tmp <- multiply *tmp-a
  tmp2 <- convert tmp
  print-int32-decimal screen, tmp2
  print-string screen, " "
  tmp-a <- get c, b
  tmp <- copy xn
  tmp <- multiply *tmp-a
  tmp2 <- convert tmp
  print-int32-decimal screen, tmp2
  print-string screen, "\n"
}

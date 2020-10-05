type vec3 {
  x: float
  y: float
  z: float
}

fn vec3-negate _v: (addr vec3) {
}

fn vec3-add-to _v1: (addr vec3), _v2: (addr vec3) {
}

fn vec3-mul-by _v1: (addr vec3), _v2: (addr vec3) {
}

fn vec3-scale-up _v: (addr vec3), f: float {
}

fn vec3-scale-down _v: (addr vec3), f: float {
}

fn vec3-length v: (addr vec3) -> result/xmm0: float {
}

fn vec3-length-squared _v: (addr vec3) -> result/xmm0: float {
}

fn vec3-dot _v1: (addr vec3), _v2: (addr vec3) -> result/xmm0: float {
}

fn vec3-cross _v1: (addr vec3), _v2: (addr vec3), out: (addr vec3) {
}

fn vec3-unit in: (addr vec3), out: (addr vec3) {
}

fn print-vec3 screen: (addr screen), _v: (addr vec3) {
  var v/esi: (addr vec3) <- copy _v
  print-string screen, "("
  var tmp/eax: (addr float) <- get v, x
  print-float screen, *tmp
  print-string screen, ", "
  tmp <- get v, y
  print-float screen, *tmp
  print-string screen, ", "
  tmp <- get v, z
  print-float screen, *tmp
  print-string screen, ")"
}

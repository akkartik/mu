type vec3 {
  x: float
  y: float
  z: float
}

fn vec3-negate _a: (addr vec3), out: (addr vec3) {
}

fn vec3-add-to _a: (addr vec3), _b: (addr vec3) {
}

fn vec3-mul-by _a: (addr vec3), _b: (addr vec3) {
}

fn vec3-scale-up _a: (addr vec3), n: float {
}

fn vec3-scale-down _a: (addr vec3), n: float {
}

fn vec3-length _a: (addr vec3) -> result/eax: float {
}

fn vec3-length-squared _a: (addr vec3) -> result/eax: float {
}

fn vec3-dot _a: (addr vec3), _b: (addr vec3) -> result/eax: float {
}

fn vec3-cross _a: (addr vec3), _b: (addr vec3), out: (addr vec3) {
}

fn vec3-unit in: (addr vec3), out: (addr vec3) {
}

fn print-vec3 screen: (addr screen), _a: (addr vec3) {
  var a/esi: (addr vec3) <- copy _a
  print-string screen, "("
  var tmp/eax: (addr float) <- get a, x
  print-float screen, *tmp
  print-string screen, ", "
  tmp <- get a, y
  print-float screen, *tmp
  print-string screen, ", "
  tmp <- get a, z
  print-float screen, *tmp
  print-string screen, ")"
}

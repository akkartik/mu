type vec3 {
  x: float
  y: float
  z: float
}

fn vec3-negate a: (addr vec3), out: (addr vec3) {
}

fn vec3-add-to a: (addr vec3), b: (addr vec3) {
}

fn vec3-mul-by a: (addr vec3), b: (addr vec3) {
}

fn vec3-scale-up a: (addr vec3), n: float {
}

fn vec3-scale-down a: (addr vec3), n: float {
}

fn vec3-length a: (addr vec3) -> result/eax: float {
}

fn vec3-length-squared a: (addr vec3) -> result/eax: float {
}

fn vec3-dot a: (addr vec3), b: (addr vec3) -> result/eax: float {
}

fn vec3-cross a: (addr vec3), b: (addr vec3), out: (addr vec3) {
}

fn vec3-unit in: (addr vec3), out: (addr vec3) {
}

fn print-vec3 screen: (addr screen), a: (addr vec3) {
}

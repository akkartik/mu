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

fn vec3-dot _v1: (addr vec3), _v2: (addr vec3) -> _/xmm0: float {
}

fn vec3-cross _v1: (addr vec3), _v2: (addr vec3), out: (addr vec3) {
}

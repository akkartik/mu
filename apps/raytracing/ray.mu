type ray {
  orig: vec3  # point
  dir: vec3
}

fn ray-at _self: (addr ray), t: float, out: (addr vec3) {
  var self/esi: (addr ray) <- copy _self
  var src/eax: (addr vec3) <- get self, dir
  copy-object src, out
  vec3-mul-by out, t
  src <- get self, orig
  vec3-add-to out, src
}

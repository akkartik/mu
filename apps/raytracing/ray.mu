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

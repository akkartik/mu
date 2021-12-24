fn next-random prev: int -> _/edi: int {
  # https://en.wikipedia.org/wiki/Linear_congruential_generator#Parameters_in_common_use
  var a/ecx: int <- copy 0x4b/75
  var c/edx: int <- copy 0x4a/74
  var m/ebx: int <- copy 0x10001
  var next/eax: int <- copy prev
  next <- multiply a
  next <- add c
  next <- remainder next, m
  return next
}

fn remainder a: int, b: int -> _/eax: int {
  var q/eax: int <- copy 0
  var r/edx: int <- copy 0
  q, r <- integer-divide a, b
  return r
}

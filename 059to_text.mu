# A couple of variants of `to-text` that we'll use implicitly in stashes (see
# later layers).
#
# Mu code might specialize them to be smarter, but I don't anticipate any need
# beyond specializing `to-text` itself.

# 'shorter' variant of to-text, when you want to enable some sort of trimming
# define it to be identical to 'to-text' by default
def to-text-line x:_elem -> y:address:array:character [
  local-scope
  load-ingredients
  y <- to-text x
]

# variant for arrays (since we can't pass them around otherwise)
def array-to-text-line x:address:array:_elem -> y:address:array:character [
  local-scope
  load-ingredients
  y <- to-text *x
]

scenario to-text-line-early-warning-for-static-dispatch [
  x:address:array:character <- to-text-line 34
  # just ensure there were no errors
]

scenario array-to-text-line-early-warning-for-static-dispatch [
  n:address:array:number <- new number:type, 3
  x:address:array:character <- array-to-text-line n
  # just ensure there were no errors
]

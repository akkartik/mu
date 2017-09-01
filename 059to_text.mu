# A couple of variants of 'to-text' that we'll use implicitly in stashes (see
# later layers).
#
# Mu code might specialize them to be smarter, but I don't anticipate any need
# beyond specializing 'to-text' itself.

# 'shorter' variant of to-text, when you want to enable some sort of trimming
# define it to be identical to 'to-text' by default
def to-text-line x:_elem -> y:text [
  local-scope
  load-ingredients
  y <- to-text x
]

# variant for arrays (since we can't pass them around otherwise)
def array-to-text-line x:&:@:_elem -> y:text [
  local-scope
  load-ingredients
  y <- to-text *x
]

scenario to-text-line-early-warning-for-static-dispatch [
  x:text <- to-text-line 34
  # just ensure there were no errors
]

scenario array-to-text-line-early-warning-for-static-dispatch [
  n:&:@:num <- new number:type, 3
  x:text <- array-to-text-line n
  # just ensure there were no errors
]

# finally, a specialization for single characters
def to-text c:char -> y:text [
  local-scope
  load-ingredients
  y <- new character:type, 1/capacity
  *y <- put-index *y, 0, c
]

scenario character-to-text [
  1:char <- copy 111/o
  2:text <- to-text 1:char
  3:@:char <- copy *2:text
  memory-should-contain [
    3:array:character <- [o]
  ]
]

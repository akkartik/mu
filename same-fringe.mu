# The 'same fringe' problem: http://wiki.c2.com/?SameFringeProblem
# Example program demonstrating coroutines using Mu's delimited continuations.
#
# Expected output:
#   1
# (i.e. that the two given trees x and y have the same leaves, in the same
# order from left to right)

container tree:_elem [
  val:_elem
  left:&:tree:_elem
  right:&:tree:_elem
]

def main [
  local-scope
  # x: ((a b) c)
  # y: (a (b c))
  a:&:tree:num <- new-tree 3
  b:&:tree:num <- new-tree 4
  c:&:tree:num <- new-tree 5
  x1:&:tree:num <- new-tree a, b
  x:&:tree:num <- new-tree x1, c
  y1:&:tree:num <- new-tree b, c
  y:&:tree:num <- new-tree a, y1
  result:bool <- same-fringe x, y
  $print result 10/newline
]

def same-fringe a:&:tree:_elem, b:&:tree:_elem -> result:bool [
  local-scope
  load-inputs
  k1:continuation <- call-with-continuation-mark process, a
  k2:continuation <- call-with-continuation-mark process, b
  {
    k1, x:_elem, a-done?:bool <- call k1
    k2, y:_elem, b-done?:bool <- call k2
    break-if a-done?
    break-if b-done?
    match?:bool <- equal x, y
    return-unless match?, 0/false
    loop
  }
  result <- and a-done?, b-done?
]

# harness around traversal
def process t:&:tree:_elem [
  local-scope
  load-inputs
  return-continuation-until-mark  # initial
  traverse t
  zero-val:&:_elem <- new _elem:type
  return-continuation-until-mark *zero-val, 1/done  # final
  assert 0/false, [continuation called past done]
]

# core traversal
def traverse t:&:tree:_elem [
  local-scope
  load-inputs
  return-unless t
  l:&:tree:_elem <- get *t, left:offset
  traverse l
  r:&:tree:_elem <- get *t, right:offset
  traverse r
  return-if l
  return-if r
  # leaf
  v:_elem <- get *t, val:offset
  return-continuation-until-mark v, 0/not-done
]

# details

def new-tree x:_elem -> result:&:tree:_elem [
  local-scope
  load-inputs
  result <- new {(tree _elem): type}
  put *result, val:offset, x
]

def new-tree l:&:tree:_elem, r:&:tree:_elem -> result:&:tree:_elem [
  local-scope
  load-inputs
  result <- new {(tree _elem): type}
  put *result, left:offset, l
  put *result, right:offset, r
]

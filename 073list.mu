# A list links up multiple objects together to make them easier to manage.
#
# The objects must be of the same type. If you want to store multiple types in
# a single list, use an exclusive-container.

container list:_elem [
  value:_elem
  next:address:list:_elem
]

# should I say in/contained-in:result, allow ingredients to refer to products?
recipe push x:_elem, in:address:list:_elem -> result:address:list:_elem [
  local-scope
  load-ingredients
  result <- new {(list _elem): type}
  val:address:_elem <- get-address *result, value:offset
  *val <- copy x
  next:address:address:list:_elem <- get-address *result, next:offset
  *next <- copy in
  reply result
]

recipe first in:address:list:_elem -> result:_elem [
  local-scope
  load-ingredients
  result <- get *in, value:offset
]

# result:address:list <- rest in:address:list
recipe rest in:address:list:_elem -> result:address:list:_elem [
  local-scope
  load-ingredients
  result <- get *in, next:offset
]

scenario list-handling [
  run [
    1:address:list:number <- push 3, 0
    1:address:list:number <- push 4, 1:address:list:number
    1:address:list:number <- push 5, 1:address:list:number
    2:number <- first 1:address:list:number
    1:address:list:number <- rest 1:address:list:number
    3:number <- first 1:address:list:number
    1:address:list:number <- rest 1:address:list:number
    4:number <- first 1:address:list:number
    1:address:list:number <- rest 1:address:list:number
  ]
  memory-should-contain [
    1 <- 0  # empty to empty, dust to dust..
    2 <- 5
    3 <- 4
    4 <- 3
  ]
]

recipe to-text in:address:list:_elem -> result:address:array:character [
  local-scope
#?   $print [to text: list], 10/newline
  load-ingredients
  buf:address:buffer <- new-buffer 80
  buf <- to-buffer in, buf
  result <- buffer-to-array buf
]

# variant of 'to-text' which stops printing after a few elements (and so is robust to cycles)
recipe to-text-line in:address:list:_elem -> result:address:array:character [
  local-scope
#?   $print [to text line: list], 10/newline
  load-ingredients
  buf:address:buffer <- new-buffer 80
  buf <- to-buffer in, buf, 6  # max elements to display
  result <- buffer-to-array buf
]

recipe to-buffer in:address:list:_elem, buf:address:buffer -> buf:address:buffer [
  local-scope
#?   $print [to buffer: list], 10/newline
  load-ingredients
  {
    break-if in
    buf <- append buf, 48/0
    reply
  }
  # append in.value to buf
  val:_elem <- get *in, value:offset
  buf <- append buf, val
  # now prepare next
  next:address:list:_elem <- rest in
  nextn:number <- copy next
#?   buf <- append buf, nextn
  reply-unless next
  space:character <- copy 32/space
  buf <- append buf, space:character
  s:address:array:character <- new [-> ]
  n:number <- length *s
  buf <- append buf, s
  # and recurse
  remaining:number, optional-ingredient-found?:boolean <- next-ingredient
  {
    break-if optional-ingredient-found?
    # unlimited recursion
    buf <- to-buffer next, buf
    reply
  }
  {
    break-unless remaining
    # limited recursion
    remaining <- subtract remaining, 1
    buf <- to-buffer next, buf, remaining
    reply
  }
  # past recursion depth; insert ellipses and stop
  s:address:array:character <- new [...]
  append buf, s
]

scenario stash-on-list-converts-to-text [
  run [
    x:address:list:number <- push 4, 0
    x <- push 5, x
    x <- push 6, x
    stash [foo foo], x
  ]
  trace-should-contain [
    app: foo foo 6 -> 5 -> 4
  ]
]

scenario stash-handles-list-with-cycle [
  run [
    x:address:list:number <- push 4, 0
    y:address:address:list:number <- get-address *x, next:offset
    *y <- copy x
    stash [foo foo], x
  ]
  trace-should-contain [
    app: foo foo 4 -> 4 -> 4 -> 4 -> 4 -> 4 -> 4 -> ...
  ]
]

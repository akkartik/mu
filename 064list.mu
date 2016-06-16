# A list links up multiple objects together to make them easier to manage.
#
# The objects must be of the same type. If you want to store multiple types in
# a single list, use an exclusive-container.

container list:_elem [
  value:_elem
  next:address:list:_elem
]

def push x:_elem, in:address:list:_elem -> result:address:list:_elem [
  local-scope
  load-ingredients
  result <- new {(list _elem): type}
  *result <- merge x, in
]

def first in:address:list:_elem -> result:_elem [
  local-scope
  load-ingredients
  result <- get *in, value:offset
]

def rest in:address:list:_elem -> result:address:list:_elem/contained-in:in [
  local-scope
  load-ingredients
  result <- get *in, next:offset
]

scenario list-handling [
  run [
    local-scope
    x:address:list:number <- push 3, 0
    x <- push 4, x
    x <- push 5, x
    10:number/raw <- first x
    x <- rest x
    11:number/raw <- first x
    x <- rest x
    12:number/raw <- first x
    20:address:list:number/raw <- rest x
  ]
  memory-should-contain [
    10 <- 5
    11 <- 4
    12 <- 3
    20 <- 0  # nothing left
  ]
]

def length l:address:list:_elem -> result:number [
  local-scope
  load-ingredients
  return-unless l, 0
  rest:address:list:_elem <- rest l
  length-of-rest:number <- length rest
  result <- add length-of-rest, 1
]

# insert 'x' after 'in'
def insert x:_elem, in:address:list:_elem -> in:address:list:_elem [
  local-scope
  load-ingredients
  new-node:address:list:_elem <- new {(list _elem): type}
  *new-node <- put *new-node, value:offset, x
  next-node:address:list:_elem <- get *in, next:offset
  *in <- put *in, next:offset, new-node
  *new-node <- put *new-node, next:offset, next-node
]

scenario inserting-into-list [
  run [
    local-scope
    list:address:list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list2:address:list:character <- rest list  # inside list
    list2 <- insert 6, list2
    # check structure
    list2 <- copy list
    10:character/raw <- first list2
    list2 <- rest list2
    11:character/raw <- first list2
    list2 <- rest list2
    12:character/raw <- first list2
    list2 <- rest list2
    13:character/raw <- first list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 4
    12 <- 6  # inserted element
    13 <- 3
  ]
]

scenario inserting-at-end-of-list [
  run [
    local-scope
    list:address:list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list2:address:list:character <- rest list  # inside list
    list2 <- rest list2  # now at end of list
    list2 <- insert 6, list2
    # check structure like before
    list2 <- copy list
    10:character/raw <- first list2
    list2 <- rest list2
    11:character/raw <- first list2
    list2 <- rest list2
    12:character/raw <- first list2
    list2 <- rest list2
    13:character/raw <- first list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 4
    12 <- 3
    13 <- 6  # inserted element
  ]
]

scenario inserting-after-start-of-list [
  run [
    local-scope
    list:address:list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list <- insert 6, list
    # check structure like before
    list2:address:list:character <- copy list
    10:character/raw <- first list2
    list2 <- rest list2
    11:character/raw <- first list2
    list2 <- rest list2
    12:character/raw <- first list2
    list2 <- rest list2
    13:character/raw <- first list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 6  # inserted element
    12 <- 4
    13 <- 3
  ]
]

def to-text in:address:list:_elem -> result:address:array:character [
  local-scope
  load-ingredients
  buf:address:buffer <- new-buffer 80
  buf <- to-buffer in, buf
  result <- buffer-to-array buf
]

# variant of 'to-text' which stops printing after a few elements (and so is robust to cycles)
def to-text-line in:address:list:_elem -> result:address:array:character [
  local-scope
  load-ingredients
  buf:address:buffer <- new-buffer 80
  buf <- to-buffer in, buf, 6  # max elements to display
  result <- buffer-to-array buf
]

def to-buffer in:address:list:_elem, buf:address:buffer -> buf:address:buffer [
  local-scope
  load-ingredients
  {
    break-if in
    buf <- append buf, 48/0
    return
  }
  # append in.value to buf
  val:_elem <- get *in, value:offset
  buf <- append buf, val
  # now prepare next
  next:address:list:_elem <- rest in
  nextn:number <- copy next
  return-unless next
  buf <- append buf, [ -> ]
  # and recurse
  remaining:number, optional-ingredient-found?:boolean <- next-ingredient
  {
    break-if optional-ingredient-found?
    # unlimited recursion
    buf <- to-buffer next, buf
    return
  }
  {
    break-unless remaining
    # limited recursion
    remaining <- subtract remaining, 1
    buf <- to-buffer next, buf, remaining
    return
  }
  # past recursion depth; insert ellipses and stop
  append buf, [...]
]

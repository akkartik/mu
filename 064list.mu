# A list links up multiple objects together to make them easier to manage.
#
# The objects must be of the same type. If you want to store multiple types in
# a single list, use an exclusive-container.

container list:_elem [
  value:_elem
  next:&:list:_elem
]

def push x:_elem, in:&:list:_elem -> result:&:list:_elem [
  local-scope
  load-ingredients
  result <- new {(list _elem): type}
  *result <- merge x, in
]

def first in:&:list:_elem -> result:_elem [
  local-scope
  load-ingredients
  result <- get *in, value:offset
]

def rest in:&:list:_elem -> result:&:list:_elem/contained-in:in [
  local-scope
  load-ingredients
  result <- get *in, next:offset
]

scenario list-handling [
  run [
    local-scope
    x:&:list:num <- push 3, 0
    x <- push 4, x
    x <- push 5, x
    10:num/raw <- first x
    x <- rest x
    11:num/raw <- first x
    x <- rest x
    12:num/raw <- first x
    20:&:list:num/raw <- rest x
  ]
  memory-should-contain [
    10 <- 5
    11 <- 4
    12 <- 3
    20 <- 0  # nothing left
  ]
]

def length l:&:list:_elem -> result:num [
  local-scope
  load-ingredients
  return-unless l, 0
  rest:&:list:_elem <- rest l
  length-of-rest:num <- length rest
  result <- add length-of-rest, 1
]

# insert 'x' after 'in'
def insert x:_elem, in:&:list:_elem -> in:&:list:_elem [
  local-scope
  load-ingredients
  new-node:&:list:_elem <- new {(list _elem): type}
  *new-node <- put *new-node, value:offset, x
  next-node:&:list:_elem <- get *in, next:offset
  *in <- put *in, next:offset, new-node
  *new-node <- put *new-node, next:offset, next-node
]

scenario inserting-into-list [
  local-scope
  list:&:list:char <- push 3, 0
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:list:char <- rest list  # inside list
    list2 <- insert 6, list2
    # check structure
    list2 <- copy list
    10:char/raw <- first list2
    list2 <- rest list2
    11:char/raw <- first list2
    list2 <- rest list2
    12:char/raw <- first list2
    list2 <- rest list2
    13:char/raw <- first list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 4
    12 <- 6  # inserted element
    13 <- 3
  ]
]

scenario inserting-at-end-of-list [
  local-scope
  list:&:list:char <- push 3, 0
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:list:char <- rest list  # inside list
    list2 <- rest list2  # now at end of list
    list2 <- insert 6, list2
    # check structure like before
    list2 <- copy list
    10:char/raw <- first list2
    list2 <- rest list2
    11:char/raw <- first list2
    list2 <- rest list2
    12:char/raw <- first list2
    list2 <- rest list2
    13:char/raw <- first list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 4
    12 <- 3
    13 <- 6  # inserted element
  ]
]

scenario inserting-after-start-of-list [
  local-scope
  list:&:list:char <- push 3, 0
  list <- push 4, list
  list <- push 5, list
  run [
    list <- insert 6, list
    # check structure like before
    list2:&:list:char <- copy list
    10:char/raw <- first list2
    list2 <- rest list2
    11:char/raw <- first list2
    list2 <- rest list2
    12:char/raw <- first list2
    list2 <- rest list2
    13:char/raw <- first list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 6  # inserted element
    12 <- 4
    13 <- 3
  ]
]

# remove 'x' from its surrounding list 'in'
#
# Returns null if and only if list is empty. Beware: in that case any other
# pointers to the head are now invalid.
def remove x:&:list:_elem/contained-in:in, in:&:list:_elem -> in:&:list:_elem [
  local-scope
  load-ingredients
  # if 'x' is null, return
  return-unless x
  next-node:&:list:_elem <- rest x
  # clear next pointer of 'x'
  *x <- put *x, next:offset, 0
  # if 'x' is at the head of 'in', return the new head
  at-head?:bool <- equal x, in
  return-if at-head?, next-node
  # compute prev-node
  prev-node:&:list:_elem <- copy in
  curr:&:list:_elem <- rest prev-node
  {
    return-unless curr
    found?:bool <- equal curr, x
    break-if found?
    prev-node <- copy curr
    curr <- rest curr
  }
  # set its next pointer to skip 'x'
  *prev-node <- put *prev-node, next:offset, next-node
]

scenario removing-from-list [
  local-scope
  list:&:list:char <- push 3, 0
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:list:char <- rest list  # second element
    list <- remove list2, list
    10:bool/raw <- equal list2, 0
    # check structure like before
    list2 <- copy list
    11:char/raw <- first list2
    list2 <- rest list2
    12:char/raw <- first list2
    20:&:list:char/raw <- rest list2
  ]
  memory-should-contain [
    10 <- 0  # remove returned non-null
    11 <- 5  # scanning next, skipping deleted element
    12 <- 3
    20 <- 0  # no more elements
  ]
]

scenario removing-from-start-of-list [
  local-scope
  list:&:list:char <- push 3, 0
  list <- push 4, list
  list <- push 5, list
  run [
    list <- remove list, list
    # check structure like before
    list2:&:list:char <- copy list
    10:char/raw <- first list2
    list2 <- rest list2
    11:char/raw <- first list2
    20:&:list:char/raw <- rest list2
  ]
  memory-should-contain [
    10 <- 4  # scanning next, skipping deleted element
    11 <- 3
    20 <- 0  # no more elements
  ]
]

scenario removing-from-end-of-list [
  local-scope
  list:&:list:char <- push 3, 0
  list <- push 4, list
  list <- push 5, list
  run [
    # delete last element
    list2:&:list:char <- rest list
    list2 <- rest list2
    list <- remove list2, list
    10:bool/raw <- equal list2, 0
    # check structure like before
    list2 <- copy list
    11:char/raw <- first list2
    list2 <- rest list2
    12:char/raw <- first list2
    20:&:list:char/raw <- rest list2
  ]
  memory-should-contain [
    10 <- 0  # remove returned non-null
    11 <- 5  # scanning next, skipping deleted element
    12 <- 4
    20 <- 0  # no more elements
  ]
]

scenario removing-from-singleton-list [
  local-scope
  list:&:list:char <- push 3, 0
  run [
    list <- remove list, list
    1:num/raw <- copy list
  ]
  memory-should-contain [
    1 <- 0  # back to an empty list
  ]
]

# reverse the elements of a list
# (contributed by Caleb Couch)
def reverse list:&:list:_elem temp:&:list:_elem -> result:&:list:_elem [
  local-scope
  load-ingredients
  reply-unless list, temp
  object:_elem <- first, list
  list <- rest list
  temp <- push object, temp
  result <- reverse list, temp
]

scenario reverse-list [
  local-scope
  list:&:list:number <- push 1, 0
  list <- push 2, list
  list <- push 3, list
  run [
    stash [list:], list
    list <- reverse list
    stash [reversed:], list
  ]
  trace-should-contain [
    app: list: 3 -> 2 -> 1
    app: reversed: 1 -> 2 -> 3
  ]
]

def to-text in:&:list:_elem -> result:text [
  local-scope
  load-ingredients
  buf:&:buffer <- new-buffer 80
  buf <- to-buffer in, buf
  result <- buffer-to-array buf
]

# variant of 'to-text' which stops printing after a few elements (and so is robust to cycles)
def to-text-line in:&:list:_elem -> result:text [
  local-scope
  load-ingredients
  buf:&:buffer <- new-buffer 80
  buf <- to-buffer in, buf, 6  # max elements to display
  result <- buffer-to-array buf
]

def to-buffer in:&:list:_elem, buf:&:buffer -> buf:&:buffer [
  local-scope
  load-ingredients
  {
    break-if in
    buf <- append buf, [[]]
    return
  }
  # append in.value to buf
  val:_elem <- get *in, value:offset
  buf <- append buf, val
  # now prepare next
  next:&:list:_elem <- rest in
  nextn:num <- copy next
  return-unless next
  buf <- append buf, [ -> ]
  # and recurse
  remaining:num, optional-ingredient-found?:bool <- next-ingredient
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

scenario stash-empty-list [
  local-scope
  x:&:list:num <- copy 0
  run [
    stash x
  ]
  trace-should-contain [
    app: []
  ]
]

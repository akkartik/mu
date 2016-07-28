# A doubly linked list permits bidirectional traversal.

container duplex-list:_elem [
  value:_elem
  next:address:duplex-list:_elem
  prev:address:duplex-list:_elem
]

# should I say in/contained-in:result, allow ingredients to refer to products?
def push x:_elem, in:address:duplex-list:_elem -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  result:address:duplex-list:_elem <- new {(duplex-list _elem): type}
  *result <- merge x, in, 0
  {
    break-unless in
    *in <- put *in, prev:offset, result
  }
  return result  # needed explicitly because we need to replace 'in' with 'result'
]

def first in:address:duplex-list:_elem -> result:_elem [
  local-scope
  load-ingredients
  return-unless in, 0
  result <- get *in, value:offset
]

def next in:address:duplex-list:_elem -> result:address:duplex-list:_elem/contained-in:in [
  local-scope
  load-ingredients
  return-unless in, 0
  result <- get *in, next:offset
]

def prev in:address:duplex-list:_elem -> result:address:duplex-list:_elem/contained-in:in [
  local-scope
  load-ingredients
  return-unless in, 0
  result <- get *in, prev:offset
  return result
]

scenario duplex-list-handling [
  run [
    local-scope
    # reserve locations 0-9 to check for missing null check
    10:number/raw <- copy 34
    11:number/raw <- copy 35
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list2:address:duplex-list:character <- copy list
    20:character/raw <- first list2
    list2 <- next list2
    21:character/raw <- first list2
    list2 <- next list2
    22:character/raw <- first list2
    30:address:duplex-list:character/raw <- next list2
    31:character/raw <- first 30:address:duplex-list:character/raw
    32:address:duplex-list:character/raw <- next 30:address:duplex-list:character/raw
    33:address:duplex-list:character/raw <- prev 30:address:duplex-list:character/raw
    list2 <- prev list2
    40:character/raw <- first list2
    list2 <- prev list2
    41:character/raw <- first list2
    50:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    0 <- 0  # no modifications to null pointers
    10 <- 34
    11 <- 35
    20 <- 5  # scanning next
    21 <- 4
    22 <- 3
    30 <- 0  # null
    31 <- 0  # first of null
    32 <- 0  # next of null
    33 <- 0  # prev of null
    40 <- 4  # then start scanning prev
    41 <- 5
    50 <- 1  # list back at start
  ]
]

# insert 'x' after 'in'
def insert x:_elem, in:address:duplex-list:_elem -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  new-node:address:duplex-list:_elem <- new {(duplex-list _elem): type}
  *new-node <- put *new-node, value:offset, x
  # save old next before changing it
  next-node:address:duplex-list:_elem <- get *in, next:offset
  *in <- put *in, next:offset, new-node
  *new-node <- put *new-node, prev:offset, in
  *new-node <- put *new-node, next:offset, next-node
  return-unless next-node
  *next-node <- put *next-node, prev:offset, new-node
]

scenario inserting-into-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list2:address:duplex-list:character <- next list  # inside list
    list2 <- insert 6, list2
    # check structure like before
    list2 <- copy list
    10:character/raw <- first list2
    list2 <- next list2
    11:character/raw <- first list2
    list2 <- next list2
    12:character/raw <- first list2
    list2 <- next list2
    13:character/raw <- first list2
    list2 <- prev list2
    20:character/raw <- first list2
    list2 <- prev list2
    21:character/raw <- first list2
    list2 <- prev list2
    22:character/raw <- first list2
    30:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 4
    12 <- 6  # inserted element
    13 <- 3
    20 <- 6  # then prev
    21 <- 4
    22 <- 5
    30 <- 1  # list back at start
  ]
]

scenario inserting-at-end-of-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list2:address:duplex-list:character <- next list  # inside list
    list2 <- next list2  # now at end of list
    list2 <- insert 6, list2
    # check structure like before
    list2 <- copy list
    10:character/raw <- first list2
    list2 <- next list2
    11:character/raw <- first list2
    list2 <- next list2
    12:character/raw <- first list2
    list2 <- next list2
    13:character/raw <- first list2
    list2 <- prev list2
    20:character/raw <- first list2
    list2 <- prev list2
    21:character/raw <- first list2
    list2 <- prev list2
    22:character/raw <- first list2
    30:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 4
    12 <- 3
    13 <- 6  # inserted element
    20 <- 3  # then prev
    21 <- 4
    22 <- 5
    30 <- 1  # list back at start
  ]
]

scenario inserting-after-start-of-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list <- insert 6, list
    # check structure like before
    list2:address:duplex-list:character <- copy list
    10:character/raw <- first list2
    list2 <- next list2
    11:character/raw <- first list2
    list2 <- next list2
    12:character/raw <- first list2
    list2 <- next list2
    13:character/raw <- first list2
    list2 <- prev list2
    20:character/raw <- first list2
    list2 <- prev list2
    21:character/raw <- first list2
    list2 <- prev list2
    22:character/raw <- first list2
    30:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    10 <- 5  # scanning next
    11 <- 6  # inserted element
    12 <- 4
    13 <- 3
    20 <- 4  # then prev
    21 <- 6
    22 <- 5
    30 <- 1  # list back at start
  ]
]

# remove 'x' from its surrounding list 'in'
#
# Returns null if and only if list is empty. Beware: in that case any other
# pointers to the head are now invalid.
def remove x:address:duplex-list:_elem/contained-in:in, in:address:duplex-list:_elem -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  # if 'x' is null, return
  return-unless x
  next-node:address:duplex-list:_elem <- get *x, next:offset
  prev-node:address:duplex-list:_elem <- get *x, prev:offset
  # null x's pointers
  *x <- put *x, next:offset, 0
  *x <- put *x, prev:offset, 0
  # if next-node is not null, set its prev pointer
  {
    break-unless next-node
    *next-node <- put *next-node, prev:offset, prev-node
  }
  # if prev-node is not null, set its next pointer and return
  {
    break-unless prev-node
    *prev-node <- put *prev-node, next:offset, next-node
    return
  }
  # if prev-node is null, then we removed the head node at 'in'
  # return the new head rather than the old 'in'
  return next-node
]

scenario removing-from-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list2:address:duplex-list:character <- next list  # second element
    list <- remove list2, list
    10:boolean/raw <- equal list2, 0
    # check structure like before
    list2 <- copy list
    11:character/raw <- first list2
    list2 <- next list2
    12:character/raw <- first list2
    20:address:duplex-list:character/raw <- next list2
    list2 <- prev list2
    30:character/raw <- first list2
    40:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    10 <- 0  # remove returned non-null
    11 <- 5  # scanning next, skipping deleted element
    12 <- 3
    20 <- 0  # no more elements
    30 <- 5  # prev of final element
    40 <- 1  # list back at start
  ]
]

scenario removing-from-start-of-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    list <- remove list, list
    # check structure like before
    list2:address:duplex-list:character <- copy list
    10:character/raw <- first list2
    list2 <- next list2
    11:character/raw <- first list2
    20:address:duplex-list:character/raw <- next list2
    list2 <- prev list2
    30:character/raw <- first list2
    40:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    10 <- 4  # scanning next, skipping deleted element
    11 <- 3
    20 <- 0  # no more elements
    30 <- 4  # prev of final element
    40 <- 1  # list back at start
  ]
]

scenario removing-from-end-of-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- push 4, list
    list <- push 5, list
    # delete last element
    list2:address:duplex-list:character <- next list
    list2 <- next list2
    list <- remove list2, list
    10:boolean/raw <- equal list2, 0
    # check structure like before
    list2 <- copy list
    11:character/raw <- first list2
    list2 <- next list2
    12:character/raw <- first list2
    20:address:duplex-list:character/raw <- next list2
    list2 <- prev list2
    30:character/raw <- first list2
    40:boolean/raw <- equal list, list2
  ]
  memory-should-contain [
    10 <- 0  # remove returned non-null
    11 <- 5  # scanning next, skipping deleted element
    12 <- 4
    20 <- 0  # no more elements
    30 <- 5  # prev of final element
    40 <- 1  # list back at start
  ]
]

scenario removing-from-singleton-duplex-list [
  run [
    local-scope
    list:address:duplex-list:character <- push 3, 0
    list <- remove list, list
    1:number/raw <- copy list
  ]
  memory-should-contain [
    1 <- 0  # back to an empty list
  ]
]

# remove values between 'start' and 'end' (both exclusive).
# also clear pointers back out from start/end for hygiene.
# set end to 0 to delete everything past start.
# can't set start to 0 to delete everything before end, because there's no
# clean way to return the new head pointer.
def remove-between start:address:duplex-list:_elem, end:address:duplex-list:_elem/contained-in:start -> start:address:duplex-list:_elem [
  local-scope
  load-ingredients
  next:address:duplex-list:_elem <- get *start, next:offset
  nothing-to-delete?:boolean <- equal next, end
  return-if nothing-to-delete?
  assert next, [malformed duplex list]
  # start->next->prev = 0
  # start->next = end
  *next <- put *next, prev:offset, 0
  *start <- put *start, next:offset, end
  return-unless end
  # end->prev->next = 0
  # end->prev = start
  prev:address:duplex-list:_elem <- get *end, prev:offset
  assert prev, [malformed duplex list - 2]
  *prev <- put *prev, next:offset, 0
  *end <- put *end, prev:offset, start
]

scenario remove-range [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  local-scope
  list:address:duplex-list:character <- push 18, 0
  list <- push 17, list
  list <- push 16, list
  list <- push 15, list
  list <- push 14, list
  list <- push 13, list
  1:address:duplex-list:character/raw <- copy list  # save list
  run [
    local-scope
    list:address:duplex-list:character <- copy 1:address:duplex-list:character/raw  # restore list
    # delete 16 onwards
    # first pointer: to the third element
    list2:address:duplex-list:character <- next list
    list2 <- next list2
    list2 <- remove-between list2, 0
    # now check the list
    10:character/raw <- get *list, value:offset
    list <- next list
    11:character/raw <- get *list, value:offset
    list <- next list
    12:character/raw <- get *list, value:offset
    20:address:duplex-list:character/raw <- next list
  ]
  memory-should-contain [
    10 <- 13
    11 <- 14
    12 <- 15
    20 <- 0
  ]
]

scenario remove-range-to-final [
  local-scope
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  list:address:duplex-list:character <- push 18, 0
  list <- push 17, list
  list <- push 16, list
  list <- push 15, list
  list <- push 14, list
  list <- push 13, list
  1:address:duplex-list:character/raw <- copy list  # save list
  run [
    local-scope
    list:address:duplex-list:character <- copy 1:address:duplex-list:character/raw  # restore list
    # delete 15, 16 and 17
    # start pointer: to the second element
    list2:address:duplex-list:character <- next list
    # end pointer: to the last (sixth) element
    end:address:duplex-list:character <- next list2
    end <- next end
    end <- next end
    end <- next end
    remove-between list2, end
    # now check the list
    10:character/raw <- get *list, value:offset
    list <- next list
    11:character/raw <- get *list, value:offset
    list <- next list
    12:character/raw <- get *list, value:offset
    20:address:duplex-list:character/raw <- next list
  ]
  memory-should-contain [
    10 <- 13
    11 <- 14
    12 <- 18
    20 <- 0  # no more elements
  ]
]

scenario remove-range-empty [
  local-scope
  # construct a duplex list with three elements [13, 14, 15]
  list:address:duplex-list:character <- push 15, 0
  list <- push 14, list
  list <- push 13, list
  1:address:duplex-list:character/raw <- copy list  # save list
  run [
    local-scope
    list:address:duplex-list:character <- copy 1:address:duplex-list:character/raw  # restore list
    # delete between first and second element (i.e. nothing)
    list2:address:duplex-list:character <- next list
    remove-between list, list2
    # now check the list
    10:character/raw <- get *list, value:offset
    list <- next list
    11:character/raw <- get *list, value:offset
    list <- next list
    12:character/raw <- get *list, value:offset
    20:address:duplex-list:character/raw <- next list
  ]
  # no change
  memory-should-contain [
    10 <- 13
    11 <- 14
    12 <- 15
    20 <- 0
  ]
]

scenario remove-range-to-end [
  local-scope
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  list:address:duplex-list:character <- push 18, 0
  list <- push 17, list
  list <- push 16, list
  list <- push 15, list
  list <- push 14, list
  list <- push 13, list
  1:address:duplex-list:character/raw <- copy list  # save list
  run [
    local-scope
    list:address:duplex-list:character <- copy 1:address:duplex-list:character/raw  # restore list
    # remove the third element and beyond
    list2:address:duplex-list:character <- next list
    remove-between list2, 0
    # now check the list
    10:character/raw <- get *list, value:offset
    list <- next list
    11:character/raw <- get *list, value:offset
    20:address:duplex-list:character/raw <- next list
  ]
  memory-should-contain [
    10 <- 13
    11 <- 14
    20 <- 0
  ]
]

# insert list beginning at 'new' after 'in'
def insert-range in:address:duplex-list:_elem, start:address:duplex-list:_elem/contained-in:in -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  return-unless in
  return-unless start
  end:address:duplex-list:_elem <- copy start
  {
    next:address:duplex-list:_elem <- next end/insert-range
    break-unless next
    end <- copy next
    loop
  }
  next:address:duplex-list:_elem <- next in
  *end <- put *end, next:offset, next
  {
    break-unless next
    *next <- put *next, prev:offset, end
  }
  *in <- put *in, next:offset, start
  *start <- put *start, prev:offset, in
]

def append in:address:duplex-list:_elem, new:address:duplex-list:_elem/contained-in:in -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  last:address:duplex-list:_elem <- last in
  *last <- put *last, next:offset, new
  return-unless new
  *new <- put *new, prev:offset, last
]

def last in:address:duplex-list:_elem -> result:address:duplex-list:_elem [
  local-scope
  load-ingredients
  result <- copy in
  {
    next:address:duplex-list:_elem <- next result
    break-unless next
    result <- copy next
    loop
  }
]

# helper for debugging
def dump-from x:address:duplex-list:_elem [
  local-scope
  load-ingredients
  $print x, [: ]
  {
    break-unless x
    c:_elem <- get *x, value:offset
    $print c, [ ]
    x <- next x
    {
      is-newline?:boolean <- equal c, 10/newline
      break-unless is-newline?
      $print 10/newline
      $print x, [: ]
    }
    loop
  }
  $print 10/newline, [---], 10/newline
]

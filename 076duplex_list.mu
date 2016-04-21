# A doubly linked list permits bidirectional traversal.

container duplex-list:_elem [
  value:_elem
  next:address:shared:duplex-list:_elem
  prev:address:shared:duplex-list:_elem
]

# should I say in/contained-in:result, allow ingredients to refer to products?
def push x:_elem, in:address:shared:duplex-list:_elem -> in:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  result:address:shared:duplex-list:_elem <- new {(duplex-list _elem): type}
  *result <- merge x, in, 0
  {
    break-unless in
    *in <- put *in, prev:offset, result
  }
  return result  # needed explicitly because we need to replace 'in' with 'result'
]

def first in:address:shared:duplex-list:_elem -> result:_elem [
  local-scope
  load-ingredients
  return-unless in, 0
  result <- get *in, value:offset
]

def next in:address:shared:duplex-list:_elem -> result:address:shared:duplex-list:_elem/contained-in:in [
  local-scope
  load-ingredients
  return-unless in, 0
  result <- get *in, next:offset
]

def prev in:address:shared:duplex-list:_elem -> result:address:shared:duplex-list:_elem/contained-in:in [
  local-scope
  load-ingredients
  return-unless in, 0
  result <- get *in, prev:offset
  return result
]

scenario duplex-list-handling [
  run [
    # reserve locations 0, 1 and 2 to check for missing null check
    1:number <- copy 34
    2:number <- copy 35
    3:address:shared:duplex-list:character <- push 3, 0
    3:address:shared:duplex-list:character <- push 4, 3:address:shared:duplex-list:character
    3:address:shared:duplex-list:character <- push 5, 3:address:shared:duplex-list:character
    4:address:shared:duplex-list:character <- copy 3:address:shared:duplex-list:character
    5:character <- first 4:address:shared:duplex-list:character
    4:address:shared:duplex-list:character <- next 4:address:shared:duplex-list:character
    6:character <- first 4:address:shared:duplex-list:character
    4:address:shared:duplex-list:character <- next 4:address:shared:duplex-list:character
    7:character <- first 4:address:shared:duplex-list:character
    8:address:shared:duplex-list:character <- next 4:address:shared:duplex-list:character
    9:character <- first 8:address:shared:duplex-list:character
    10:address:shared:duplex-list:character <- next 8:address:shared:duplex-list:character
    11:address:shared:duplex-list:character <- prev 8:address:shared:duplex-list:character
    4:address:shared:duplex-list:character <- prev 4:address:shared:duplex-list:character
    12:character <- first 4:address:shared:duplex-list:character
    4:address:shared:duplex-list:character <- prev 4:address:shared:duplex-list:character
    13:character <- first 4:address:shared:duplex-list:character
    14:boolean <- equal 3:address:shared:duplex-list:character, 4:address:shared:duplex-list:character
  ]
  memory-should-contain [
    0 <- 0  # no modifications to null pointers
    1 <- 34
    2 <- 35
    5 <- 5  # scanning next
    6 <- 4
    7 <- 3
    8 <- 0  # null
    9 <- 0  # first of null
    10 <- 0  # next of null
    11 <- 0  # prev of null
    12 <- 4  # then start scanning prev
    13 <- 5
    14 <- 1  # list back at start
  ]
]

# insert 'x' after 'in'
def insert x:_elem, in:address:shared:duplex-list:_elem -> in:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  new-node:address:shared:duplex-list:_elem <- new {(duplex-list _elem): type}
  *new-node <- put *new-node, value:offset, x
  # save old next before changing it
  next-node:address:shared:duplex-list:_elem <- get *in, next:offset
  *in <- put *in, next:offset, new-node
  *new-node <- put *new-node, prev:offset, in
  *new-node <- put *new-node, next:offset, next-node
  return-unless next-node
  *next-node <- put *next-node, prev:offset, new-node
]

scenario inserting-into-duplex-list [
  run [
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- push 4, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- push 5, 1:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character  # 2 points inside list
    2:address:shared:duplex-list:character <- insert 6, 2:address:shared:duplex-list:character
    # check structure like before
    2:address:shared:duplex-list:character <- copy 1:address:shared:duplex-list:character
    3:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    4:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    5:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    6:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    7:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    8:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    9:character <- first 2:address:shared:duplex-list:character
    10:boolean <- equal 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
  ]
  memory-should-contain [
    3 <- 5  # scanning next
    4 <- 4
    5 <- 6  # inserted element
    6 <- 3
    7 <- 6  # then prev
    8 <- 4
    9 <- 5
    10 <- 1  # list back at start
  ]
]

scenario inserting-at-end-of-duplex-list [
  run [
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- push 4, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- push 5, 1:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character  # 2 points inside list
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character  # now at end of list
    2:address:shared:duplex-list:character <- insert 6, 2:address:shared:duplex-list:character
    # check structure like before
    2:address:shared:duplex-list:character <- copy 1:address:shared:duplex-list:character
    3:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    4:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    5:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    6:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    7:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    8:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    9:character <- first 2:address:shared:duplex-list:character
    10:boolean <- equal 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
  ]
  memory-should-contain [
    3 <- 5  # scanning next
    4 <- 4
    5 <- 3
    6 <- 6  # inserted element
    7 <- 3  # then prev
    8 <- 4
    9 <- 5
    10 <- 1  # list back at start
  ]
]

scenario inserting-after-start-of-duplex-list [
  run [
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- push 4, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- push 5, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- insert 6, 1:address:shared:duplex-list:character
    # check structure like before
    2:address:shared:duplex-list:character <- copy 1:address:shared:duplex-list:character
    3:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    4:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    5:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    6:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    7:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    8:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    9:character <- first 2:address:shared:duplex-list:character
    10:boolean <- equal 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
  ]
  memory-should-contain [
    3 <- 5  # scanning next
    4 <- 6  # inserted element
    5 <- 4
    6 <- 3
    7 <- 4  # then prev
    8 <- 6
    9 <- 5
    10 <- 1  # list back at start
  ]
]

# remove 'x' from its surrounding list 'in'
#
# Returns null if and only if list is empty. Beware: in that case any other
# pointers to the head are now invalid.
def remove x:address:shared:duplex-list:_elem/contained-in:in, in:address:shared:duplex-list:_elem -> in:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  # if 'x' is null, return
  return-unless x
  next-node:address:shared:duplex-list:_elem <- get *x, next:offset
  prev-node:address:shared:duplex-list:_elem <- get *x, prev:offset
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
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- push 4, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- push 5, 1:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character  # 2 points at second element
    1:address:shared:duplex-list:character <- remove 2:address:shared:duplex-list:character, 1:address:shared:duplex-list:character
    3:boolean <- equal 2:address:shared:duplex-list:character, 0
    # check structure like before
    2:address:shared:duplex-list:character <- copy 1:address:shared:duplex-list:character
    4:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    5:character <- first 2:address:shared:duplex-list:character
    6:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    7:character <- first 2:address:shared:duplex-list:character
    8:boolean <- equal 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
  ]
  memory-should-contain [
    3 <- 0  # remove returned non-null
    4 <- 5  # scanning next, skipping deleted element
    5 <- 3
    6 <- 0  # no more elements
    7 <- 5  # prev of final element
    8 <- 1  # list back at start
  ]
]

scenario removing-from-start-of-duplex-list [
  run [
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- push 4, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- push 5, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- remove 1:address:shared:duplex-list:character, 1:address:shared:duplex-list:character
    # check structure like before
    2:address:shared:duplex-list:character <- copy 1:address:shared:duplex-list:character
    3:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    4:character <- first 2:address:shared:duplex-list:character
    5:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    6:character <- first 2:address:shared:duplex-list:character
    7:boolean <- equal 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
  ]
  memory-should-contain [
    3 <- 4  # scanning next, skipping deleted element
    4 <- 3
    5 <- 0  # no more elements
    6 <- 4  # prev of final element
    7 <- 1  # list back at start
  ]
]

scenario removing-from-end-of-duplex-list [
  run [
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- push 4, 1:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- push 5, 1:address:shared:duplex-list:character
    # delete last element
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    1:address:shared:duplex-list:character <- remove 2:address:shared:duplex-list:character, 1:address:shared:duplex-list:character
    3:boolean <- equal 2:address:shared:duplex-list:character, 0
    # check structure like before
    2:address:shared:duplex-list:character <- copy 1:address:shared:duplex-list:character
    4:character <- first 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    5:character <- first 2:address:shared:duplex-list:character
    6:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- prev 2:address:shared:duplex-list:character
    7:character <- first 2:address:shared:duplex-list:character
    8:boolean <- equal 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
  ]
  memory-should-contain [
    3 <- 0  # remove returned non-null
    4 <- 5  # scanning next, skipping deleted element
    5 <- 4
    6 <- 0  # no more elements
    7 <- 5  # prev of final element
    8 <- 1  # list back at start
  ]
]

scenario removing-from-singleton-list [
  run [
    1:address:shared:duplex-list:character <- push 3, 0
    1:address:shared:duplex-list:character <- remove 1:address:shared:duplex-list:character, 1:address:shared:duplex-list:character
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
def remove-between start:address:shared:duplex-list:_elem, end:address:shared:duplex-list:_elem/contained-in:start -> start:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  next:address:shared:duplex-list:_elem <- get *start, next:offset
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
  prev:address:shared:duplex-list:_elem <- get *end, prev:offset
  assert prev, [malformed duplex list - 2]
  *prev <- put *prev, next:offset, 0
  *end <- put *end, prev:offset, start
]

scenario remove-range [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:shared:duplex-list:character <- push 18, 0
  1:address:shared:duplex-list:character <- push 17, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 16, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 15, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 14, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 13, 1:address:shared:duplex-list:character
  run [
    # delete 16 onwards
    # first pointer: to the third element
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    2:address:shared:duplex-list:character <- remove-between 2:address:shared:duplex-list:character, 0
    # now check the list
    4:character <- get *1:address:shared:duplex-list:character, value:offset
    5:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    6:character <- get *5:address:shared:duplex-list:character, value:offset
    7:address:shared:duplex-list:character <- next 5:address:shared:duplex-list:character
    8:character <- get *7:address:shared:duplex-list:character, value:offset
    9:address:shared:duplex-list:character <- next 7:address:shared:duplex-list:character
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    8 <- 15
    9 <- 0
  ]
]

scenario remove-range-to-final [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:shared:duplex-list:character <- push 18, 0
  1:address:shared:duplex-list:character <- push 17, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 16, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 15, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 14, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 13, 1:address:shared:duplex-list:character
  run [
    # delete 15, 16 and 17
    # start pointer: to the second element
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    # end pointer: to the last (sixth) element
    3:address:shared:duplex-list:character <- next 2:address:shared:duplex-list:character
    3:address:shared:duplex-list:character <- next 3:address:shared:duplex-list:character
    3:address:shared:duplex-list:character <- next 3:address:shared:duplex-list:character
    3:address:shared:duplex-list:character <- next 3:address:shared:duplex-list:character
    remove-between 2:address:shared:duplex-list:character, 3:address:shared:duplex-list:character
    # now check the list
    4:character <- get *1:address:shared:duplex-list:character, value:offset
    5:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    6:character <- get *5:address:shared:duplex-list:character, value:offset
    7:address:shared:duplex-list:character <- next 5:address:shared:duplex-list:character
    8:character <- get *7:address:shared:duplex-list:character, value:offset
    9:address:shared:duplex-list:character <- next 7:address:shared:duplex-list:character
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    8 <- 18
    9 <- 0
  ]
]

scenario remove-range-empty [
  # construct a duplex list with three elements [13, 14, 15]
  1:address:shared:duplex-list:character <- push 15, 0
  1:address:shared:duplex-list:character <- push 14, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 13, 1:address:shared:duplex-list:character
  run [
    # delete between first and second element (i.e. nothing)
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    remove-between 1:address:shared:duplex-list:character, 2:address:shared:duplex-list:character
    # now check the list
    4:character <- get *1:address:shared:duplex-list:character, value:offset
    5:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    6:character <- get *5:address:shared:duplex-list:character, value:offset
    7:address:shared:duplex-list:character <- next 5:address:shared:duplex-list:character
    8:character <- get *7:address:shared:duplex-list:character, value:offset
    9:address:shared:duplex-list:character <- next 7:address:shared:duplex-list:character
  ]
  # no change
  memory-should-contain [
    4 <- 13
    6 <- 14
    8 <- 15
    9 <- 0
  ]
]

scenario remove-range-to-end [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:shared:duplex-list:character <- push 18, 0
  1:address:shared:duplex-list:character <- push 17, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 16, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 15, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 14, 1:address:shared:duplex-list:character
  1:address:shared:duplex-list:character <- push 13, 1:address:shared:duplex-list:character
  run [
    # remove the third element and beyond
    2:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    remove-between 2:address:shared:duplex-list:character, 0
    # now check the list
    4:character <- get *1:address:shared:duplex-list:character, value:offset
    5:address:shared:duplex-list:character <- next 1:address:shared:duplex-list:character
    6:character <- get *5:address:shared:duplex-list:character, value:offset
    7:address:shared:duplex-list:character <- next 5:address:shared:duplex-list:character
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    7 <- 0
  ]
]

# insert list beginning at 'new' after 'in'
def insert-range in:address:shared:duplex-list:_elem, start:address:shared:duplex-list:_elem/contained-in:in -> in:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  return-unless in
  return-unless start
  end:address:shared:duplex-list:_elem <- copy start
  {
    next:address:shared:duplex-list:_elem <- next end/insert-range
    break-unless next
    end <- copy next
    loop
  }
  next:address:shared:duplex-list:_elem <- next in
  *end <- put *end, next:offset, next
  {
    break-unless next
    *next <- put *next, prev:offset, end
  }
  *in <- put *in, next:offset, start
  *start <- put *start, prev:offset, in
]

def append in:address:shared:duplex-list:_elem, new:address:shared:duplex-list:_elem/contained-in:in -> in:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  last:address:shared:duplex-list:_elem <- last in
  *last <- put *last, next:offset, new
  return-unless new
  *new <- put *new, prev:offset, last
]

def last in:address:shared:duplex-list:_elem -> result:address:shared:duplex-list:_elem [
  local-scope
  load-ingredients
  result <- copy in
  {
    next:address:shared:duplex-list:_elem <- next result
    break-unless next
    result <- copy next
    loop
  }
]

# helper for debugging
def dump-from x:address:shared:duplex-list:_elem [
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

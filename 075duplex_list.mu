# A doubly linked list permits bidirectional traversal.

container duplex-list:_elem [
  value:_elem
  next:address:duplex-list:_elem
  prev:address:duplex-list:_elem
]

recipe push x:_elem, in:address:duplex-list:_elem -> result:address:duplex-list:_elem [
  local-scope
  load-ingredients
  result <- new {(duplex-list _elem): type}
  val:address:_elem <- get-address *result, value:offset
  *val <- copy x
  next:address:address:duplex-list:_elem <- get-address *result, next:offset
  *next <- copy in
  reply-unless in
  prev:address:address:duplex-list:_elem <- get-address *in, prev:offset
  *prev <- copy result
]

recipe first in:address:duplex-list:_elem -> result:_elem [
  local-scope
  load-ingredients
  reply-unless in, 0
  result <- get *in, value:offset
]

recipe next in:address:duplex-list:_elem -> result:address:duplex-list:_elem [
  local-scope
  load-ingredients
  reply-unless in, 0
  result <- get *in, next:offset
]

recipe prev in:address:duplex-list:_elem -> result:address:duplex-list:_elem [
  local-scope
  load-ingredients
  reply-unless in, 0
  result <- get *in, prev:offset
  reply result
]

scenario duplex-list-handling [
  run [
    # reserve locations 0, 1 and 2 to check for missing null check
    1:number <- copy 34
    2:number <- copy 35
    3:address:duplex-list:character <- push 3, 0
    3:address:duplex-list:character <- push 4, 3:address:duplex-list:character
    3:address:duplex-list:character <- push 5, 3:address:duplex-list:character
    4:address:duplex-list:character <- copy 3:address:duplex-list:character
    5:character <- first 4:address:duplex-list:character
    4:address:duplex-list:character <- next 4:address:duplex-list:character
    6:character <- first 4:address:duplex-list:character
    4:address:duplex-list:character <- next 4:address:duplex-list:character
    7:character <- first 4:address:duplex-list:character
    8:address:duplex-list:character <- next 4:address:duplex-list:character
    9:character <- first 8:address:duplex-list:character
    10:address:duplex-list:character <- next 8:address:duplex-list:character
    11:address:duplex-list:character <- prev 8:address:duplex-list:character
    4:address:duplex-list:character <- prev 4:address:duplex-list:character
    12:character <- first 4:address:duplex-list:character
    4:address:duplex-list:character <- prev 4:address:duplex-list:character
    13:character <- first 4:address:duplex-list:character
    14:boolean <- equal 3:address:duplex-list:character, 4:address:duplex-list:character
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

# Inserts 'x' after 'in'. Returns some pointer into the list.
recipe insert x:_elem, in:address:duplex-list:_elem -> new-node:address:duplex-list:_elem [
  local-scope
  load-ingredients
  new-node <- new {(duplex-list _elem): type}
  val:address:_elem <- get-address *new-node, value:offset
  *val <- copy x
  next-node:address:duplex-list:_elem <- get *in, next:offset
  # in.next = new-node
  y:address:address:duplex-list:_elem <- get-address *in, next:offset
  *y <- copy new-node
  # new-node.prev = in
  y <- get-address *new-node, prev:offset
  *y <- copy in
  # new-node.next = next-node
  y <- get-address *new-node, next:offset
  *y <- copy next-node
  # if next-node is not null
  reply-unless next-node, new-node
  # next-node.prev = new-node
  y <- get-address *next-node, prev:offset
  *y <- copy new-node
  reply new-node  # just signalling something changed; don't rely on the result
]

scenario inserting-into-duplex-list [
  run [
    1:address:duplex-list:character <- push 3, 0
    1:address:duplex-list:character <- push 4, 1:address:duplex-list:character
    1:address:duplex-list:character <- push 5, 1:address:duplex-list:character
    2:address:duplex-list:character <- next 1:address:duplex-list:character  # 2 points inside list
    2:address:duplex-list:character <- insert 6, 2:address:duplex-list:character
    # check structure like before
    2:address:duplex-list:character <- copy 1:address:duplex-list:character
    3:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    4:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    5:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    6:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    7:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    8:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    9:character <- first 2:address:duplex-list:character
    10:boolean <- equal 1:address:duplex-list:character, 2:address:duplex-list:character
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
    1:address:duplex-list:character <- push 3, 0
    1:address:duplex-list:character <- push 4, 1:address:duplex-list:character
    1:address:duplex-list:character <- push 5, 1:address:duplex-list:character
    2:address:duplex-list:character <- next 1:address:duplex-list:character  # 2 points inside list
    2:address:duplex-list:character <- next 2:address:duplex-list:character  # now at end of list
    2:address:duplex-list:character <- insert 6, 2:address:duplex-list:character
    # check structure like before
    2:address:duplex-list:character <- copy 1:address:duplex-list:character
    3:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    4:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    5:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    6:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    7:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    8:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    9:character <- first 2:address:duplex-list:character
    10:boolean <- equal 1:address:duplex-list:character, 2:address:duplex-list:character
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
    1:address:duplex-list:character <- push 3, 0
    1:address:duplex-list:character <- push 4, 1:address:duplex-list:character
    1:address:duplex-list:character <- push 5, 1:address:duplex-list:character
    2:address:duplex-list:character <- insert 6, 1:address:duplex-list:character
    # check structure like before
    2:address:duplex-list:character <- copy 1:address:duplex-list:character
    3:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    4:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    5:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    6:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    7:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    8:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    9:character <- first 2:address:duplex-list:character
    10:boolean <- equal 1:address:duplex-list:character, 2:address:duplex-list:character
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

# Removes 'in' from its surrounding list. Returns some valid pointer into the
# rest of the list.
#
# Returns null if and only if list is empty. Beware: in that case any pointers
# to the head are now invalid.
recipe remove in:address:duplex-list:_elem -> next-node:address:duplex-list:_elem [
  local-scope
  load-ingredients
  # if 'in' is null, return
  reply-unless in, in
  next-node:address:duplex-list:_elem <- get *in, next:offset
  prev-node:address:duplex-list:_elem <- get *in, prev:offset
  # null in's pointers
  x:address:address:duplex-list:_elem <- get-address *in, next:offset
  *x <- copy 0
  x <- get-address *in, prev:offset
  *x <- copy 0
  {
    # if next-node is not null
    break-unless next-node
    # next-node.prev = prev-node
    x <- get-address *next-node, prev:offset
    *x <- copy prev-node
  }
  {
    # if prev-node is not null
    break-unless prev-node
    # prev-node.next = next-node
    x <- get-address *prev-node, next:offset
    *x <- copy next-node
    reply prev-node
  }
  reply next-node
]

scenario removing-from-duplex-list [
  run [
    1:address:duplex-list:character <- push 3, 0
    1:address:duplex-list:character <- push 4, 1:address:duplex-list:character
    1:address:duplex-list:character <- push 5, 1:address:duplex-list:character
    2:address:duplex-list:character <- next 1:address:duplex-list:character  # 2 points at second element
    2:address:duplex-list:character <- remove 2:address:duplex-list:character
    3:boolean <- equal 2:address:duplex-list:character, 0
    # check structure like before
    2:address:duplex-list:character <- copy 1:address:duplex-list:character
    4:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    5:character <- first 2:address:duplex-list:character
    6:address:duplex-list:character <- next 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    7:character <- first 2:address:duplex-list:character
    8:boolean <- equal 1:address:duplex-list:character, 2:address:duplex-list:character
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
    1:address:duplex-list:character <- push 3, 0
    1:address:duplex-list:character <- push 4, 1:address:duplex-list:character
    1:address:duplex-list:character <- push 5, 1:address:duplex-list:character
    # removing from head? return value matters.
    1:address:duplex-list:character <- remove 1:address:duplex-list:character
    # check structure like before
    2:address:duplex-list:character <- copy 1:address:duplex-list:character
    3:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    4:character <- first 2:address:duplex-list:character
    5:address:duplex-list:character <- next 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    6:character <- first 2:address:duplex-list:character
    7:boolean <- equal 1:address:duplex-list:character, 2:address:duplex-list:character
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
    1:address:duplex-list:character <- push 3, 0
    1:address:duplex-list:character <- push 4, 1:address:duplex-list:character
    1:address:duplex-list:character <- push 5, 1:address:duplex-list:character
    # delete last element
    2:address:duplex-list:character <- next 1:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    2:address:duplex-list:character <- remove 2:address:duplex-list:character
    3:boolean <- equal 2:address:duplex-list:character, 0
    # check structure like before
    2:address:duplex-list:character <- copy 1:address:duplex-list:character
    4:character <- first 2:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    5:character <- first 2:address:duplex-list:character
    6:address:duplex-list:character <- next 2:address:duplex-list:character
    2:address:duplex-list:character <- prev 2:address:duplex-list:character
    7:character <- first 2:address:duplex-list:character
    8:boolean <- equal 1:address:duplex-list:character, 2:address:duplex-list:character
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
    1:address:duplex-list:character <- push 3, 0
    2:address:duplex-list:character <- remove 1:address:duplex-list:character
    3:address:duplex-list:character <- get *1:address:duplex-list:character, next:offset
    4:address:duplex-list:character <- get *1:address:duplex-list:character, prev:offset
  ]
  memory-should-contain [
    2 <- 0  # remove returned null
    3 <- 0  # removed node is also detached
    4 <- 0
  ]
]

# remove values between 'start' and 'end' (both exclusive)
# also clear pointers back out from start/end for hygiene
recipe remove-between start:address:duplex-list:_elem, end:address:duplex-list:_elem -> start:address:duplex-list:_elem [
  local-scope
  load-ingredients
  reply-unless start
  # start->next->prev = 0
  # start->next = end
  next:address:address:duplex-list:_elem <- get-address *start, next:offset
  nothing-to-delete?:boolean <- equal *next, end
  reply-if nothing-to-delete?
  prev:address:address:duplex-list:_elem <- get-address **next, prev:offset
  *prev <- copy 0
  *next <- copy end
  reply-unless end
  # end->prev->next = 0
  # end->prev = start
  prev <- get-address *end, prev:offset
  next <- get-address **prev, next:offset
  *next <- copy 0
  *prev <- copy start
]

scenario remove-range [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:duplex-list:character <- push 18, 0
  1:address:duplex-list:character <- push 17, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 16, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 15, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 14, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 13, 1:address:duplex-list:character
  run [
    # delete 16 onwards
    # first pointer: to the third element
    2:address:duplex-list:character <- next 1:address:duplex-list:character
    2:address:duplex-list:character <- next 2:address:duplex-list:character
    2:address:duplex-list:character <- remove-between 2:address:duplex-list:character, 0
    # now check the list
    4:character <- get *1:address:duplex-list:character, value:offset
    5:address:duplex-list:character <- next 1:address:duplex-list:character
    6:character <- get *5:address:duplex-list:character, value:offset
    7:address:duplex-list:character <- next 5:address:duplex-list:character
    8:character <- get *7:address:duplex-list:character, value:offset
    9:address:duplex-list:character <- next 7:address:duplex-list:character
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    8 <- 15
    9 <- 0
  ]
]

scenario remove-range-to-end [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:duplex-list:character <- push 18, 0
  1:address:duplex-list:character <- push 17, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 16, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 15, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 14, 1:address:duplex-list:character
  1:address:duplex-list:character <- push 13, 1:address:duplex-list:character
  run [
    # delete 15, 16 and 17
    # first pointer: to the third element
    2:address:duplex-list:character <- next 1:address:duplex-list:character
    # second pointer: to the fifth element
    3:address:duplex-list:character <- next 2:address:duplex-list:character
    3:address:duplex-list:character <- next 3:address:duplex-list:character
    3:address:duplex-list:character <- next 3:address:duplex-list:character
    3:address:duplex-list:character <- next 3:address:duplex-list:character
    remove-between 2:address:duplex-list:character, 3:address:duplex-list:character
    # now check the list
    4:character <- get *1:address:duplex-list:character, value:offset
    5:address:duplex-list:character <- next 1:address:duplex-list:character
    6:character <- get *5:address:duplex-list:character, value:offset
    7:address:duplex-list:character <- next 5:address:duplex-list:character
    8:character <- get *7:address:duplex-list:character, value:offset
    9:address:duplex-list:character <- next 7:address:duplex-list:character
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    8 <- 18
    9 <- 0
  ]
]

scenario remove-range-empty [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:duplex-list:character <- push 14, 0
  1:address:duplex-list:character <- push 13, 1:address:duplex-list:character
  run [
    # delete 16 onwards
    # first pointer: to the third element
    2:address:duplex-list:character <- next 1:address:duplex-list:character
    remove-between 1:address:duplex-list:character, 2:address:duplex-list:character
    # now check the list
    4:character <- get *1:address:duplex-list:character, value:offset
    5:address:duplex-list:character <- next 1:address:duplex-list:character
    6:character <- get *5:address:duplex-list:character, value:offset
    7:address:duplex-list:character <- next 5:address:duplex-list:character
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    7 <- 0
  ]
]

# Inserts list beginning at 'new' after 'in'. Returns some pointer into the list.
recipe insert-range in:address:duplex-list:_elem, start:address:duplex-list:_elem -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  reply-unless in
  reply-unless start
  end:address:duplex-list:_elem <- copy start
  {
    next:address:duplex-list:_elem <- next end/insert-range
    break-unless next
    end <- copy next
    loop
  }
  next:address:duplex-list:_elem <- next in
  dest:address:address:duplex-list:_elem <- get-address *end, next:offset
  *dest <- copy next
  {
    break-unless next
    dest <- get-address *next, prev:offset
    *dest <- copy end
  }
  dest <- get-address *in, next:offset
  *dest <- copy start
  dest <- get-address *start, prev:offset
  *dest <- copy in
]

recipe append in:address:duplex-list:_elem, new:address:duplex-list:_elem -> in:address:duplex-list:_elem [
  local-scope
  load-ingredients
  last:address:duplex-list:_elem <- last in
  dest:address:address:duplex-list:_elem <- get-address *last, next:offset
  *dest <- copy new
  reply-unless new
  dest <- get-address *new, prev:offset
  *dest <- copy last
]

recipe last in:address:duplex-list:_elem -> result:address:duplex-list:_elem [
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
recipe dump-from x:address:duplex-list:_elem [
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

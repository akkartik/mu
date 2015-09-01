# A doubly linked list permits bidirectional traversal.

container duplex-list [
  value:location
  next:address:duplex-list
  prev:address:duplex-list
]

# result:address:duplex-list <- push-duplex x:location, in:address:duplex-list
recipe push-duplex [
  local-scope
  x:location <- next-ingredient
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- new duplex-list:type
  val:address:location <- get-address *result, value:offset
  *val <- copy x
  next:address:address:duplex-list <- get-address *result, next:offset
  *next <- copy in
  reply-unless in, result
  prev:address:address:duplex-list <- get-address *in, prev:offset
  *prev <- copy result
  reply result
]

# result:location <- first-duplex in:address:duplex-list
recipe first-duplex [
  local-scope
  in:address:duplex-list <- next-ingredient
  reply-unless in, 0
  result:location <- get *in, value:offset
  reply result
]

# result:address:duplex-list <- next-duplex in:address:duplex-list
recipe next-duplex [
  local-scope
  in:address:duplex-list <- next-ingredient
  reply-unless in, 0
  result:address:duplex-list <- get *in, next:offset
  reply result
]

# result:address:duplex-list <- prev-duplex in:address:duplex-list
recipe prev-duplex [
  local-scope
  in:address:duplex-list <- next-ingredient
  reply-unless in, 0
  result:address:duplex-list <- get *in, prev:offset
  reply result
]

scenario duplex-list-handling [
  run [
    # reserve locations 0, 1 and 2 to check for missing null check
    1:number <- copy 34
    2:number <- copy 35
    3:address:duplex-list <- copy 0
    3:address:duplex-list <- push-duplex 3, 3:address:duplex-list
    3:address:duplex-list <- push-duplex 4, 3:address:duplex-list
    3:address:duplex-list <- push-duplex 5, 3:address:duplex-list
    4:address:duplex-list <- copy 3:address:duplex-list
    5:number <- first-duplex 4:address:duplex-list
    4:address:duplex-list <- next-duplex 4:address:duplex-list
    6:number <- first-duplex 4:address:duplex-list
    4:address:duplex-list <- next-duplex 4:address:duplex-list
    7:number <- first-duplex 4:address:duplex-list
    8:address:duplex-list <- next-duplex 4:address:duplex-list
    9:number <- first-duplex 8:address:duplex-list
    10:address:duplex-list <- next-duplex 8:address:duplex-list
    11:address:duplex-list <- prev-duplex 8:address:duplex-list
    4:address:duplex-list <- prev-duplex 4:address:duplex-list
    12:number <- first-duplex 4:address:duplex-list
    4:address:duplex-list <- prev-duplex 4:address:duplex-list
    13:number <- first-duplex 4:address:duplex-list
    14:boolean <- equal 3:address:duplex-list, 4:address:duplex-list
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

# l:address:duplex-list <- insert-duplex x:location, in:address:duplex-list
# Inserts 'x' after 'in'. Returns some pointer into the list.
recipe insert-duplex [
  local-scope
  x:location <- next-ingredient
  in:address:duplex-list <- next-ingredient
  new-node:address:duplex-list <- new duplex-list:type
  val:address:location <- get-address *new-node, value:offset
  *val <- copy x
  next-node:address:duplex-list <- get *in, next:offset
  # in.next = new-node
  y:address:address:duplex-list <- get-address *in, next:offset
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
    1:address:duplex-list <- copy 0  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5, 1:address:duplex-list
    2:address:duplex-list <- next-duplex 1:address:duplex-list  # 2 points inside list
    2:address:duplex-list <- insert-duplex 6, 2:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    6:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    8:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    9:number <- first-duplex 2:address:duplex-list
    10:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
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
    1:address:duplex-list <- copy 0  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5, 1:address:duplex-list
    2:address:duplex-list <- next-duplex 1:address:duplex-list  # 2 points inside list
    2:address:duplex-list <- next-duplex 2:address:duplex-list  # now at end of list
    2:address:duplex-list <- insert-duplex 6, 2:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    6:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    8:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    9:number <- first-duplex 2:address:duplex-list
    10:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
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
    1:address:duplex-list <- copy 0  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5, 1:address:duplex-list
    2:address:duplex-list <- insert-duplex 6, 1:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    6:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    8:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    9:number <- first-duplex 2:address:duplex-list
    10:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
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

# l:address:duplex-list <- remove-duplex in:address:duplex-list
# Removes 'in' from its surrounding list. Returns some valid pointer into the
# rest of the list.
#
# Returns null if and only if list is empty. Beware: in that case any pointers
# to the head are now invalid.
recipe remove-duplex [
  local-scope
  in:address:duplex-list <- next-ingredient
  # if 'in' is null, return
  reply-unless in, in
  next-node:address:duplex-list <- get *in, next:offset
  prev-node:address:duplex-list <- get *in, prev:offset
  # null in's pointers
  x:address:address:duplex-list <- get-address *in, next:offset
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
    1:address:duplex-list <- copy 0  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5, 1:address:duplex-list
    2:address:duplex-list <- next-duplex 1:address:duplex-list  # 2 points at second element
    2:address:duplex-list <- remove-duplex 2:address:duplex-list
    3:boolean <- equal 2:address:duplex-list, 0
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    4:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first-duplex 2:address:duplex-list
    6:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first-duplex 2:address:duplex-list
    8:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
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
    1:address:duplex-list <- copy 0  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5, 1:address:duplex-list
    # removing from head? return value matters.
    1:address:duplex-list <- remove-duplex 1:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first-duplex 2:address:duplex-list
    5:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    6:number <- first-duplex 2:address:duplex-list
    7:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
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
    1:address:duplex-list <- copy 0  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5, 1:address:duplex-list
    # delete last element
    2:address:duplex-list <- next-duplex 1:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- remove-duplex 2:address:duplex-list
    3:boolean <- equal 2:address:duplex-list, 0
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    4:number <- first-duplex 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first-duplex 2:address:duplex-list
    6:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first-duplex 2:address:duplex-list
    8:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
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
    1:address:duplex-list <- copy 0  # 1 points to singleton list
    1:address:duplex-list <- push-duplex 3, 1:address:duplex-list
    2:address:duplex-list <- remove-duplex 1:address:duplex-list
    3:address:duplex-list <- get *1:address:duplex-list, next:offset
    4:address:duplex-list <- get *1:address:duplex-list, prev:offset
  ]
  memory-should-contain [
    2 <- 0  # remove returned null
    3 <- 0  # removed node is also detached
    4 <- 0
  ]
]

# l:address:duplex-list <- remove-duplex-between start:address:duplex-list, end:address:duplex-list
# Remove values between 'start' and 'end' (both exclusive). Returns some valid
# pointer into the rest of the list.
# Also clear pointers back out from start/end for hygiene.
recipe remove-duplex-between [
  local-scope
  start:address:duplex-list <- next-ingredient
  end:address:duplex-list <- next-ingredient
  reply-unless start, start
  # start->next->prev = 0
  # start->next = end
  next:address:address:duplex-list <- get-address *start, next:offset
  nothing-to-delete?:boolean <- equal *next, end
  reply-if nothing-to-delete?, start
  prev:address:address:duplex-list <- get-address **next, prev:offset
  *prev <- copy 0
  *next <- copy end
  reply-unless end, start
  # end->prev->next = 0
  # end->prev = start
  prev <- get-address *end, prev:offset
  next <- get-address **prev, next:offset
  *next <- copy 0
  *prev <- copy start
  reply start
]

scenario remove-range [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  1:address:duplex-list <- copy 0  # 1 points to singleton list
  1:address:duplex-list <- push-duplex 18, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 17, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 16, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 15, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 14, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 13, 1:address:duplex-list
  run [
    # delete 16 onwards
    # first pointer: to the third element
    2:address:duplex-list <- next-duplex 1:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    remove-duplex-between 2:address:duplex-list, 0
    # now check the list
    4:number <- get *1:address:duplex-list, value:offset
    5:address:duplex-list <- next-duplex 1:address:duplex-list
    6:number <- get *5:address:duplex-list, value:offset
    7:address:duplex-list <- next-duplex 5:address:duplex-list
    8:number <- get *7:address:duplex-list, value:offset
    9:address:duplex-list <- next-duplex 7:address:duplex-list
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
  1:address:duplex-list <- copy 0  # 1 points to singleton list
  1:address:duplex-list <- push-duplex 18, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 17, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 16, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 15, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 14, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 13, 1:address:duplex-list
  run [
    # delete 15, 16 and 17
    # first pointer: to the third element
    2:address:duplex-list <- next-duplex 1:address:duplex-list
    # second pointer: to the fifth element
    3:address:duplex-list <- next-duplex 2:address:duplex-list
    3:address:duplex-list <- next-duplex 3:address:duplex-list
    3:address:duplex-list <- next-duplex 3:address:duplex-list
    3:address:duplex-list <- next-duplex 3:address:duplex-list
    remove-duplex-between 2:address:duplex-list, 3:address:duplex-list
    # now check the list
    4:number <- get *1:address:duplex-list, value:offset
    5:address:duplex-list <- next-duplex 1:address:duplex-list
    6:number <- get *5:address:duplex-list, value:offset
    7:address:duplex-list <- next-duplex 5:address:duplex-list
    8:number <- get *7:address:duplex-list, value:offset
    9:address:duplex-list <- next-duplex 7:address:duplex-list
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
  1:address:duplex-list <- copy 0  # 1 points to singleton list
  1:address:duplex-list <- push-duplex 14, 1:address:duplex-list
  1:address:duplex-list <- push-duplex 13, 1:address:duplex-list
  run [
    # delete 16 onwards
    # first pointer: to the third element
    2:address:duplex-list <- next-duplex 1:address:duplex-list
    remove-duplex-between 1:address:duplex-list, 2:address:duplex-list
    # now check the list
    4:number <- get *1:address:duplex-list, value:offset
    5:address:duplex-list <- next-duplex 1:address:duplex-list
    6:number <- get *5:address:duplex-list, value:offset
    7:address:duplex-list <- next-duplex 5:address:duplex-list
  ]
  memory-should-contain [
    4 <- 13
    6 <- 14
    7 <- 0
  ]
]

# l:address:duplex-list <- insert-duplex-range in:address:duplex-list, new:address:duplex-list
# Inserts list beginning at 'new' after 'in'. Returns some pointer into the list.
recipe insert-duplex-range [
  local-scope
  in:address:duplex-list <- next-ingredient
  start:address:duplex-list <- next-ingredient
  reply-unless in, in
  reply-unless start, in
  end:address:duplex-list <- copy start
  {
    next:address:duplex-list <- next-duplex end
    break-unless next
    end <- copy next
    loop
  }
  next:address:duplex-list <- next-duplex in
  dest:address:address:duplex-list <- get-address *end, next:offset
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
  reply in
]

recipe append-duplex [
  local-scope
  in:address:duplex-list <- next-ingredient
  new:address:duplex-list <- next-ingredient
  last:address:duplex-list <- last-duplex in
  dest:address:address:duplex-list <- get-address *last, next:offset
  *dest <- copy new
  reply-unless new, in/same-as-ingredient:0
  dest <- get-address *new, prev:offset
  *dest <- copy last
  reply in/same-as-ingredient:0
]

recipe last-duplex [
  local-scope
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- copy in
  {
    next:address:duplex-list <- next-duplex result
    break-unless next
    result <- copy next
    loop
  }
  reply result
]

# helper for debugging
recipe dump-duplex-from [
  local-scope
  x:address:duplex-list <- next-ingredient
  $print x, [: ]
  {
    break-unless x
    c:character <- get *x, value:offset
    $print c, [ ]
    x <- next-duplex x
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

# A doubly linked list permits bidirectional traversal.

container duplex-list [
  value:location
  next:address:duplex-list
  prev:address:duplex-list
]

# result:address:duplex-list <- push-duplex x:location, in:address:duplex-list
recipe push-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  x:location <- next-ingredient
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- new duplex-list:type
  val:address:location <- get-address result:address:duplex-list/deref, value:offset
  val:address:location/deref <- copy x:location
  next:address:address:duplex-list <- get-address result:address:duplex-list/deref, next:offset
  next:address:address:duplex-list/deref <- copy in:address:duplex-list
  prev:address:address:duplex-list <- get-address in:address:duplex-list/deref, prev:offset
  prev:address:address:duplex-list/deref <- copy result:address:duplex-list
  reply result:address:duplex-list
]

# result:location <- first-duplex in:address:duplex-list
recipe first-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  result:location <- get in:address:duplex-list/deref, value:offset
  reply result:location
]

# result:address:duplex-list <- next-duplex in:address:duplex-list
recipe next-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- get in:address:duplex-list/deref, next:offset
  reply result:address:duplex-list
]

# result:address:duplex-list <- prev-duplex in:address:duplex-list
recipe prev-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- get in:address:duplex-list/deref, prev:offset
  reply result:address:duplex-list
]

scenario duplex-list-handling [
  run [
    1:address:duplex-list <- copy 0:literal
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    6:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
    8:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
  ]
  memory-should-contain [
    3 <- 5  # scanning next
    4 <- 4
    5 <- 3
    6 <- 4  # then prev
    7 <- 5
    8 <- 1  # list back at start
  ]
]

# l:address:duplex-list <- insert-duplex x:location, in:address:duplex-list
# Inserts 'x' after 'in'. Returns some pointer into the list.
recipe insert-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  x:location <- next-ingredient
  in:address:duplex-list <- next-ingredient
  new-node:address:duplex-list <- new duplex-list:type
  val:address:location <- get-address new-node:address:duplex-list/deref, value:offset
  val:address:location/deref <- copy x:location
  next-node:address:duplex-list <- get in:address:duplex-list/deref, next:offset
  # in.next = new-node
  y:address:address:duplex-list <- get-address in:address:duplex-list/deref, next:offset
  y:address:address:duplex-list/deref <- copy new-node:address:duplex-list
  # new-node.prev = in
  y:address:address:duplex-list <- get-address new-node:address:duplex-list/deref, prev:offset
  y:address:address:duplex-list/deref <- copy in:address:duplex-list
  # new-node.next = next-node
  y:address:address:duplex-list <- get-address new-node:address:duplex-list/deref, next:offset
  y:address:address:duplex-list/deref <- copy next-node:address:duplex-list
  # if next-node is not null
  reply-unless next-node:address:duplex-list, new-node:address:duplex-list
  # next-node.prev = new-node
  y:address:address:duplex-list <- get-address next-node:address:duplex-list/deref, prev:offset
  y:address:address:duplex-list/deref <- copy new-node:address:duplex-list
  reply new-node:address:duplex-list  # just signalling something changed; don't rely on the result
]

scenario inserting-into-duplex-list [
  run [
    1:address:duplex-list <- copy 0:literal  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    2:address:duplex-list <- next-duplex 1:address:duplex-list  # 2 points inside list
    2:address:duplex-list <- insert-duplex 6:literal, 2:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    6:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    8:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    9:number <- first 2:address:duplex-list
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
    1:address:duplex-list <- copy 0:literal  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    2:address:duplex-list <- next-duplex 1:address:duplex-list  # 2 points inside list
    2:address:duplex-list <- next-duplex 2:address:duplex-list  # now at end of list
    2:address:duplex-list <- insert-duplex 6:literal, 2:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    6:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    8:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    9:number <- first 2:address:duplex-list
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
    1:address:duplex-list <- copy 0:literal  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    2:address:duplex-list <- insert-duplex 6:literal, 1:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    6:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    8:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    9:number <- first 2:address:duplex-list
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
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  # if 'in' is null, return
  reply-unless in:address:duplex-list, in:address:duplex-list
  next-node:address:duplex-list <- get in:address:duplex-list/deref, next:offset
  prev-node:address:duplex-list <- get in:address:duplex-list/deref, prev:offset
  # null in's pointers
  x:address:address:duplex-list <- get-address in:address:duplex-list/deref, next:offset
  x:address:address:duplex-list/deref <- copy 0:literal
  x:address:address:duplex-list <- get-address in:address:duplex-list/deref, prev:offset
  x:address:address:duplex-list/deref <- copy 0:literal
  {
    # if next-node is not null
    break-unless next-node:address:duplex-list
    # next-node.prev = prev-node
    x:address:address:duplex-list <- get-address next-node:address:duplex-list/deref, prev:offset
    x:address:address:duplex-list/deref <- copy prev-node:address:duplex-list
  }
  {
    # if prev-node is not null
    break-unless prev-node:address:duplex-list
    # prev-node.next = next-node
    x:address:address:duplex-list <- get-address prev-node:address:duplex-list/deref, next:offset
    x:address:address:duplex-list/deref <- copy next-node:address:duplex-list
    reply prev-node:address:duplex-list
  }
  reply next-node:address:duplex-list
]

scenario removing-from-duplex-list [
  run [
    1:address:duplex-list <- copy 0:literal  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    2:address:duplex-list <- next-duplex 1:address:duplex-list  # 2 points at second element
    2:address:duplex-list <- remove-duplex 2:address:duplex-list
    3:boolean <- equal 2:address:duplex-list, 0:literal
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    6:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
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
    1:address:duplex-list <- copy 0:literal  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    # removing from head? return value matters.
    1:address:duplex-list <- remove-duplex 1:address:duplex-list
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first 2:address:duplex-list
    5:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    6:number <- first 2:address:duplex-list
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
    1:address:duplex-list <- copy 0:literal  # 1 points to head of list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    # delete last element
    2:address:duplex-list <- next-duplex 1:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- remove-duplex 2:address:duplex-list
    3:boolean <- equal 2:address:duplex-list, 0:literal
    # check structure like before
    2:address:duplex-list <- copy 1:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    6:address:duplex-list <- next-duplex 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
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
    1:address:duplex-list <- copy 0:literal  # 1 points to singleton list
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    2:address:duplex-list <- remove-duplex 1:address:duplex-list
    3:address:duplex-list <- get 1:address:duplex-list/deref, next:offset
    4:address:duplex-list <- get 1:address:duplex-list/deref, prev:offset
  ]
  memory-should-contain [
    2 <- 0  # remove returned null
    3 <- 0  # removed node is also detached
    4 <- 0
  ]
]

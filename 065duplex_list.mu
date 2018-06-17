# A doubly linked list permits bidirectional traversal.

container duplex-list:_elem [
  value:_elem
  next:&:duplex-list:_elem
  prev:&:duplex-list:_elem
]

def push x:_elem, in:&:duplex-list:_elem/contained-in:result -> result:&:duplex-list:_elem [
  local-scope
  load-inputs
  result:&:duplex-list:_elem <- new {(duplex-list _elem): type}
  *result <- merge x, in, null
  return-unless in
  put *in, prev:offset, result
]

def first in:&:duplex-list:_elem -> result:_elem [
  local-scope
  load-inputs
  {
    break-if in
    zero:&:_elem <- new _elem:type
    zero-result:_elem <- copy *zero
    abandon zero
    return zero-result
  }
  result <- get *in, value:offset
]

def next in:&:duplex-list:_elem -> result:&:duplex-list:_elem/contained-in:in [
  local-scope
  load-inputs
  return-unless in, null
  result <- get *in, next:offset
]

def prev in:&:duplex-list:_elem -> result:&:duplex-list:_elem/contained-in:in [
  local-scope
  load-inputs
  return-unless in, null
  result <- get *in, prev:offset
  return result
]

scenario duplex-list-handling [
  run [
    local-scope
    # reserve locations 0-9 to check for missing null check
    10:num/raw <- copy 34
    11:num/raw <- copy 35
    list:&:duplex-list:num <- push 3, null
    list <- push 4, list
    list <- push 5, list
    list2:&:duplex-list:num <- copy list
    20:num/raw <- first list2
    list2 <- next list2
    21:num/raw <- first list2
    list2 <- next list2
    22:num/raw <- first list2
    30:&:duplex-list:num/raw <- next list2
    31:num/raw <- first 30:&:duplex-list:num/raw
    32:&:duplex-list:num/raw <- next 30:&:duplex-list:num/raw
    33:&:duplex-list:num/raw <- prev 30:&:duplex-list:num/raw
    list2 <- prev list2
    40:num/raw <- first list2
    list2 <- prev list2
    41:num/raw <- first list2
    50:bool/raw <- equal list, list2
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

def length l:&:duplex-list:_elem -> result:num [
  local-scope
  load-inputs
  result <- copy 0
  {
    break-unless l
    result <- add result, 1
    l <- next l
    loop
  }
]

# insert 'x' after 'in'
def insert x:_elem, in:&:duplex-list:_elem -> in:&:duplex-list:_elem [
  local-scope
  load-inputs
  new-node:&:duplex-list:_elem <- new {(duplex-list _elem): type}
  *new-node <- put *new-node, value:offset, x
  # save old next before changing it
  next-node:&:duplex-list:_elem <- get *in, next:offset
  *in <- put *in, next:offset, new-node
  *new-node <- put *new-node, prev:offset, in
  *new-node <- put *new-node, next:offset, next-node
  return-unless next-node
  *next-node <- put *next-node, prev:offset, new-node
]

scenario inserting-into-duplex-list [
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:duplex-list:num <- next list  # inside list
    list2 <- insert 6, list2
    # check structure like before
    list2 <- copy list
    10:num/raw <- first list2
    list2 <- next list2
    11:num/raw <- first list2
    list2 <- next list2
    12:num/raw <- first list2
    list2 <- next list2
    13:num/raw <- first list2
    list2 <- prev list2
    20:num/raw <- first list2
    list2 <- prev list2
    21:num/raw <- first list2
    list2 <- prev list2
    22:num/raw <- first list2
    30:bool/raw <- equal list, list2
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
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:duplex-list:num <- next list  # inside list
    list2 <- next list2  # now at end of list
    list2 <- insert 6, list2
    # check structure like before
    list2 <- copy list
    10:num/raw <- first list2
    list2 <- next list2
    11:num/raw <- first list2
    list2 <- next list2
    12:num/raw <- first list2
    list2 <- next list2
    13:num/raw <- first list2
    list2 <- prev list2
    20:num/raw <- first list2
    list2 <- prev list2
    21:num/raw <- first list2
    list2 <- prev list2
    22:num/raw <- first list2
    30:bool/raw <- equal list, list2
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
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    list <- insert 6, list
    # check structure like before
    list2:&:duplex-list:num <- copy list
    10:num/raw <- first list2
    list2 <- next list2
    11:num/raw <- first list2
    list2 <- next list2
    12:num/raw <- first list2
    list2 <- next list2
    13:num/raw <- first list2
    list2 <- prev list2
    20:num/raw <- first list2
    list2 <- prev list2
    21:num/raw <- first list2
    list2 <- prev list2
    22:num/raw <- first list2
    30:bool/raw <- equal list, list2
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
def remove x:&:duplex-list:_elem/contained-in:in, in:&:duplex-list:_elem -> in:&:duplex-list:_elem [
  local-scope
  load-inputs
  # if 'x' is null, return
  return-unless x
  next-node:&:duplex-list:_elem <- get *x, next:offset
  prev-node:&:duplex-list:_elem <- get *x, prev:offset
  # null x's pointers
  *x <- put *x, next:offset, null
  *x <- put *x, prev:offset, null
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
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:duplex-list:num <- next list  # second element
    list <- remove list2, list
    10:bool/raw <- equal list2, null
    # check structure like before
    list2 <- copy list
    11:num/raw <- first list2
    list2 <- next list2
    12:num/raw <- first list2
    20:&:duplex-list:num/raw <- next list2
    list2 <- prev list2
    30:num/raw <- first list2
    40:bool/raw <- equal list, list2
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
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    list <- remove list, list
    # check structure like before
    list2:&:duplex-list:num <- copy list
    10:num/raw <- first list2
    list2 <- next list2
    11:num/raw <- first list2
    20:&:duplex-list:num/raw <- next list2
    list2 <- prev list2
    30:num/raw <- first list2
    40:bool/raw <- equal list, list2
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
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    # delete last element
    list2:&:duplex-list:num <- next list
    list2 <- next list2
    list <- remove list2, list
    10:bool/raw <- equal list2, null
    # check structure like before
    list2 <- copy list
    11:num/raw <- first list2
    list2 <- next list2
    12:num/raw <- first list2
    20:&:duplex-list:num/raw <- next list2
    list2 <- prev list2
    30:num/raw <- first list2
    40:bool/raw <- equal list, list2
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
  local-scope
  list:&:duplex-list:num <- push 3, null
  run [
    list <- remove list, list
    1:num/raw <- deaddress list
  ]
  memory-should-contain [
    1 <- 0  # back to an empty list
  ]
]

def remove x:&:duplex-list:_elem/contained-in:in, n:num, in:&:duplex-list:_elem -> in:&:duplex-list:_elem [
  local-scope
  load-inputs
  i:num <- copy 0
  curr:&:duplex-list:_elem <- copy x
  {
    done?:bool <- greater-or-equal i, n
    break-if done?
    break-unless curr
    next:&:duplex-list:_elem <- next curr
    in <- remove curr, in
    curr <- copy next
    i <- add i, 1
    loop
  }
]

scenario removing-multiple-from-duplex-list [
  local-scope
  list:&:duplex-list:num <- push 3, null
  list <- push 4, list
  list <- push 5, list
  run [
    list2:&:duplex-list:num <- next list  # second element
    list <- remove list2, 2, list
    stash list
  ]
  trace-should-contain [
    app: 5
  ]
]

# remove values between 'start' and 'end' (both exclusive).
# also clear pointers back out from start/end for hygiene.
# set end to 0 to delete everything past start.
# can't set start to 0 to delete everything before end, because there's no
# clean way to return the new head pointer.
def remove-between start:&:duplex-list:_elem, end:&:duplex-list:_elem/contained-in:start -> start:&:duplex-list:_elem [
  local-scope
  load-inputs
  next:&:duplex-list:_elem <- get *start, next:offset
  nothing-to-delete?:bool <- equal next, end
  return-if nothing-to-delete?
  assert next, [malformed duplex list]
  # start->next->prev = 0
  # start->next = end
  *next <- put *next, prev:offset, null
  *start <- put *start, next:offset, end
  return-unless end
  # end->prev->next = 0
  # end->prev = start
  prev:&:duplex-list:_elem <- get *end, prev:offset
  assert prev, [malformed duplex list - 2]
  *prev <- put *prev, next:offset, null
  *end <- put *end, prev:offset, start
]

scenario remove-range [
  # construct a duplex list with six elements [13, 14, 15, 16, 17, 18]
  local-scope
  list:&:duplex-list:num <- push 18, null
  list <- push 17, list
  list <- push 16, list
  list <- push 15, list
  list <- push 14, list
  list <- push 13, list
  run [
    # delete 16 onwards
    # first pointer: to the third element
    list2:&:duplex-list:num <- next list
    list2 <- next list2
    list2 <- remove-between list2, null
    # now check the list
    10:num/raw <- get *list, value:offset
    list <- next list
    11:num/raw <- get *list, value:offset
    list <- next list
    12:num/raw <- get *list, value:offset
    20:&:duplex-list:num/raw <- next list
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
  list:&:duplex-list:num <- push 18, null
  list <- push 17, list
  list <- push 16, list
  list <- push 15, list
  list <- push 14, list
  list <- push 13, list
  run [
    # delete 15, 16 and 17
    # start pointer: to the second element
    list2:&:duplex-list:num <- next list
    # end pointer: to the last (sixth) element
    end:&:duplex-list:num <- next list2
    end <- next end
    end <- next end
    end <- next end
    remove-between list2, end
    # now check the list
    10:num/raw <- get *list, value:offset
    list <- next list
    11:num/raw <- get *list, value:offset
    list <- next list
    12:num/raw <- get *list, value:offset
    20:&:duplex-list:num/raw <- next list
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
  list:&:duplex-list:num <- push 15, null
  list <- push 14, list
  list <- push 13, list
  run [
    # delete between first and second element (i.e. nothing)
    list2:&:duplex-list:num <- next list
    remove-between list, list2
    # now check the list
    10:num/raw <- get *list, value:offset
    list <- next list
    11:num/raw <- get *list, value:offset
    list <- next list
    12:num/raw <- get *list, value:offset
    20:&:duplex-list:num/raw <- next list
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
  list:&:duplex-list:num <- push 18, null
  list <- push 17, list
  list <- push 16, list
  list <- push 15, list
  list <- push 14, list
  list <- push 13, list
  run [
    # remove the third element and beyond
    list2:&:duplex-list:num <- next list
    remove-between list2, null
    # now check the list
    10:num/raw <- get *list, value:offset
    list <- next list
    11:num/raw <- get *list, value:offset
    20:&:duplex-list:num/raw <- next list
  ]
  memory-should-contain [
    10 <- 13
    11 <- 14
    20 <- 0
  ]
]

# insert list beginning at 'start' after 'in'
def splice in:&:duplex-list:_elem, start:&:duplex-list:_elem/contained-in:in -> in:&:duplex-list:_elem [
  local-scope
  load-inputs
  return-unless in
  return-unless start
  end:&:duplex-list:_elem <- last start
  next:&:duplex-list:_elem <- next in
  {
    break-unless next
    *end <- put *end, next:offset, next
    *next <- put *next, prev:offset, end
  }
  *in <- put *in, next:offset, start
  *start <- put *start, prev:offset, in
]

# insert contents of 'new' after 'in'
def insert in:&:duplex-list:_elem, new:&:@:_elem -> in:&:duplex-list:_elem [
  local-scope
  load-inputs
  return-unless in
  return-unless new
  len:num <- length *new
  return-unless len
  curr:&:duplex-list:_elem <- copy in
  idx:num <- copy 0
  {
    done?:bool <- greater-or-equal idx, len
    break-if done?
    c:_elem <- index *new, idx
    insert c, curr
    # next iter
    curr <- next curr
    idx <- add idx, 1
    loop
  }
]

def append in:&:duplex-list:_elem, new:&:duplex-list:_elem/contained-in:in -> in:&:duplex-list:_elem [
  local-scope
  load-inputs
  last:&:duplex-list:_elem <- last in
  *last <- put *last, next:offset, new
  return-unless new
  *new <- put *new, prev:offset, last
]

def last in:&:duplex-list:_elem -> result:&:duplex-list:_elem [
  local-scope
  load-inputs
  result <- copy in
  {
    next:&:duplex-list:_elem <- next result
    break-unless next
    result <- copy next
    loop
  }
]

# does a duplex list start with a certain sequence of elements?
def match x:&:duplex-list:_elem, y:&:@:_elem -> result:bool [
  local-scope
  load-inputs
  i:num <- copy 0
  max:num <- length *y
  {
    done?:bool <- greater-or-equal i, max
    break-if done?
    expected:_elem <- index *y, i
    return-unless x, false/no-match
    curr:_elem <- first x
    curr-matches?:bool <- equal curr, expected
    return-unless curr-matches?, false/no-match
    x <- next x
    i <- add i, 1
    loop
  }
  return true/successful-match
]

scenario duplex-list-match [
  local-scope
  list:&:duplex-list:char <- push 97/a, null
  list <- push 98/b, list
  list <- push 99/c, list
  list <- push 100/d, list
  run [
    10:bool/raw <- match list, []
    11:bool/raw <- match list, [d]
    12:bool/raw <- match list, [dc]
    13:bool/raw <- match list, [dcba]
    14:bool/raw <- match list, [dd]
    15:bool/raw <- match list, [dcbax]
  ]
  memory-should-contain [
    10 <- 1  # matches []
    11 <- 1  # matches [d]
    12 <- 1  # matches [dc]
    13 <- 1  # matches [dcba]
    14 <- 0  # does not match [dd]
    15 <- 0  # does not match [dcbax]
  ]
]

# helper for debugging
def dump-from x:&:duplex-list:_elem [
  local-scope
  load-inputs
  $print x, [: ]
  {
    break-unless x
    c:_elem <- get *x, value:offset
    $print c, [ ]
    x <- next x
    {
      is-newline?:bool <- equal c, 10/newline
      break-unless is-newline?
      $print 10/newline
      $print x, [: ]
    }
    loop
  }
  $print 10/newline, [---], 10/newline
]

scenario stash-duplex-list [
  local-scope
  list:&:duplex-list:num <- push 1, null
  list <- push 2, list
  list <- push 3, list
  run [
    stash [list:], list
  ]
  trace-should-contain [
    app: list: 3 <-> 2 <-> 1
  ]
]

def to-text in:&:duplex-list:_elem -> result:text [
  local-scope
  load-inputs
  buf:&:buffer:char <- new-buffer 80
  buf <- to-buffer in, buf
  result <- buffer-to-array buf
]

# variant of 'to-text' which stops printing after a few elements (and so is robust to cycles)
def to-text-line in:&:duplex-list:_elem -> result:text [
  local-scope
  load-inputs
  buf:&:buffer:char <- new-buffer 80
  buf <- to-buffer in, buf, 6  # max elements to display
  result <- buffer-to-array buf
]

def to-buffer in:&:duplex-list:_elem, buf:&:buffer:char -> buf:&:buffer:char [
  local-scope
  load-inputs
  {
    break-if in
    buf <- append buf, [[]]
    return
  }
  # append in.value to buf
  val:_elem <- get *in, value:offset
  buf <- append buf, val
  # now prepare next
  next:&:duplex-list:_elem <- next in
  nextn:num <- deaddress next
  return-unless next
  buf <- append buf, [ <-> ]
  # and recurse
  remaining:num, optional-input-found?:bool <- next-input
  {
    break-if optional-input-found?
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

scenario stash-empty-duplex-list [
  local-scope
  x:&:duplex-list:num <- copy null
  run [
    stash x
  ]
  trace-should-contain [
    app: []
  ]
]

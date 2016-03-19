# Mu synchronizes using channels rather than locks, like Erlang and Go.
#
# The two ends of a channel will usually belong to different routines, but
# each end should only be used by a single one. Don't try to read from or
# write to it from multiple routines at once.
#
# The key property of channels is that writing to a full channel or reading
# from an empty one will put the current routine in 'waiting' state until the
# operation can be completed.

scenario channel [
  run [
    1:address:shared:channel:character <- new-channel 3/capacity
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    2:character, 1:address:shared:channel:character <- read 1:address:shared:channel:character
  ]
  memory-should-contain [
    2 <- 34
  ]
]

container channel:_elem [
  # To avoid locking, writer and reader will never write to the same location.
  # So channels will include fields in pairs, one for the writer and one for the
  # reader.
  first-full:number  # for write
  first-free:number  # for read
  # A circular buffer contains values from index first-full up to (but not
  # including) index first-empty. The reader always modifies it at first-full,
  # while the writer always modifies it at first-empty.
  data:address:shared:array:_elem
]

def new-channel capacity:number -> result:address:shared:channel:_elem [
  local-scope
  load-ingredients
  result <- new {(channel _elem): type}
  # result.first-full = 0
  full:address:number <- get-address *result, first-full:offset
  *full <- copy 0
  # result.first-free = 0
  free:address:number <- get-address *result, first-free:offset
  *free <- copy 0
  # result.data = new location[ingredient+1]
  capacity <- add capacity, 1  # unused slot for 'full?' below
  dest:address:address:shared:array:_elem <- get-address *result, data:offset
  *dest <- new _elem:type, capacity
]

def write chan:address:shared:channel:_elem, val:_elem -> chan:address:shared:channel:_elem [
  local-scope
  load-ingredients
  {
    # block if chan is full
    full:boolean <- channel-full? chan
    break-unless full
    full-address:address:number <- get-address *chan, first-full:offset
    wait-for-location *full-address
  }
  # store val
  circular-buffer:address:shared:array:_elem <- get *chan, data:offset
  free:address:number <- get-address *chan, first-free:offset
  dest:address:_elem <- index-address *circular-buffer, *free
  *dest <- copy val
  # mark its slot as filled
  *free <- add *free, 1
  {
    # wrap free around to 0 if necessary
    len:number <- length *circular-buffer
    at-end?:boolean <- greater-or-equal *free, len
    break-unless at-end?
    *free <- copy 0
  }
]

def read chan:address:shared:channel:_elem -> result:_elem, chan:address:shared:channel:_elem [
  local-scope
  load-ingredients
  {
    # block if chan is empty
    empty?:boolean <- channel-empty? chan
    break-unless empty?
    free-address:address:number <- get-address *chan, first-free:offset
    wait-for-location *free-address
  }
  # read result
  full:address:number <- get-address *chan, first-full:offset
  circular-buffer:address:shared:array:_elem <- get *chan, data:offset
  result <- index *circular-buffer, *full
  # mark its slot as empty
  *full <- add *full, 1
  {
    # wrap full around to 0 if necessary
    len:number <- length *circular-buffer
    at-end?:boolean <- greater-or-equal *full, len
    break-unless at-end?
    *full <- copy 0
  }
]

def clear-channel chan:address:shared:channel:_elem -> chan:address:shared:channel:_elem [
  local-scope
  load-ingredients
  {
    empty?:boolean <- channel-empty? chan
    break-if empty?
    _, chan <- read chan
  }
]

scenario channel-initialization [
  run [
    1:address:shared:channel:character <- new-channel 3/capacity
    2:number <- get *1:address:shared:channel:character, first-full:offset
    3:number <- get *1:address:shared:channel:character, first-free:offset
  ]
  memory-should-contain [
    2 <- 0  # first-full
    3 <- 0  # first-free
  ]
]

scenario channel-write-increments-free [
  run [
    1:address:shared:channel:character <- new-channel 3/capacity
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    2:number <- get *1:address:shared:channel:character, first-full:offset
    3:number <- get *1:address:shared:channel:character, first-free:offset
  ]
  memory-should-contain [
    2 <- 0  # first-full
    3 <- 1  # first-free
  ]
]

scenario channel-read-increments-full [
  run [
    1:address:shared:channel:character <- new-channel 3/capacity
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    _, 1:address:shared:channel:character <- read 1:address:shared:channel:character
    2:number <- get *1:address:shared:channel:character, first-full:offset
    3:number <- get *1:address:shared:channel:character, first-free:offset
  ]
  memory-should-contain [
    2 <- 1  # first-full
    3 <- 1  # first-free
  ]
]

scenario channel-wrap [
  run [
    # channel with just 1 slot
    1:address:shared:channel:character <- new-channel 1/capacity
    # write and read a value
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    _, 1:address:shared:channel:character <- read 1:address:shared:channel:character
    # first-free will now be 1
    2:number <- get *1:address:shared:channel:character, first-free:offset
    3:number <- get *1:address:shared:channel:character, first-free:offset
    # write second value, verify that first-free wraps
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    4:number <- get *1:address:shared:channel:character, first-free:offset
    # read second value, verify that first-full wraps
    _, 1:address:shared:channel:character <- read 1:address:shared:channel:character
    5:number <- get *1:address:shared:channel:character, first-full:offset
  ]
  memory-should-contain [
    2 <- 1  # first-free after first write
    3 <- 1  # first-full after first read
    4 <- 0  # first-free after second write, wrapped
    5 <- 0  # first-full after second read, wrapped
  ]
]

## helpers

# An empty channel has first-empty and first-full both at the same value.
def channel-empty? chan:address:shared:channel:_elem -> result:boolean [
  local-scope
  load-ingredients
  # return chan.first-full == chan.first-free
  full:number <- get *chan, first-full:offset
  free:number <- get *chan, first-free:offset
  result <- equal full, free
]

# A full channel has first-empty just before first-full, wasting one slot.
# (Other alternatives: https://en.wikipedia.org/wiki/Circular_buffer#Full_.2F_Empty_Buffer_Distinction)
def channel-full? chan:address:shared:channel:_elem -> result:boolean [
  local-scope
  load-ingredients
  # tmp = chan.first-free + 1
  tmp:number <- get *chan, first-free:offset
  tmp <- add tmp, 1
  {
    # if tmp == chan.capacity, tmp = 0
    len:number <- channel-capacity chan
    at-end?:boolean <- greater-or-equal tmp, len
    break-unless at-end?
    tmp <- copy 0
  }
  # return chan.first-full == tmp
  full:number <- get *chan, first-full:offset
  result <- equal full, tmp
]

def channel-capacity chan:address:shared:channel:_elem -> result:number [
  local-scope
  load-ingredients
  q:address:shared:array:_elem <- get *chan, data:offset
  result <- length *q
]

scenario channel-new-empty-not-full [
  run [
    1:address:shared:channel:character <- new-channel 3/capacity
    2:boolean <- channel-empty? 1:address:shared:channel:character
    3:boolean <- channel-full? 1:address:shared:channel:character
  ]
  memory-should-contain [
    2 <- 1  # empty?
    3 <- 0  # full?
  ]
]

scenario channel-write-not-empty [
  run [
    1:address:shared:channel:character <- new-channel 3/capacity
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    2:boolean <- channel-empty? 1:address:shared:channel:character
    3:boolean <- channel-full? 1:address:shared:channel:character
  ]
  memory-should-contain [
    2 <- 0  # empty?
    3 <- 0  # full?
  ]
]

scenario channel-write-full [
  run [
    1:address:shared:channel:character <- new-channel 1/capacity
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    2:boolean <- channel-empty? 1:address:shared:channel:character
    3:boolean <- channel-full? 1:address:shared:channel:character
  ]
  memory-should-contain [
    2 <- 0  # empty?
    3 <- 1  # full?
  ]
]

scenario channel-read-not-full [
  run [
    1:address:shared:channel:character <- new-channel 1/capacity
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 34
    _, 1:address:shared:channel:character <- read 1:address:shared:channel:character
    2:boolean <- channel-empty? 1:address:shared:channel:character
    3:boolean <- channel-full? 1:address:shared:channel:character
  ]
  memory-should-contain [
    2 <- 1  # empty?
    3 <- 0  # full?
  ]
]

# helper for channels of characters in particular
def buffer-lines in:address:shared:channel:character, out:address:shared:channel:character -> out:address:shared:channel:character, in:address:shared:channel:character [
  local-scope
  load-ingredients
  # repeat forever
  {
    line:address:shared:buffer <- new-buffer 30
    # read characters from 'in' until newline, copy into line
    {
      +next-character
      c:character, in <- read in
      # drop a character on backspace
      {
        # special-case: if it's a backspace
        backspace?:boolean <- equal c, 8
        break-unless backspace?
        # drop previous character
        {
          buffer-length:address:number <- get-address *line, length:offset
          buffer-empty?:boolean <- equal *buffer-length, 0
          break-if buffer-empty?
          *buffer-length <- subtract *buffer-length, 1
        }
        # and don't append this one
        loop +next-character:label
      }
      # append anything else
      line <- append line, c
      line-done?:boolean <- equal c, 10/newline
      break-if line-done?
      # stop buffering on eof (currently only generated by fake console)
      eof?:boolean <- equal c, 0/eof
      break-if eof?
      loop
    }
    # copy line into 'out'
    i:number <- copy 0
    line-contents:address:shared:array:character <- get *line, data:offset
    max:number <- get *line, length:offset
    {
      done?:boolean <- greater-or-equal i, max
      break-if done?
      c:character <- index *line-contents, i
      out <- write out, c
      i <- add i, 1
      loop
    }
    loop
  }
]

scenario buffer-lines-blocks-until-newline [
  run [
    1:address:shared:channel:character/stdin <- new-channel 10/capacity
    2:address:shared:channel:character/buffered-stdin <- new-channel 10/capacity
    3:boolean <- channel-empty? 2:address:shared:channel:character/buffered-stdin
    assert 3:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after init]
    # buffer stdin into buffered-stdin, try to read from buffered-stdin
    4:number/buffer-routine <- start-running buffer-lines, 1:address:shared:channel:character/stdin, 2:address:shared:channel:character/buffered-stdin
    wait-for-routine 4:number/buffer-routine
    5:boolean <- channel-empty? 2:address:shared:channel:character/buffered-stdin
    assert 5:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after buffer-lines bring-up]
    # write 'a'
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 97/a
    restart 4:number/buffer-routine
    wait-for-routine 4:number/buffer-routine
    6:boolean <- channel-empty? 2:address:shared:channel:character/buffered-stdin
    assert 6:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after writing 'a']
    # write 'b'
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 98/b
    restart 4:number/buffer-routine
    wait-for-routine 4:number/buffer-routine
    7:boolean <- channel-empty? 2:address:shared:channel:character/buffered-stdin
    assert 7:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after writing 'b']
    # write newline
    1:address:shared:channel:character <- write 1:address:shared:channel:character, 10/newline
    restart 4:number/buffer-routine
    wait-for-routine 4:number/buffer-routine
    8:boolean <- channel-empty? 2:address:shared:channel:character/buffered-stdin
    9:boolean/completed? <- not 8:boolean
    assert 9:boolean/completed?, [ 
F buffer-lines-blocks-until-newline: channel should contain data after writing newline]
    trace 1, [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

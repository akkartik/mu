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
    1:address:source:number, 2:address:sink:number <- new-channel 3/capacity
    2:address:sink:number <- write 2:address:sink:number, 34
    3:number, 1:address:source:number <- read 1:address:source:number
  ]
  memory-should-contain [
    3 <- 34
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
  data:address:array:_elem
]

# Since channels have two ends, and since it's an error to use either end from
# multiple routines, let's distinguish the ends.

container source:_elem [
  chan:address:channel:_elem
]

container sink:_elem [
  chan:address:channel:_elem
]

def new-channel capacity:number -> in:address:source:_elem, out:address:sink:_elem [
  local-scope
  load-ingredients
  result:address:channel:_elem <- new {(channel _elem): type}
  *result <- put *result, first-full:offset, 0
  *result <- put *result, first-free:offset, 0
  capacity <- add capacity, 1  # unused slot for 'full?' below
  data:address:array:_elem <- new _elem:type, capacity
  *result <- put *result, data:offset, data
  in <- new {(source _elem): type}
  *in <- put *in, chan:offset, result
  out <- new {(sink _elem): type}
  *out <- put *out, chan:offset, result
]

def write out:address:sink:_elem, val:_elem -> out:address:sink:_elem [
  local-scope
  load-ingredients
  chan:address:channel:_elem <- get *out, chan:offset
  <channel-write-initial>
  {
    # block if chan is full
    full:boolean <- channel-full? chan
    break-unless full
    full-address:location <- get-location *chan, first-full:offset
    wait-for-location full-address
  }
  # store val
  circular-buffer:address:array:_elem <- get *chan, data:offset
  free:number <- get *chan, first-free:offset
  *circular-buffer <- put-index *circular-buffer, free, val
  # mark its slot as filled
  # todo: clear the slot itself
  free <- add free, 1
  {
    # wrap free around to 0 if necessary
    len:number <- length *circular-buffer
    at-end?:boolean <- greater-or-equal free, len
    break-unless at-end?
    free <- copy 0
  }
  # write back
  *chan <- put *chan, first-free:offset, free
]

def read in:address:source:_elem -> result:_elem, in:address:source:_elem [
  local-scope
  load-ingredients
  chan:address:channel:_elem <- get *in, chan:offset
  {
    # block if chan is empty
    empty?:boolean <- channel-empty? chan
    break-unless empty?
    <channel-read-empty>
    free-address:location <- get-location *chan, first-free:offset
    wait-for-location free-address
  }
  # pull result off
  full:number <- get *chan, first-full:offset
  circular-buffer:address:array:_elem <- get *chan, data:offset
  result <- index *circular-buffer, full
  # mark its slot as empty
  # todo: clear the slot itself
  full <- add full, 1
  {
    # wrap full around to 0 if necessary
    len:number <- length *circular-buffer
    at-end?:boolean <- greater-or-equal full, len
    break-unless at-end?
    full <- copy 0
  }
  # write back
  *chan <- put *chan, first-full:offset, full
]

def clear in:address:source:_elem -> in:address:source:_elem [
  local-scope
  load-ingredients
  chan:address:channel:_elem <- get *in, chan:offset
  {
    empty?:boolean <- channel-empty? chan
    break-if empty?
    _, in <- read in
  }
]

scenario channel-initialization [
  run [
    1:address:source:number <- new-channel 3/capacity
    2:address:channel:number <- get *1:address:source:number, chan:offset
    3:number <- get *2:address:channel:number, first-full:offset
    4:number <- get *2:address:channel:number, first-free:offset
  ]
  memory-should-contain [
    3 <- 0  # first-full
    4 <- 0  # first-free
  ]
]

scenario channel-write-increments-free [
  run [
    _, 1:address:sink:number <- new-channel 3/capacity
    1:address:sink:number <- write 1:address:sink:number, 34
    2:address:channel:number <- get *1:address:sink:number, chan:offset
    3:number <- get *2:address:channel:character, first-full:offset
    4:number <- get *2:address:channel:character, first-free:offset
  ]
  memory-should-contain [
    3 <- 0  # first-full
    4 <- 1  # first-free
  ]
]

scenario channel-read-increments-full [
  run [
    1:address:source:number, 2:address:sink:number <- new-channel 3/capacity
    2:address:sink:number <- write 2:address:sink:number, 34
    _, 1:address:source:number <- read 1:address:source:number
    3:address:channel:number <- get *1:address:source:number, chan:offset
    4:number <- get *3:address:channel:number, first-full:offset
    5:number <- get *3:address:channel:number, first-free:offset
  ]
  memory-should-contain [
    4 <- 1  # first-full
    5 <- 1  # first-free
  ]
]

scenario channel-wrap [
  run [
    # channel with just 1 slot
    1:address:source:number, 2:address:sink:number <- new-channel 1/capacity
    3:address:channel:number <- get *1:address:source:number, chan:offset
    # write and read a value
    2:address:sink:number <- write 2:address:sink:number, 34
    _, 1:address:source:number <- read 1:address:source:number
    # first-free will now be 1
    4:number <- get *3:address:channel:number, first-free:offset
    5:number <- get *3:address:channel:number, first-free:offset
    # write second value, verify that first-free wraps
    2:address:sink:number <- write 2:address:sink:number, 34
    6:number <- get *3:address:channel:number, first-free:offset
    # read second value, verify that first-full wraps
    _, 1:address:source:number <- read 1:address:source:number
    7:number <- get *3:address:channel:number, first-full:offset
  ]
  memory-should-contain [
    4 <- 1  # first-free after first write
    5 <- 1  # first-full after first read
    6 <- 0  # first-free after second write, wrapped
    7 <- 0  # first-full after second read, wrapped
  ]
]

scenario channel-new-empty-not-full [
  run [
    1:address:source:number, 2:address:sink:number <- new-channel 3/capacity
    3:address:channel:number <- get *1:address:source:number, chan:offset
    4:boolean <- channel-empty? 3:address:channel:number
    5:boolean <- channel-full? 3:address:channel:number
  ]
  memory-should-contain [
    4 <- 1  # empty?
    5 <- 0  # full?
  ]
]

scenario channel-write-not-empty [
  run [
    1:address:source:number, 2:address:sink:number <- new-channel 3/capacity
    3:address:channel:number <- get *1:address:source:number, chan:offset
    2:address:sink:number <- write 2:address:sink:number, 34
    4:boolean <- channel-empty? 3:address:channel:number
    5:boolean <- channel-full? 3:address:channel:number
  ]
  memory-should-contain [
    4 <- 0  # empty?
    5 <- 0  # full?
  ]
]

scenario channel-write-full [
  run [
    1:address:source:number, 2:address:sink:number <- new-channel 1/capacity
    3:address:channel:number <- get *1:address:source:number, chan:offset
    2:address:sink:number <- write 2:address:sink:number, 34
    4:boolean <- channel-empty? 3:address:channel:number
    5:boolean <- channel-full? 3:address:channel:number
  ]
  memory-should-contain [
    4 <- 0  # empty?
    5 <- 1  # full?
  ]
]

scenario channel-read-not-full [
  run [
    1:address:source:number, 2:address:sink:number <- new-channel 1/capacity
    3:address:channel:number <- get *1:address:source:number, chan:offset
    2:address:sink:number <- write 2:address:sink:number, 34
    _, 1:address:source:number <- read 1:address:source:number
    4:boolean <- channel-empty? 3:address:channel:number
    5:boolean <- channel-full? 3:address:channel:number
  ]
  memory-should-contain [
    4 <- 1  # empty?
    5 <- 0  # full?
  ]
]

## cancelling channels

# every channel comes with a boolean signifying if it's been closed
# initially this boolean is false
# todo: can't yet include type ingredients when extending containers
container channel [
  closed?:boolean
]

# a channel can be closed from either the source or the sink
# both threads can modify it, but they can only set it, so this is a benign race
def close x:address:source:_elem -> x:address:source:_elem [
  local-scope
  load-ingredients
  chan:address:channel:_elem <- get *x, chan:offset
  *chan <- put *chan, closed?:offset, 1/true
]
def close x:address:sink:_elem -> x:address:sink:_elem [
  local-scope
  load-ingredients
  chan:address:channel:_elem <- get *x, chan:offset
  *chan <- put *chan, closed?:offset, 1/true
]

# once a channel is closed from one side, no further operations are expected from that side
# if a channel is closed for reading,
#   no further writes will be let through
# if a channel is closed for writing,
#   future reads continue until the channel empties,
#   then the channel is also closed for reading
after <channel-write-initial> [
  closed?:boolean <- get *chan, closed?:offset
  reply-if closed?
]

after <channel-read-empty> [
  closed?:boolean <- get *chan, closed?:offset
  reply-if closed?, 0/hack  # only scalar _elems supported in channels; need to support construction of arbitrary empty containers
]

## helpers

# An empty channel has first-empty and first-full both at the same value.
def channel-empty? chan:address:channel:_elem -> result:boolean [
  local-scope
  load-ingredients
  # return chan.first-full == chan.first-free
  full:number <- get *chan, first-full:offset
  free:number <- get *chan, first-free:offset
  result <- equal full, free
]

# A full channel has first-empty just before first-full, wasting one slot.
# (Other alternatives: https://en.wikipedia.org/wiki/Circular_buffer#Full_.2F_Empty_Buffer_Distinction)
def channel-full? chan:address:channel:_elem -> result:boolean [
  local-scope
  load-ingredients
  # tmp = chan.first-free + 1
  tmp:number <- get *chan, first-free:offset
  tmp <- add tmp, 1
  {
    # if tmp == chan.capacity, tmp = 0
    len:number <- capacity chan
    at-end?:boolean <- greater-or-equal tmp, len
    break-unless at-end?
    tmp <- copy 0
  }
  # return chan.first-full == tmp
  full:number <- get *chan, first-full:offset
  result <- equal full, tmp
]

def capacity chan:address:channel:_elem -> result:number [
  local-scope
  load-ingredients
  q:address:array:_elem <- get *chan, data:offset
  result <- length *q
]

# helper for channels of characters in particular
def buffer-lines in:address:source:character, buffered-out:address:sink:character -> buffered-out:address:sink:character, in:address:source:character [
  local-scope
  load-ingredients
  # repeat forever
  {
    line:address:buffer <- new-buffer 30
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
          buffer-length:number <- get *line, length:offset
          buffer-empty?:boolean <- equal buffer-length, 0
          break-if buffer-empty?
          buffer-length <- subtract buffer-length, 1
          *line <- put *line, length:offset, buffer-length
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
    # copy line into 'buffered-out'
    i:number <- copy 0
    line-contents:address:array:character <- get *line, data:offset
    max:number <- get *line, length:offset
    {
      done?:boolean <- greater-or-equal i, max
      break-if done?
      c:character <- index *line-contents, i
      buffered-out <- write buffered-out, c
      i <- add i, 1
      loop
    }
    {
      break-unless eof?
      buffered-out <- close buffered-out
      reply
    }
    loop
  }
]

scenario buffer-lines-blocks-until-newline [
  run [
    1:address:source:number, 2:address:sink:number <- new-channel 10/capacity
    _, 3:address:sink:number/buffered-stdin <- new-channel 10/capacity
    4:address:channel:number/buffered-stdin <- get *3:address:source:number, chan:offset
    5:boolean <- channel-empty? 4:address:channel:character/buffered-stdin
    assert 5:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after init]
    # buffer stdin into buffered-stdin, try to read from buffered-stdin
    6:number/buffer-routine <- start-running buffer-lines, 1:address:source:character/stdin, 3:address:sink:character/buffered-stdin
    wait-for-routine 6:number/buffer-routine
    7:boolean <- channel-empty? 4:address:channel:character/buffered-stdin
    assert 7:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after buffer-lines bring-up]
    # write 'a'
    2:address:sink:character <- write 2:address:sink:character, 97/a
    restart 6:number/buffer-routine
    wait-for-routine 6:number/buffer-routine
    8:boolean <- channel-empty? 4:address:channel:character/buffered-stdin
    assert 8:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after writing 'a']
    # write 'b'
    2:address:sink:character <- write 2:address:sink:character, 98/b
    restart 6:number/buffer-routine
    wait-for-routine 6:number/buffer-routine
    9:boolean <- channel-empty? 4:address:channel:character/buffered-stdin
    assert 9:boolean, [ 
F buffer-lines-blocks-until-newline: channel should be empty after writing 'b']
    # write newline
    2:address:sink:character <- write 2:address:sink:character, 10/newline
    restart 6:number/buffer-routine
    wait-for-routine 6:number/buffer-routine
    10:boolean <- channel-empty? 4:address:channel:character/buffered-stdin
    11:boolean/completed? <- not 10:boolean
    assert 11:boolean/completed?, [ 
F buffer-lines-blocks-until-newline: channel should contain data after writing newline]
    trace 1, [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

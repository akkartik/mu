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
    1:address:channel <- init-channel 3:literal/capacity
    1:address:channel <- write 1:address:channel, 34:literal
    2:number, 1:address:channel <- read 1:address:channel
  ]
  memory-should-contain [
    2 <- 34
  ]
]

container channel [
  # To avoid locking, writer and reader will never write to the same location.
  # So channels will include fields in pairs, one for the writer and one for the
  # reader.
  first-full:number  # for write
  first-free:number  # for read
  # A circular buffer contains values from index first-full up to (but not
  # including) index first-empty. The reader always modifies it at first-full,
  # while the writer always modifies it at first-empty.
  data:address:array:location
]

# result:address:channel <- init-channel capacity:number
recipe init-channel [
  default-space:address:array:location <- new location:type, 30:literal
  # result = new channel
  result:address:channel <- new channel:type
  # result.first-full = 0
  full:address:number <- get-address result:address:channel/deref, first-full:offset
  full:address:number/deref <- copy 0:literal
  # result.first-free = 0
  free:address:number <- get-address result:address:channel/deref, first-free:offset
  free:address:number/deref <- copy 0:literal
  # result.data = new location[ingredient+1]
  capacity:number <- next-ingredient
  capacity:number <- add capacity:number, 1:literal  # unused slot for 'full?' below
  dest:address:address:array:location <- get-address result:address:channel/deref, data:offset
  dest:address:address:array:location/deref <- new location:type, capacity:number
  reply result:address:channel
]

# chan:address:channel <- write chan:address:channel, val:location
recipe write [
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  val:location <- next-ingredient
  {
    # block if chan is full
    full:boolean <- channel-full? chan:address:channel
    break-unless full:boolean
    full-address:address:number <- get-address chan:address:channel/deref, first-full:offset
    wait-for-location full-address:address:number/deref
  }
  # store val
  circular-buffer:address:array:location <- get chan:address:channel/deref, data:offset
  free:address:number <- get-address chan:address:channel/deref, first-free:offset
  dest:address:location <- index-address circular-buffer:address:array:location/deref, free:address:number/deref
  dest:address:location/deref <- copy val:location
  # increment free
  free:address:number/deref <- add free:address:number/deref, 1:literal
  {
    # wrap free around to 0 if necessary
    len:number <- length circular-buffer:address:array:location/deref
    at-end?:boolean <- greater-or-equal free:address:number/deref, len:number
    break-unless at-end?:boolean
    free:address:number/deref <- copy 0:literal
  }
  reply chan:address:channel/same-as-ingredient:0
]

# result:location, chan:address:channel <- read chan:address:channel
recipe read [
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  {
    # block if chan is empty
    empty:boolean <- channel-empty? chan:address:channel
    break-unless empty:boolean
    free-address:address:number <- get-address chan:address:channel/deref, first-free:offset
    wait-for-location free-address:address:number/deref
  }
  # read result
  full:address:number <- get-address chan:address:channel/deref, first-full:offset
  circular-buffer:address:array:location <- get chan:address:channel/deref, data:offset
  result:location <- index circular-buffer:address:array:location/deref, full:address:number/deref
  # increment full
  full:address:number/deref <- add full:address:number/deref, 1:literal
  {
    # wrap full around to 0 if necessary
    len:number <- length circular-buffer:address:array:location/deref
    at-end?:boolean <- greater-or-equal full:address:number/deref, len:number
    break-unless at-end?:boolean
    full:address:number/deref <- copy 0:literal
  }
  reply result:location, chan:address:channel/same-as-ingredient:0
]

recipe clear-channel [
  default-space:address:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  {
    empty?:boolean <- channel-empty? chan:address:channel
    break-if empty?:boolean
    _, chan:address:channel <- read chan:address:channel
  }
  reply chan:address:channel/same-as-ingredient:0
]

scenario channel-initialization [
  run [
    1:address:channel <- init-channel 3:literal/capacity
    2:number <- get 1:address:channel/deref, first-full:offset
    3:number <- get 1:address:channel/deref, first-free:offset
  ]
  memory-should-contain [
    2 <- 0  # first-full
    3 <- 0  # first-free
  ]
]

scenario channel-write-increments-free [
  run [
    1:address:channel <- init-channel 3:literal/capacity
    1:address:channel <- write 1:address:channel, 34:literal
    2:number <- get 1:address:channel/deref, first-full:offset
    3:number <- get 1:address:channel/deref, first-free:offset
  ]
  memory-should-contain [
    2 <- 0  # first-full
    3 <- 1  # first-free
  ]
]

scenario channel-read-increments-full [
  run [
    1:address:channel <- init-channel 3:literal/capacity
    1:address:channel <- write 1:address:channel, 34:literal
    _, 1:address:channel <- read 1:address:channel
    2:number <- get 1:address:channel/deref, first-full:offset
    3:number <- get 1:address:channel/deref, first-free:offset
  ]
  memory-should-contain [
    2 <- 1  # first-full
    3 <- 1  # first-free
  ]
]

scenario channel-wrap [
  run [
    # channel with just 1 slot
    1:address:channel <- init-channel 1:literal/capacity
    # write and read a value
    1:address:channel <- write 1:address:channel, 34:literal
    _, 1:address:channel <- read 1:address:channel
    # first-free will now be 1
    2:number <- get 1:address:channel/deref, first-free:offset
    3:number <- get 1:address:channel/deref, first-free:offset
    # write second value, verify that first-free wraps
    1:address:channel <- write 1:address:channel, 34:literal
    4:number <- get 1:address:channel/deref, first-free:offset
    # read second value, verify that first-full wraps
    _, 1:address:channel <- read 1:address:channel
    5:number <- get 1:address:channel/deref, first-full:offset
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
recipe channel-empty? [
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  # return chan.first-full == chan.first-free
  full:number <- get chan:address:channel/deref, first-full:offset
  free:number <- get chan:address:channel/deref, first-free:offset
  result:boolean <- equal full:number, free:number
  reply result:boolean
]

# A full channel has first-empty just before first-full, wasting one slot.
# (Other alternatives: https://en.wikipedia.org/wiki/Circular_buffer#Full_.2F_Empty_Buffer_Distinction)
recipe channel-full? [
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  # tmp = chan.first-free + 1
  tmp:number <- get chan:address:channel/deref, first-free:offset
  tmp:number <- add tmp:number, 1:literal
  {
    # if tmp == chan.capacity, tmp = 0
    len:number <- channel-capacity chan:address:channel
    at-end?:boolean <- greater-or-equal tmp:number, len:number
    break-unless at-end?:boolean
    tmp:number <- copy 0:literal
  }
  # return chan.first-full == tmp
  full:number <- get chan:address:channel/deref, first-full:offset
  result:boolean <- equal full:number, tmp:number
  reply result:boolean
]

# result:number <- channel-capacity chan:address:channel
recipe channel-capacity [
  default-space:address:array:location <- new location:type, 30:literal
  chan:address:channel <- next-ingredient
  q:address:array:location <- get chan:address:channel/deref, data:offset
  result:number <- length q:address:array:location/deref
  reply result:number
]

scenario channel-new-empty-not-full [
  run [
    1:address:channel <- init-channel 3:literal/capacity
    2:boolean <- channel-empty? 1:address:channel
    3:boolean <- channel-full? 1:address:channel
  ]
  memory-should-contain [
    2 <- 1  # empty?
    3 <- 0  # full?
  ]
]

scenario channel-write-not-empty [
  run [
    1:address:channel <- init-channel 3:literal/capacity
    1:address:channel <- write 1:address:channel, 34:literal
    2:boolean <- channel-empty? 1:address:channel
    3:boolean <- channel-full? 1:address:channel
  ]
  memory-should-contain [
    2 <- 0  # empty?
    3 <- 0  # full?
  ]
]

scenario channel-write-full [
  run [
    1:address:channel <- init-channel 1:literal/capacity
    1:address:channel <- write 1:address:channel, 34:literal
    2:boolean <- channel-empty? 1:address:channel
    3:boolean <- channel-full? 1:address:channel
  ]
  memory-should-contain [
    2 <- 0  # empty?
    3 <- 1  # full?
  ]
]

scenario channel-read-not-full [
  run [
    1:address:channel <- init-channel 1:literal/capacity
    1:address:channel <- write 1:address:channel, 34:literal
    _, 1:address:channel <- read 1:address:channel
    2:boolean <- channel-empty? 1:address:channel
    3:boolean <- channel-full? 1:address:channel
  ]
  memory-should-contain [
    2 <- 1  # empty?
    3 <- 0  # full?
  ]
]

# helper for channels of characters in particular
# out:address:channel <- buffer-lines in:address:channel, out:address:channel
recipe buffer-lines [
  default-space:address:address:array:location <- new location:type, 30:literal
#?   $print [buffer-lines: aaa
#? ]
  in:address:channel <- next-ingredient
  out:address:channel <- next-ingredient
  # repeat forever
  {
    line:address:buffer <- init-buffer, 30:literal
    # read characters from 'in' until newline, copy into line
    {
      +next-character
      c:character, in:address:channel <- read in:address:channel
      # drop a character on backspace
      {
        # special-case: if it's a backspace
        backspace?:boolean <- equal c:character, 8:literal
        break-unless backspace?:boolean
        # drop previous character
#?         return-to-console #? 2
#?         $print [backspace! #? 1
#? ] #? 1
        {
          buffer-length:address:number <- get-address line:address:buffer/deref, length:offset
          buffer-empty?:boolean <- equal buffer-length:address:number/deref, 0:literal
          break-if buffer-empty?:boolean
#?           $print [before: ], buffer-length:address:number/deref, [ 
#? ] #? 1
          buffer-length:address:number/deref <- subtract buffer-length:address:number/deref, 1:literal
#?           $print [after: ], buffer-length:address:number/deref, [ 
#? ] #? 1
        }
#?         $exit #? 2
        # and don't append this one
        loop +next-character:label
      }
      # append anything else
#?       $print [buffer-lines: appending ], c:character, [ 
#? ]
      line:address:buffer <- buffer-append line:address:buffer, c:character
      line-done?:boolean <- equal c:character, 10:literal/newline
      break-if line-done?:boolean
      # stop buffering on eof (currently only generated by fake keyboard)
      empty-fake-keyboard?:boolean <- equal c:character, 0:literal/eof
      break-if empty-fake-keyboard?:boolean
      loop
    }
#?     return-to-console #? 1
    # copy line into 'out'
#?     $print [buffer-lines: emitting
#? ]
    i:number <- copy 0:literal
    line-contents:address:array:character <- get line:address:buffer/deref, data:offset
    max:number <- get line:address:buffer/deref, length:offset
    {
      done?:boolean <- greater-or-equal i:number, max:number
      break-if done?:boolean
      c:character <- index line-contents:address:array:character/deref, i:number
      out:address:channel <- write out:address:channel, c:character
#?       $print [writing ], i:number, [: ], c:character, [ 
#? ] #? 1
      i:number <- add i:number, 1:literal
      loop
    }
#?     $dump-trace #? 1
#?     $exit #? 1
    loop
  }
  reply out:address:channel/same-as-ingredient:1
]

scenario buffer-lines-blocks-until-newline [
  run [
    1:address:channel/stdin <- init-channel 10:literal/capacity
    2:address:channel/buffered-stdin <- init-channel 10:literal/capacity
    3:boolean <- channel-empty? 2:address:channel/buffered-stdin
    assert 3:boolean, [
F buffer-lines-blocks-until-newline: channel should be empty after init]
    # buffer stdin into buffered-stdin, try to read from buffered-stdin
    4:number/buffer-routine <- start-running buffer-lines:recipe, 1:address:channel/stdin, 2:address:channel/buffered-stdin
    wait-for-routine 4:number/buffer-routine
    5:boolean <- channel-empty? 2:address:channel/buffered-stdin
    assert 5:boolean, [
F buffer-lines-blocks-until-newline: channel should be empty after buffer-lines bring-up]
    # write 'a'
    1:address:channel <- write 1:address:channel, 97:literal/a
    restart 4:number/buffer-routine
    wait-for-routine 4:number/buffer-routine
    6:boolean <- channel-empty? 2:address:channel/buffered-stdin
    assert 6:boolean, [
F buffer-lines-blocks-until-newline: channel should be empty after writing 'a']
    # write 'b'
    1:address:channel <- write 1:address:channel, 98:literal/b
    restart 4:number/buffer-routine
    wait-for-routine 4:number/buffer-routine
    7:boolean <- channel-empty? 2:address:channel/buffered-stdin
    assert 7:boolean, [
F buffer-lines-blocks-until-newline: channel should be empty after writing 'b']
    # write newline
    1:address:channel <- write 1:address:channel, 10:literal/newline
    restart 4:number/buffer-routine
    wait-for-routine 4:number/buffer-routine
    8:boolean <- channel-empty? 2:address:channel/buffered-stdin
    9:boolean/completed? <- not 8:boolean
    assert 9:boolean/completed?, [
F buffer-lines-blocks-until-newline: channel should contain data after writing newline]
    trace [test], [reached end]
  ]
  trace-should-contain [
    test: reached end
  ]
]

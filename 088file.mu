# Wrappers around file system primitives that take a 'resources' object and
# are thus easier to test.
#
# - start-reading - asynchronously open a file, returning a channel source for
#   receiving the results
# - start-writing - asynchronously open a file, returning a channel sink for
#   the data to write
# - slurp - synchronously read from a file
# - dump - synchronously write to a file

container resources [
  lock:bool
  data:&:@:resource
]

container resource [
  name:text
  contents:text
]

def start-reading resources:&:resources, filename:text -> contents:&:source:char, error?:bool [
  local-scope
  load-ingredients
  error? <- copy 0/false
  {
    break-unless resources
    # fake file system
    contents, error? <- start-reading-from-fake-resource resources, filename
    return
  }
  # real file system
  file:num <- $open-file-for-reading filename
  return-unless file, 0/contents, 1/error?
  contents:&:source:char, sink:&:sink:char <- new-channel 30
  start-running receive-from-file file, sink
]

def slurp resources:&:resources, filename:text -> contents:text, error?:bool [
  local-scope
  load-ingredients
  source:&:source:char, error?:bool <- start-reading resources, filename
  return-if error?, 0/contents
  buf:&:buffer:char <- new-buffer 30/capacity
  {
    c:char, done?:bool, source <- read source
    break-if done?
    buf <- append buf, c
    loop
  }
  contents <- buffer-to-array buf
]

def start-reading-from-fake-resource resources:&:resources, resource:text -> contents:&:source:char, error?:bool [
  local-scope
  load-ingredients
  error? <- copy 0/no-error
  i:num <- copy 0
  data:&:@:resource <- get *resources, data:offset
  len:num <- length *data
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    tmp:resource <- index *data, i
    i <- add i, 1
    curr-resource:text <- get tmp, name:offset
    found?:bool <- equal resource, curr-resource
    loop-unless found?
    contents:&:source:char, sink:&:sink:char <- new-channel 30
    curr-contents:text <- get tmp, contents:offset
    start-running receive-from-text curr-contents, sink
    return
  }
  return 0/not-found, 1/error
]

def receive-from-file file:num, sink:&:sink:char -> sink:&:sink:char [
  local-scope
  load-ingredients
  {
    c:char, eof?:bool <- $read-from-file file
    break-if eof?
    sink <- write sink, c
    loop
  }
  sink <- close sink
  file <- $close-file file
]

def receive-from-text contents:text, sink:&:sink:char -> sink:&:sink:char [
  local-scope
  load-ingredients
  i:num <- copy 0
  len:num <- length *contents
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    c:char <- index *contents, i
    sink <- write sink, c
    i <- add i, 1
    loop
  }
  sink <- close sink
]

def start-writing resources:&:resources, filename:text -> sink:&:sink:char, routine-id:num, error?:bool [
  local-scope
  load-ingredients
  error? <- copy 0/false
  source:&:source:char, sink:&:sink:char <- new-channel 30
  {
    break-unless resources
    # fake file system
    routine-id <- start-running transmit-to-fake-resource resources, filename, source
    return
  }
  # real file system
  file:num <- $open-file-for-writing filename
  return-unless file, 0/sink, 0/routine-id, 1/error?
  {
    break-if file
    msg:text <- append [no such file: ] filename
    assert file, msg
  }
  routine-id <- start-running transmit-to-file file, source
]

def dump resources:&:resources, filename:text, contents:text -> resources:&:resources, error?:bool [
  local-scope
  load-ingredients
  # todo: really create an empty file
  return-unless contents, resources, 0/no-error
  sink-file:&:sink:char, write-routine:num, error?:bool <- start-writing resources, filename
  return-if error?
  i:num <- copy 0
  len:num <- length *contents
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    c:char <- index *contents, i
    sink-file <- write sink-file, c
    i <- add i, 1
    loop
  }
  close sink-file
  # make sure to wait for the file to be actually written to disk
  # (Mu practices structured concurrency: http://250bpm.com/blog:71)
  wait-for-routine write-routine
]

def transmit-to-file file:num, source:&:source:char -> source:&:source:char [
  local-scope
  load-ingredients
  {
    c:char, done?:bool, source <- read source
    break-if done?
    $write-to-file file, c
    loop
  }
  file <- $close-file file
]

def transmit-to-fake-resource resources:&:resources, filename:text, source:&:source:char -> resources:&:resources, source:&:source:char [
  local-scope
  load-ingredients
  lock:location <- get-location *resources, lock:offset
  wait-for-reset-then-set lock
  # compute new file contents
  buf:&:buffer:char <- new-buffer 30
  {
    c:char, done?:bool, source <- read source
    break-if done?
    buf <- append buf, c
    loop
  }
  contents:text <- buffer-to-array buf
  new-resource:resource <- merge filename, contents
  # write to resources
  curr-filename:text <- copy 0
  data:&:@:resource <- get *resources, data:offset
  # replace file contents if it already exists
  i:num <- copy 0
  len:num <- length *data
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    tmp:resource <- index *data, i
    curr-filename <- get tmp, name:offset
    found?:bool <- equal filename, curr-filename
    {
      break-unless found?
      put-index *data, i, new-resource
      jump +unlock-and-exit
    }
    i <- add i, 1
    loop
  }
  # if file didn't already exist, make room for it
  new-len:num <- add len, 1
  new-data:&:@:resource <- new resource:type, new-len
  put *resources, data:offset, new-data
  # copy over old files
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    tmp:resource <- index *data, i
    put-index *new-data, i, tmp
  }
  # write new file
  put-index *new-data, len, new-resource
  +unlock-and-exit
  reset lock
]

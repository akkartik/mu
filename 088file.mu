# Wrappers around file system primitives that take a 'resources' object and
# are thus easier to test.

container resources [
  data:&:@:resource
]

container resource [
  name:text
  contents:text
]

def start-reading resources:&:resources, filename:text -> contents:&:source:char [
  local-scope
  load-ingredients
  {
    break-if resources
    # real file system
    file:num <- $open-file-for-reading filename
    assert file, [file not found]
    contents:&:source:char, sink:&:sink:char <- new-channel 30
    start-running receive-from-file file, sink
    return
  }
  # fake file system
  i:num <- copy 0
  data:&:@:resource <- get *resources, data:offset
  len:num <- length *data
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    tmp:resource <- index *data, i
    i <- add i, 1
    curr-filename:text <- get tmp, name:offset
    found?:bool <- equal filename, curr-filename
    loop-unless found?
    contents:&:source:char, sink:&:sink:char <- new-channel 30
    curr-contents:text <- get tmp, contents:offset
    start-running receive-from-text curr-contents, sink
    return
  }
  return 0/not-found
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

def start-writing resources:&:resources, filename:text -> sink:&:sink:char, routine-id:num [
  local-scope
  load-ingredients
  source:&:source:char, sink:&:sink:char <- new-channel 30
  {
    break-if resources
    # real file system
    file:num <- $open-file-for-writing filename
    assert file, [no such file]
    routine-id <- start-running transmit-to-file file, source
    reply
  }
  # fake file system
  # beware: doesn't support multiple concurrent writes yet
  routine-id <- start-running transmit-to-fake-file resources, filename, source
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

def transmit-to-fake-file resources:&:resources, filename:text, source:&:source:char -> resources:&:resources, source:&:source:char [
  local-scope
  load-ingredients
  # compute new file contents
  buf:&:buffer <- new-buffer 30
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
    loop-unless found?
    put-index *data, i, new-resource
    reply
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
]

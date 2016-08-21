# Wrappers around file-system primitives that take a 'filesystem' object and
# are thus easier to test.

container filesystem [
  data:address:array:file-mapping
]

container file-mapping [
  name:address:array:character
  contents:address:array:character
]

def start-reading fs:address:filesystem, filename:address:array:character -> contents:address:source:character [
  local-scope
  load-ingredients
  {
    break-if fs
    # real file-system
    file:number <- $open-file-for-reading filename
    assert file, [file not found]
    contents:address:source:character, sink:address:sink:character <- new-channel 30
    start-running transmit-from-file file, sink
    return
  }
  # fake file system
  i:number <- copy 0
  data:address:array:file-mapping <- get *fs, data:offset
  len:number <- length *data
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    tmp:file-mapping <- index *data, i
    curr-filename:address:array:character <- get tmp, name:offset
    found?:boolean <- equal filename, curr-filename
    loop-unless found?
    contents:address:source:character, sink:address:sink:character <- new-channel 30
    curr-contents:address:array:character <- get tmp, contents:offset
    start-running transmit-from-text curr-contents, sink
    return
  }
  return 0/not-found
]

def transmit-from-file file:number, sink:address:sink:character -> sink:address:sink:character [
  local-scope
  load-ingredients
  {
    c:character <- $read-from-file file
    break-unless c
    sink <- write sink, c
    loop
  }
  sink <- close sink
  $close-file file
]

def transmit-from-text contents:address:array:character, sink:address:sink:character -> sink:address:sink:character [
  local-scope
  load-ingredients
  i:number <- copy 0
  len:number <- length *contents
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    c:character <- index *contents, i
    sink <- write sink, c
    i <- add i, 1
    loop
  }
  sink <- close sink
]

def start-writing fs:address:filesystem, filename:address:array:character -> sink:address:sink:character, routine-id:number [
  local-scope
  load-ingredients
  file:number <- $open-file-for-writing filename
  source:address:source:character, sink:address:sink:character <- new-channel 30
  routine-id <- start-running transmit-to-file file, source
]

def transmit-to-file file:number, source:address:source:character -> file:number, source:address:source:character [
  local-scope
  load-ingredients
  {
    c:character, done?:boolean, source <- read source
    break-if done?
    $write-to-file file, c
    loop
  }
  $close-file file
]

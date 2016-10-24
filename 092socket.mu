# Wrappers around socket primitives that are easier to test.

# To test server operations, just run a real client against localhost.
scenario example-server-test [
  local-scope
  # test server without a fake on a random (real) port
  # that way repeatedly running the test will give ports time to timeout and
  # close before reusing them
  make-random-nondeterministic
  port:num <- random-in-range 0/real-random-numbers, 8000, 8100
  run [
    socket:num <- $open-server-socket port
    assert socket, [ 
F - example-server-test: $open-server-socket failed]
    handler-routine:number <- start-running serve-one-request socket, example-handler
  ]
  source:&:source:char <- start-reading-from-network 0/real-resources, [localhost/], port
  response:text <- drain source
  10:@:char/raw <- copy *response
  memory-should-contain [
    10:array:character <- [abc]
  ]
]
# helper just for this scenario
def example-handler query:text -> response:text [
  local-scope
  load-ingredients
  reply [abc]
]

# To test client operations, use `assume-resources` with a filename that
# begins with a hostname. (Filenames starting with '/' are assumed to be
# local.)
scenario example-client-test [
  local-scope
  assume-resources [
    [example.com/] <- [
      |abc|
    ]
  ]
  run [
    source:&:source:char <- start-reading-from-network resources, [example.com/]
  ]
  contents:text <- drain source
  10:@:char/raw <- copy *contents
  memory-should-contain [
    10:array:character <- [abc
]
  ]
]

type request-handler = (recipe text -> text)

def serve-one-request socket:num, request-handler:request-handler [
  local-scope
  load-ingredients
  session:num <- $accept socket
  assert session, [ 
F - example-server-test: $accept failed]
  contents:&:source:char, sink:&:sink:char <- new-channel 30
  sink <- start-running receive-from-socket session, sink
  query:text <- drain contents
  response:text <- call request-handler, query
  write-to-socket session, response
  $close-socket session
]

def start-reading-from-network resources:&:resources, uri:text -> contents:&:source:char [
  local-scope
  load-ingredients
  {
    port:num, port-found?:boolean <- next-ingredient
    break-if port-found?
    port <- copy 80/http-port
  }
  {
    break-if resources
    # real network
    host:text, path:text <- split-at uri, 47/slash
    socket:num <- $open-client-socket host, port
    assert socket, [contents]
    req:text <- interpolate [GET _ HTTP/1.1], path
    request-socket socket, req
    contents:&:source:char, sink:&:sink:char <- new-channel 10000
    start-running receive-from-socket socket, sink
    return
  }
  # fake network
  contents <- start-reading-from-fake-resources resources, uri
]

def request-socket socket:num, s:text -> socket:num [
  local-scope
  load-ingredients
  write-to-socket socket, s
  $write-to-socket socket, 13/cr
  $write-to-socket socket, 10/lf
  # empty line to delimit request
  $write-to-socket socket, 13/cr
  $write-to-socket socket, 10/lf
]

def receive-from-socket socket:num, sink:&:sink:char -> sink:&:sink:char [
  local-scope
  load-ingredients
  {
    +next-attempt
    req:text, found?:bool, eof?:bool, error:num <- $read-from-socket socket, 4096/bytes
    break-if error
    {
      break-if found?
      switch
      loop +next-attempt
    }
    bytes-read:num <- length *req
    i:num <- copy 0
    {
      done?:bool <- greater-or-equal i, bytes-read
      break-if done?
      c:char <- index *req, i  # todo: unicode
      sink <- write sink, c
      i <- add i, 1
      loop
    }
    loop-unless eof?
  }
  sink <- close sink
]

def write-to-socket socket:num, s:text [
  local-scope
  load-ingredients
  len:num <- length *s
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    c:char <- index *s, i
    $write-to-socket socket, c
    i <- add i, 1
    loop
  }
]

# like split-first, but don't eat the delimiter
def split-at text:text, delim:char -> x:text, y:text [
  local-scope
  load-ingredients
  # empty text? return empty texts
  len:num <- length *text
  {
    empty?:bool <- equal len, 0
    break-unless empty?
    x:text <- new []
    y:text <- new []
    return
  }
  idx:num <- find-next text, delim, 0
  x:text <- copy-range text, 0, idx
  y:text <- copy-range text, idx, len
]

scenario text-split-at [
  local-scope
  x:text <- new [a/b]
  run [
    y:text, z:text <- split-at x, 47/slash
    10:@:char/raw <- copy *y
    20:@:char/raw <- copy *z
  ]
  memory-should-contain [
    10:array:character <- [a]
    20:array:character <- [/b]
  ]
]

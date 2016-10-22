# Wrappers around socket primitives that are easier to test.
#
# To test client operations, use `assume-resources` with a filename that
# begins with a hostname. (Filenames starting with '/' are assumed to be
# local.)
#
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
    $print [server socket: ], socket, 10/newline
    assert socket, [ 
F - example-server-test: $open-server-socket failed]
    $print [starting up server routine], 10/newline
    handler-routine:number <- start-running serve-one-request socket, example-handler
  ]
  $print [starting to read from port ], port, 10/newline
  source:&:source:char <- start-reading-from-network 0/real-resources, [localhost], [/], port
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

#? scenario example-client-test [
#?   local-scope
#?   assume-resources [
#?     [example.com/] -> [abc]
#?   ]
#?   run [
#?     source:&:source:char <- start-reading-from-network resources, [example.com], [/]
#?   ]
#?   contents:text <- drain source
#?   10:@:char/raw <- copy *contents
#?   memory-should-contain [
#?     10:address:character <- [abc]
#?   ]
#? ]

type request-handler = (recipe text -> text)

def serve-one-request socket:num, request-handler:request-handler [
  local-scope
  load-ingredients
  session:num <- $accept socket
  $print [server session socket: ], session, 10/newline
  assert session, [ 
F - example-server-test: $accept failed]
  contents:&:source:char, sink:&:sink:char <- new-channel 30
  sink <- start-running receive-from-socket session, sink
  query:text <- drain contents
  response:text <- call request-handler, query
  write-to-socket session, response
  $close-socket session
]

def start-reading-from-network resources:&:resources, host:text, path:text -> contents:&:source:char [
  local-scope
  load-ingredients
  $print [running start-reading-from-network], 10/newline
  {
    port:num, port-found?:boolean <- next-ingredient
    break-if port-found?
    port <- copy 80/http-port
  }
  {
    break-if resources
    # real network
    socket:num <- $open-client-socket host, port
    $print [client socket: ], socket, 10/newline
    assert socket, [contents]
    req:text <- interpolate [GET _ HTTP/1.1], path
    request-socket socket, req
    contents:&:source:char, sink:&:sink:char <- new-channel 10000
    start-running receive-from-socket socket, sink
    return
  }
  # fake network
#?   i:num <- copy 0
#?   data:&:@:resource <- get *fs, data:offset
#?   len:num <- length *data
#?   {
#?     done?:bool <- greater-or-equal i, len
#?     break-if done?
#?     tmp:resource <- index *data, i
#?     i <- add i, 1
#?     curr-filename:text <- get tmp, name:offset
#?     found?:bool <- equal filename, curr-filename
#?     loop-unless found?
#?     contents:&:source:char, sink:&:sink:char <- new-channel 30
#?     curr-contents:text <- get tmp, contents:offset
#?     start-running transmit-from-text curr-contents, sink
#?     return
#?   }
  return 0/not-found
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

#? def start-writing-socket network:&:local-network, port:num -> sink:&:sink:char, routine-id:num [
#?   local-scope
#?   load-ingredients
#?   source:&:source:char, sink:&:sink:char <- new-channel 30
#?   {
#?     break-if network
#?     socket:num <- $open-server-socket port
#?     session:num <- $accept socket
#?     # TODO Create channel implementation of write-to-socket.
#?     return sink, 0/routine-id
#?   }
#?   # fake network
#?   routine-id <- start-running transmit-to-fake-socket network, port, source
#? ]

#? def transmit-to-fake-socket network:&:local-network, port:num, source:&:source:char -> network:&:local-network, source:&:source:char [
#?   local-scope
#?   load-ingredients
#?   # compute new port connection contents
#?   buf:&:buffer <- new-buffer 30
#?   {
#?     c:char, done?:bool, source <- read source
#?     break-unless c
#?     buf <- append buf, c
#?     break-if done?
#?     loop
#?   }
#?   contents:text <- buffer-to-array buf
#?   new-port-connection:&:port-connection <- new-port-connection port, contents
#?   # Got the contents of the channel, time to write to fake port.
#?   i:num <- copy 0
#?   port-connections:&:@:port-connection <- get *network, data:offset
#?   len:num <- length *port-connections
#?   {
#?     done?:bool <- greater-or-equal i, len
#?     break-if done?
#?     current:port-connection <- index *port-connections, i
#?     current-port:num <- get current, port:offset
#?     ports-match?:bool <- equal current-port, port
#?     i <- add i, 1
#?     loop-unless ports-match?
#?     # Found an existing connection on this port, overwrite.
#?     put-index *port-connections, i, *new-port-connection
#?     reply
#?   }
#?   # Couldn't find an existing connection on this port, initialize a new one.
#?   new-len:num <- add len, 1
#?   new-port-connections:&:@:port-connection <- new port-connection:type, new-len
#?   put *network, data:offset, new-port-connections
#?   i:num <- copy 0
#?   {
#?     done?:bool <- greater-or-equal i, len
#?     break-if done?
#?     tmp:port-connection <- index *port-connections, i
#?     put-index *new-port-connections, i, tmp
#?   }
#?   put-index *new-port-connections, len, *new-port-connection
#? ]

def receive-from-socket socket:num, sink:&:sink:char -> sink:&:sink:char [
  local-scope
  load-ingredients
  {
    $print [read-from-socket ], socket, 10/newline
    req:text, eof?:bool <- $read-from-socket socket, 4096/bytes
    loop-unless req
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

# Wrappers around socket primitives that take a 'network-interface' object and
# are thus easier to test.
# The current semantics of fake port-connections don't match UNIX socket ones, but we'll improve them as we learn more.
container local-network [
  data:&:@:port-connection
]

# Port connections represent connections to ports on localhost.
# Before passing a local-network object to network functions
# `start-reading` and `start-writing`, add port-connections to the
# local-network.
#
# For reading, `transmit-from-socket` will check for a
# port-connection on the port parameter that's been passed in. If there's
# no port-connectin for that port, it will return nothing and log. If
# there is a port-connection for that port, it will transmit the contents
# to the passed in sink.
#
# For writing, `start-writing-socket` returns a sink connecting the
# caller to the socket on the passed-in port.
container port-connection [
  port:num
  contents:text
]

def new-port-connection port:num, contents:text -> p:&:port-connection [
  local-scope
  load-ingredients
  p:&:port-connection <- new port-connection:type
  *p <- merge port, contents
]

def new-fake-network -> n:&:local-network [
  local-scope
  load-ingredients
  n:&:local-network <- new local-network:type
  local-network-ports:&:@:port-connection <- new port-connection:type, 0
  *n <- put *n, data:offset, local-network-ports
]

scenario write-to-fake-socket [
  local-scope
  single-port-network:&:local-network <- new-fake-network
  sink:&:sink:char, writer:num/routine <- start-writing-socket single-port-network, 8080
  sink <- write sink, 120/x
  close sink
  wait-for-routine writer
  tested-port-connections:&:@:port-connection <- get *single-port-network, data:offset
  tested-port-connection:port-connection <- index *tested-port-connections, 0
  contents:text <- get tested-port-connection, contents:offset
  10:@:char/raw <- copy *contents
  memory-should-contain [
    10:array:character <- [x]
  ]
]

def start-writing-socket network:&:local-network, port:num -> sink:&:sink:char, routine-id:num [
  local-scope
  load-ingredients
  source:&:source:char, sink:&:sink:char <- new-channel 30
  {
    break-if network
    socket:num <- $socket port
    session:num <- $accept socket
    # TODO Create channel implementation of write-to-socket.
    return sink, 0/routine-id
  }
  # fake network
  routine-id <- start-running transmit-to-fake-socket network, port, source
]

def transmit-to-fake-socket network:&:local-network, port:num, source:&:source:char -> network:&:local-network, source:&:source:char [
  local-scope
  load-ingredients
  # compute new port connection contents
  buf:&:buffer <- new-buffer 30
  {
    c:char, done?:bool, source <- read source
    break-unless c
    buf <- append buf, c
    break-if done?
    loop
  }
  contents:text <- buffer-to-array buf
  new-port-connection:&:port-connection <- new-port-connection port, contents
  # Got the contents of the channel, time to write to fake port.
  i:num <- copy 0
  port-connections:&:@:port-connection <- get *network, data:offset
  len:num <- length *port-connections
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    current:port-connection <- index *port-connections, i
    current-port:num <- get current, port:offset
    ports-match?:bool <- equal current-port, port
    i <- add i, 1
    loop-unless ports-match?
    # Found an existing connection on this port, overwrite.
    put-index *port-connections, i, *new-port-connection
    reply
  }
  # Couldn't find an existing connection on this port, initialize a new one.
  new-len:num <- add len, 1
  new-port-connections:&:@:port-connection <- new port-connection:type, new-len
  put *network, data:offset, new-port-connections
  i:num <- copy 0
  {
    done?:bool <- greater-or-equal i, len
    break-if done?
    tmp:port-connection <- index *port-connections, i
    put-index *new-port-connections, i, tmp
  }
  put-index *new-port-connections, len, *new-port-connection
]

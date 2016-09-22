# Example of reading from a socket using channels and writing back to it
# directly. Running this file and navigating to <address of server>:8080
# should result in your browser displaying "SUCCESS!".
#
# Unfortunately, the reading implementation has some redundant, inelegant
# code to make up for my lack of insight into Linux's socket internals.
def main [
  local-scope
  socket:num <- $socket 8080/port
  $print [Mu socket creation returned ], socket, 10/newline
  session:num <- $accept socket
  contents:&:source:char, sink:&:sink:char <- new-channel 30
  sink <- start-running transmit-from-socket session, sink
  buf:&:buffer <- new-buffer 30
  {
    c:char, done?:bool, contents <- read contents
    break-if done?
    buf <- append buf, c
    loop
  }
  socket-text:text <- buffer-to-array buf
  $print [Done reading from socket.], 10/newline
  write-to-socket session, [HTTP/1.0 200 OK
Content-type: text/plain

SUCCESS!
]
  $print 10/newline, [Wrote to and closing socket...], 10/newline
  $close-socket session
  $close-socket socket
]

def write-to-socket session-socket:number, s:address:array:character [
  local-scope
  load-ingredients
  len:number <- length *s
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    c:character <- index *s, i
    $print [writing to socket: ], i, [ ], c, 10/newline
    $write-to-socket session-socket, c
    i <- add i, 1
    loop
  }
]

def transmit-from-socket session:num, sink:&:sink:char -> sink:&:sink:char [
  local-scope
  load-ingredients
  {
    req:text, bytes-read:number <- $read-from-socket session, 4096/bytes
    $print [read ], bytes-read, [ bytes from socket], 10/newline
    i:number <- copy 0
    {
      done?:boolean <- greater-or-equal i, bytes-read
      break-if done?
      c:char <- index *req, i
      end-of-request?:bool <- equal c, 10/newline
      break-if end-of-request? # To be safe, for now.
      sink <- write sink, c
      i <- add i, 1
      loop
    }
  }
  sink <- close sink
]

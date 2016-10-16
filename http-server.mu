# example program: a single-request HTTP server
#   listen for connections from clients on a server socket
#   when a connection occurs, transfer it to a session socket
#   read from it using channels
#   write to it directly
#
# After running it, navigate to localhost:8080. Your browser should display
# "SUCCESS!" and the server will terminate after one connection.

def main [
  local-scope
  socket:num <- $open-server-socket 8080/port
  $print [Mu socket creation returned ], socket, 10/newline
  return-unless socket
  session:num <- $accept socket
  contents:&:source:char, sink:&:sink:char <- new-channel 30
  sink <- start-running receive-from-socket session, sink
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

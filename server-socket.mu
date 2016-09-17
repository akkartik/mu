def main [
  local-scope
  socket:num <- $socket 8080/port
  $print [Mu socket creation returned ], socket, 10/newline
  session:num <- $accept socket
  {
    client-message:&:buffer <- new-buffer 1024
    c:char <- $read-from-socket session
    break-unless c
    $print c
    loop
  }
  $close-socket socket, session
]

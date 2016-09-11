def main [
  local-scope
  socket:number <- $socket 8080/port
  $print [Mu socket creation returned ], socket, 10/newline
  session:number <- $accept socket
  {
    client-message:address:buffer <- new-buffer 1024
    c:character <- $read-from-socket session
    break-unless c
    $print c
    loop
  }
  $close-socket socket, session
]

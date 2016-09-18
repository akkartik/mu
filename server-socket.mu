def main [
  local-scope
  socket:num <- $socket 8080/port
  $print [Mu socket creation returned ], socket, 10/newline
  session:num <- $accept socket
  write-to-socket session, [HTTP/1.0 200 OK

OK]
  {
    c:char, eof?:boolean <- $read-from-socket session
    $print c
    break-if eof?
    loop
  }
  $print 10/newline, [Hit end of socket, closing...], 10/newline
  $close-socket socket, session
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
    $write-to-socket session-socket, c
    i <- add i, 1
    loop
  }
]

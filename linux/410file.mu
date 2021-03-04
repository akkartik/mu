fn read-lines in: (addr buffered-file), out: (addr handle array (handle array byte)) {
  var stream: (stream (handle array byte) 0x10)
  var stream-a/edi: (addr stream (handle array byte)) <- address stream
  var line: (stream byte 0x10)
  var line-a/esi: (addr stream byte) <- address line
  {
    clear-stream line-a
    read-line-buffered in, line-a
    var done?/eax: boolean <- stream-empty? line-a
    compare done?, 0/false
    break-if-!=
#?     print-string 0, "AAA\n"
    var h: (handle array byte)
    var ah/eax: (addr handle array byte) <- address h
    stream-to-array line-a, ah
    write-to-stream stream-a, ah
    loop
  }
  stream-to-array stream-a, out
}

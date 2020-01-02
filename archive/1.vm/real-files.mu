# example program: read a character from one file and write it to another
# BEWARE: this will modify your file system
# before running it, put a character into /tmp/mu-x
# after running it, check /tmp/mu-y

def main [
  local-scope
  f:num/file <- $open-file-for-reading [/tmp/mu-x]
  $print [file to read from: ], f, 10/newline
  c:char, eof?:bool <- $read-from-file f
  $print [copying ], c, 10/newline
  f <- $close-file f
  $print [file after closing: ], f, 10/newline
  f <- $open-file-for-writing [/tmp/mu-y]
  $print [file to write to: ], f, 10/newline
  $write-to-file f, c
  f <- $close-file f
]

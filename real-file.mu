# example program: read a character from one file and write it to another
# before running it, put a character into /tmp/mu-x

def main [
  local-scope
  f:number/file <- real-open-file-for-reading [/tmp/mu-x]
  $print [file to read from: ], f, 10/newline
  c:character <- real-read-from-file f
  $print [copying ], c, 10/newline
  f <- real-close-file f
  $print [file after closing: ], f, 10/newline
  f <- real-open-file-for-writing [/tmp/mu-y]
  $print [file to write to: ], f, 10/newline
  real-write-to-file f, c
  f <- real-close-file f
]

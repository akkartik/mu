def main [
  local-scope
  $print [file to read from: ], [/tmp/mu-fs]
  # initialize filesystem
  fs:address:filesystem <- copy 0/real-filesystem
  content-source:address:source:character <- start-reading fs, [/tmp/mu-fs]
  # read from channel until exhausted and print out characters
  {
    c:character, done?:boolean, content-source <- read content-source
    break-if done?
    $print [Next: ], c, 10/newline
    loop
  }
  $print [Done reading], 10/newline
  # TODO: writing to file
]

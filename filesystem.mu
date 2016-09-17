# example program: copy one file into another, character by character
# BEWARE: this will modify your file system
# before running it, put some text into /tmp/mu-x
# after running it, check /tmp/mu-y

def main [
  local-scope
  source-file:&:source:char <- start-reading 0/real-filesystem, [/tmp/mu-x]
  sink-file:&:sink:char, write-routine:num <- start-writing 0/real-filesystem, [/tmp/mu-y]
  {
    c:char, done?:boolean, source-file <- read source-file
    break-if done?
    sink-file <- write sink-file, c
    loop
  }
  close sink-file
  # make sure to wait for the file to be actually written to disk
  # (Mu practices structured concurrency: http://250bpm.com/blog:71)
  wait-for-routine write-routine
]

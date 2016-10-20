# example program: reading a URL over HTTP

def main [
  local-scope
  google:&:source:char <- start-reading-from-network 0/real-resources, [google.com], [/]
  n:num <- copy 0
  b:&:buffer <- new-buffer 30
  {
    c:char, done?:bool <- read google
    break-if done?
    n <- add n, 1
    b <- append b, c
#?     trunc?:bool <- greater-or-equal n, 10000
#?     loop-unless trunc?
    loop
  }
  result:text <- buffer-to-array b
  open-console
  len:num <- length *result
  print 0/real-screen, result
  wait-for-some-interaction
  close-console
]

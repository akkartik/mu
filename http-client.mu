# example program: reading a URL over HTTP

def main [
  local-scope
  $print [aaa] 10/newline
  google:&:source:char <- start-reading-from-network 0/real-resources, [google.com/]
  $print [bbb] 10/newline
  n:num <- copy 0
  buf:&:buffer:char <- new-buffer 30
  {
    c:char, done?:bool <- read google
    break-if done?
    n <- add n, 1
    buf <- append buf, c
    {
      _, a:num <- divide-with-remainder n, 100
      break-if a
      $print n 10/newline
    }
    loop
  }
  result:text <- buffer-to-array buf
  open-console
  clear-screen 0/screen  # non-scrolling app
  len:num <- length *result
  print 0/real-screen, result
  wait-for-some-interaction
  close-console
]

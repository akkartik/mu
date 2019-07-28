# example program: running multiple routines

def main [
  start-running thread2
  {
    $print 34
    loop
  }
]

def thread2 [
  {
    $print 35
    loop
  }
]

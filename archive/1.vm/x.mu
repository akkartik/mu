# example program: add two numbers

def main [
  11:num <- copy 1
  12:num <- copy 3
  13:num <- add 11:num, 12:num
  $dump-memory
]

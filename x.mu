# example program: add two numbers

recipe main [
  11:number <- copy 1:literal
  12:number <- copy 3:literal
  13:number <- add 11:number, 12:number
  $dump-memory
]

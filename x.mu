# example program: add two numbers

recipe main [
  11:integer <- copy 1:literal
  12:integer <- copy 3:literal
  13:integer <- add 11:integer, 12:integer
  $dump-memory
]

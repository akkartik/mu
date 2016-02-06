# From http://burtleburtle.net/bob/hash/hashfaq.html#example
# Though this one doesn't behave the same because mu uses doubles under the
# hood, which wrap around at a different limit.
recipe hash x:address:shared:array:character -> n:number [
  local-scope
  load-ingredients
  n <- copy 0
  len:number <- length *x
  i:number <- copy 0
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    c:character <- index *x, i
    n <- add n, c
    tmp1:number <- shift-left n, 10
    n <- add n, tmp1
    tmp2:number <- shift-right n, 6
    n <- xor-bits n, tmp2
    tmp3:number <- shift-left n, 3
    n <- add n, tmp3
    tmp4:number <- shift-right n, 11
    n <- xor-bits n, tmp4
    tmp5:number <- shift-left n, 15
    n <- add n, tmp5
    i <- add i, 1
    loop
  }
]

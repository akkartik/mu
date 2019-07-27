# c = (f-32) * 5/9
def fahrenheit-to-celsius [
  local-scope
  f:number <- next-ingredient
  tmp:number <- subtract f, 32
  tmp <- multiply tmp, 5
  c:number <- divide tmp, 9
  return c
]

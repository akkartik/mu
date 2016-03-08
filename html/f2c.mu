# c = (f-32) * 5/9
recipe fahrenheit-to-celsius f:number -> c:number [
  local-scope
  load-ingredients
  tmp:number <- subtract f, 32
  tmp <- multiply tmp, 5
  c <- divide tmp, 9
]

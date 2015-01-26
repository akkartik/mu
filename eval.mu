; example of calling to underlying arc eval

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (s:string-address <- new "(+ 1 1)")
  (t:string-address <- $eval s:string-address)
  (print-string nil:literal/terminal t:string-address)
])

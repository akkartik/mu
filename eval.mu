; example of calling to underlying arc eval

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (s:string-address <- new "(+ 1 1)")
  (t:string-address <- $eval s:string-address)
  (print-primitive-to-host t:string-address)
  ; then you'll have to read off the characters starting at string-address 't'
])

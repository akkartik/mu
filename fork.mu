(main
  (fork (thread2 fn))
  ((1 integer) <- literal 34)
  (print (1 integer))
  (jmp (-2 offset))
)

(thread2
  ((2 integer) <- literal 35)
  (print (2 integer))
  (jmp (-2 offset))
)

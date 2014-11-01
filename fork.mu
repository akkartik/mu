(main
  (fork (thread2 fn))
  ((default-scope scope-address) <- new (scope literal) (2 literal))
  ((x integer) <- copy (34 literal))
  { begin
    (print-primitive (x integer))
    (continue)
  }
)

(thread2
  ((default-scope scope-address) <- new (scope literal) (2 literal))
  ((y integer) <- copy (35 literal))
  { begin
    (print-primitive (y integer))
    (continue)
  }
)

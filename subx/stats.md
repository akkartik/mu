                          Initial   -tests/whitespace/comments
## Lines in source
standard library           9597     2316
apps/crenshaw2-1b.subx      798      176
apps/crenshaw2-1.subx       601      180
apps/factorial.subx         107       28
apps/handle.subx            361       58
apps/hex.subx              1511      144
apps/pack.subx             7348     1054
apps/assort.subx           1318      284
apps/dquotes.subx          2694      497
apps/survey.subx           4573      998

## Bytes in executable
crenshaw2-1               17612     4112
crenshaw2-1b              18171     4140
factorial                 16530     3488
handle                    17323     3582
hex                       22684     4909
pack                      37316     7825
assort                    22506     5342
dquotes                   27186     5849
survey                    42791    11258

## Translation speed

Emulated:
  - 35 LoC: 7.5s
  - 84 LoC: 16.8s
  - 219 LoC: 43.5s (error after 4/5 phases)

Native:
  - less than 0.1s for layers 049-052

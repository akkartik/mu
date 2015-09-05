## handling malformed programs

scenario run-shows-warnings-in-get [
  $close-trace  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  get 123:number, foo:offset
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  get 123:number, foo:offset                      ┊                                                 .
    .]                                                 ┊                                                 .
    .unknown element foo in container number           ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found                                                                                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .unknown element foo in container number                                                             .
    .                                                                                                    .
  ]
]

scenario run-shows-missing-type-warnings [
  $close-trace  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x <- copy 0
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x <- copy 0                                     ┊                                                 .
    .]                                                 ┊                                                 .
    .missing type in 'x <- copy 0'                     ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-unbalanced-bracket-warnings [
  $close-trace  # trace too long
  assume-screen 100/width, 15/height
  # recipe is incomplete (unbalanced '[')
  1:address:array:character <- new [ 
recipe foo «
  x <- copy 0
]
  string-replace 1:address:array:character, 171/«, 91  # '['
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo \\\[                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x <- copy 0                                     ┊                                                 .
    .                                                  ┊                                                 .
    .9: unbalanced '\\\[' for recipe                      ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-get-on-non-container-warnings [
  $close-trace  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:address:point <- new point:type
  get x:address:point, 1:offset
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:address:point <- new point:type               ┊                                                x.
    .  get x:address:point, 1:offset                   ┊foo                                              .
    .]                                                 ┊foo: first ingredient of 'get' should be a conta↩.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊iner, but got x:address:point                    .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-non-literal-get-argument-warnings [
  $close-trace  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:number <- copy 0
  y:address:point <- new point:type
  get *y:address:point, x:number
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy 0                              ┊                                                 .
    .  y:address:point <- new point:type               ┊                                                 .
    .  get *y:address:point, x:number                  ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: expected ingredient 1 of 'get' to have type ↩┊                                                 .
    .'offset'; got x:number                            ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-warnings-everytime [
  $close-trace  # trace too long
  # try to run a file with an error
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:number <- copy y:number
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy y:number                       ┊                                                 .
    .]                                                 ┊                                                 .
    .use before set: y in foo                          ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  # rerun the file, check for the same error
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy y:number                       ┊                                                 .
    .]                                                 ┊                                                 .
    .use before set: y in foo                          ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

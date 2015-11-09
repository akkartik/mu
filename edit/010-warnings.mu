## handling malformed programs

container programming-environment-data [
  recipe-warnings:address:array:character
]

# copy code from recipe editor, persist, load into mu, save any warnings
recipe! update-recipes env:address:programming-environment-data, screen:address:screen -> errors-found?:boolean, env:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  recipes:address:editor-data <- get *env, recipes:offset
  in:address:array:character <- editor-contents recipes
  save [recipes.mu], in
  recipe-warnings:address:address:array:character <- get-address *env, recipe-warnings:offset
  *recipe-warnings <- reload in
  # if recipe editor has errors, stop
  {
    break-unless *recipe-warnings
    status:address:array:character <- new [errors found]
    update-status screen, status, 1/red
    errors-found? <- copy 1/true
    reply
  }
  errors-found? <- copy 0/false
]

before <render-components-end> [
  trace 11, [app], [render status]
  recipe-warnings:address:array:character <- get *env, recipe-warnings:offset
  {
    break-unless recipe-warnings
    status:address:array:character <- new [errors found]
    update-status screen, status, 1/red
  }
]

before <render-recipe-components-end> [
  {
    recipe-warnings:address:array:character <- get *env, recipe-warnings:offset
    break-unless recipe-warnings
    row, screen <- render-string screen, recipe-warnings, left, right, 1/red, row
  }
]

container sandbox-data [
  warnings:address:array:character
]

recipe! update-sandbox sandbox:address:sandbox-data -> sandbox:address:sandbox-data [
  local-scope
  load-ingredients
  data:address:array:character <- get *sandbox, data:offset
  response:address:address:array:character <- get-address *sandbox, response:offset
  warnings:address:address:array:character <- get-address *sandbox, warnings:offset
  trace:address:address:array:character <- get-address *sandbox, trace:offset
  fake-screen:address:address:screen <- get-address *sandbox, screen:offset
  *response, *warnings, *fake-screen, *trace, completed?:boolean <- run-interactive data
  {
    break-if *warnings
    break-if completed?:boolean
    *warnings <- new [took too long!
]
  }
]

# make sure we render any trace
after <render-sandbox-trace-done> [
  {
    sandbox-warnings:address:array:character <- get *sandbox, warnings:offset
    break-unless sandbox-warnings
    *response-starting-row <- copy 0  # no response
    row, screen <- render-string screen, sandbox-warnings, left, right, 1/red, row
    # don't try to print anything more for this sandbox
    jump +render-sandbox-end:label
  }
]

scenario run-shows-warnings-in-get [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  get 123:number, foo:offset
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  get 123:number, foo:offset                      ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: unknown element foo in container number      ┊                                                 .
    .foo: first ingredient of 'get' should be a contai↩┊                                                 .
    .ner, but got 123:number                           ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found                                                                                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .foo: unknown element foo in container number                                                        .
    .foo: first ingredient of 'get' should be a contai                                                   .
    .ner, but got 123:number                                                                             .
    .                                                                                                    .
  ]
]

scenario run-shows-missing-type-warnings [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x <- copy 0
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x <- copy 0                                     ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: missing type for x in 'x <- copy 0'          ┊                                                 .
  ]
]

scenario run-shows-unbalanced-bracket-warnings [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  # recipe is incomplete (unbalanced '[')
  1:address:array:character <- new [ 
recipe foo «
  x <- copy 0
]
  string-replace 1:address:array:character, 171/«, 91  # '['
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
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
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:address:point <- new point:type
  get x:address:point, 1:offset
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:address:point <- new point:type               ┊                                                 .
    .  get x:address:point, 1:offset                   ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: first ingredient of 'get' should be a contai↩┊                                                 .
    .ner, but got x:address:point                      ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-non-literal-get-argument-warnings [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:number <- copy 0
  y:address:point <- new point:type
  get *y:address:point, x:number
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
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
    .foo: second ingredient of 'get' should have type ↩┊                                                 .
    .'offset', but got x:number                        ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-warnings-everytime [
  trace-until 100/app  # trace too long
  # try to run a file with an error
  assume-screen 100/width, 15/height
  1:address:array:character <- new [ 
recipe foo [
  x:number <- copy y:number
]]
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy y:number                       ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: use before set: y                            ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  # rerun the file, check for the same error
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  x:number <- copy y:number                       ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: use before set: y                            ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-and-print-warnings [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [get 1234:number, foo:offset]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # check that screen prints error message in red
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊get 1234:number, foo:offset                      .
    .                                                  ┊unknown element foo in container number          .
    .                                                  ┊first ingredient of 'get' should be a container,↩.
    .                                                  ┊ but got 1234:number                             .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   get 1234:number, foo:offset                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 1/red, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   unknown element foo in container number          .
    .                                                   first ingredient of 'get' should be a container, .
    .                                                    but got 1234:number                             .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
    .                                                  ┊                                                ↩.
    .                                                  ┊                                                 .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-and-print-warnings-only-once [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an illegal instruction
  2:address:array:character <- new [get 1234:number, foo:offset]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  # run the code in the editors multiple times
  assume-console [
    press F4
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊get 1234:number, foo:offset                      .
    .                                                  ┊unknown element foo in container number          .
    .                                                  ┊first ingredient of 'get' should be a container,↩.
    .                                                  ┊ but got 1234:number                             .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario sandbox-can-handle-infinite-loop [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new [recipe foo [
  {
    loop
  }
]]
  # right editor contains an instruction
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  {                                               ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .    loop                                          ┊                                                x.
    .  }                                               ┊foo                                              .
    .]                                                 ┊took too long!                                   .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario sandbox-with-warnings-shows-trace [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # generate a stash and a warning
  1:address:array:character <- new [recipe foo [
local-scope
a:number <- next-ingredient
b:number <- next-ingredient
stash [dividing by], b
_, c:number <- divide-with-remainder a, b
reply b
]]
  2:address:array:character <- new [foo 4, 0]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  # run
  assume-console [
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  # screen prints error message
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo \\\[                                      ┊                                                 .
    .local-scope                                       ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .a:number <- next-ingredient                       ┊                                                x.
    .b:number <- next-ingredient                       ┊foo 4, 0                                         .
    .stash [dividing by], b                            ┊foo: divide by zero in '_, c:number <- divide-wi↩.
    ._, c:number <- divide-with-remainder a, b         ┊th-remainder a, b'                               .
  ]
  # click on the call in the sandbox
  assume-console [
    left-click 4, 55
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # screen should expand trace
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo \\\[                                      ┊                                                 .
    .local-scope                                       ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .a:number <- next-ingredient                       ┊                                                x.
    .b:number <- next-ingredient                       ┊foo 4, 0                                         .
    .stash [dividing by], b                            ┊dividing by 0                                    .
    ._, c:number <- divide-with-remainder a, b         ┊foo: divide by zero in '_, c:number <- divide-wi↩.
    .reply b                                           ┊th-remainder a, b'                               .
  ]
]

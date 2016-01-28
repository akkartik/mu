## handling malformed programs

container programming-environment-data [
  recipe-warnings:address:shared:array:character
]

# copy code from recipe editor, persist, load into mu, save any warnings
recipe! update-recipes env:address:shared:programming-environment-data, screen:address:shared:screen -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
#?   $log [update recipes]
  recipes:address:shared:editor-data <- get *env, recipes:offset
  in:address:shared:array:character <- editor-contents recipes
  save [recipes.mu], in
  recipe-warnings:address:address:shared:array:character <- get-address *env, recipe-warnings:offset
  *recipe-warnings <- reload in
  # if recipe editor has errors, stop
  {
    break-unless *recipe-warnings
    status:address:shared:array:character <- new [errors found     ]
    update-status screen, status, 1/red
    errors-found? <- copy 1/true
    reply
  }
  errors-found? <- copy 0/false
]

before <render-components-end> [
  trace 11, [app], [render status]
  recipe-warnings:address:shared:array:character <- get *env, recipe-warnings:offset
  {
    break-unless recipe-warnings
    status:address:shared:array:character <- new [errors found     ]
    update-status screen, status, 1/red
  }
]

before <render-recipe-components-end> [
  {
    recipe-warnings:address:shared:array:character <- get *env, recipe-warnings:offset
    break-unless recipe-warnings
    row, screen <- render screen, recipe-warnings, left, right, 1/red, row
  }
]

container programming-environment-data [
  warning-index:number  # index of first sandbox with an error (or -1 if none)
]

after <programming-environment-initialization> [
  warning-index:address:number <- get-address *result, warning-index:offset
  *warning-index <- copy -1
]

after <run-sandboxes-begin> [
  warning-index:address:number <- get-address *env, warning-index:offset
  *warning-index <- copy -1
]

before <run-sandboxes-end> [
  {
    sandboxes-completed-successfully?:boolean <- equal *warning-index, -1
    break-if sandboxes-completed-successfully?
    errors-found? <- copy 1/true
  }
]

before <render-components-end> [
  {
    break-if recipe-warnings
    warning-index:number <- get *env, warning-index:offset
    sandboxes-completed-successfully?:boolean <- equal warning-index, -1
    break-if sandboxes-completed-successfully?
    status-template:address:shared:array:character <- new [errors found (_)    ]
    warning-index-text:address:shared:array:character <- to-text warning-index
    status:address:shared:array:character <- interpolate status-template, warning-index-text
#?     $print [update-status: sandbox warning], 10/newline
    update-status screen, status, 1/red
#?     $print [run sandboxes end], 10/newline
  }
]

container sandbox-data [
  warnings:address:shared:array:character
]

recipe! update-sandbox sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data, idx:number -> sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
#?   $log [update sandbox]
  data:address:shared:array:character <- get *sandbox, data:offset
  response:address:address:shared:array:character <- get-address *sandbox, response:offset
  warnings:address:address:shared:array:character <- get-address *sandbox, warnings:offset
  trace:address:address:shared:array:character <- get-address *sandbox, trace:offset
  fake-screen:address:address:shared:screen <- get-address *sandbox, screen:offset
#?   $print [run-interactive], 10/newline
  *response, *warnings, *fake-screen, *trace, completed?:boolean <- run-interactive data
  {
    break-if *warnings
    break-if completed?:boolean
    *warnings <- new [took too long!
]
  }
  {
    break-unless *warnings
#?     $print [setting warning-index to ], idx, 10/newline
    warning-index:address:number <- get-address *env, warning-index:offset
    warning-not-set?:boolean <- equal *warning-index, -1
    break-unless warning-not-set?
    *warning-index <- copy idx
  }
#?   $print [done with run-interactive], 10/newline
]

# make sure we render any trace
after <render-sandbox-trace-done> [
  {
    sandbox-warnings:address:shared:array:character <- get *sandbox, warnings:offset
    break-unless sandbox-warnings
    *response-starting-row <- copy 0  # no response
    row, screen <- render screen, sandbox-warnings, left, right, 1/red, row
    # don't try to print anything more for this sandbox
    jump +render-sandbox-end:label
  }
]

scenario run-shows-warnings-in-get [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:shared:array:character <- new [ 
recipe foo [
  get 123:number, foo:offset
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
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

scenario run-updates-status-with-first-erroneous-sandbox [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new []
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    left-click 3, 80
    # create invalid sandbox 1
    type [get foo, x:offset]
    press F4
    # create invalid sandbox 0
    type [get foo, x:offset]
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # status line shows that error is in first sandbox
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
  ]
]

scenario run-updates-status-with-first-erroneous-sandbox-2 [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new []
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    left-click 3, 80
    # create invalid sandbox 2
    type [get foo, x:offset]
    press F4
    # create invalid sandbox 1
    type [get foo, x:offset]
    press F4
    # create valid sandbox 0
    type [add 2, 2]
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # status line shows that error is in second sandbox
  screen-should-contain [
    .  errors found (1)                                                               run (F4)           .
  ]
]

scenario run-hides-warnings-from-past-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new [get foo, x:offset]  # invalid
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4  # generate error
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  assume-console [
    left-click 3, 80
    press ctrl-k
    type [add 2, 2]  # valid code
    press F4  # update sandbox
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # error should disappear
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-updates-warnings-for-shape-shifting-recipes [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  # define a shape-shifting recipe with an error
  1:address:shared:array:character <- new [recipe foo x:_elem -> z:_elem [
local-scope
load-ingredients
z <- add x, [a]
]]
  2:address:shared:array:character <- new [foo 2]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .recipe foo x:_elem -> z:_elem [                   ┊                                                 .
    .local-scope                                       ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .load-ingredients                                  ┊0                                               x.
    .z <- add x, [a]                                   ┊foo 2                                            .
    .]                                                 ┊foo_2: 'add' requires number ingredients, but go↩.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊t [a]                                            .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # now rerun everything
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # error should remain unchanged
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .recipe foo x:_elem -> z:_elem [                   ┊                                                 .
    .local-scope                                       ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .load-ingredients                                  ┊0                                               x.
    .z <- add x, [a]                                   ┊foo 2                                            .
    .]                                                 ┊foo_2: 'add' requires number ingredients, but go↩.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊t [a]                                            .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-avoids-spurious-warnings-on-reloading-shape-shifting-recipes [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  # overload a well-known shape-shifting recipe
  1:address:shared:array:character <- new [recipe length l:address:shared:list:_elem -> n:number [
]]
  # call code that uses other variants of it, but not it itself
  2:address:shared:array:character <- new [x:address:shared:list:number <- copy 0
to-text x]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run it once
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  # no errors anywhere on screen (can't check anything else, since to-text will return an address)
  screen-should-contain-in-color 1/red, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                <-                  .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  # rerun everything
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # still no errors
  screen-should-contain-in-color 1/red, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                <-                  .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
]

scenario run-shows-missing-type-warnings [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:shared:array:character <- new [ 
recipe foo [
  x <- copy 0
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
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
  1:address:shared:array:character <- new [ 
recipe foo «
  x <- copy 0
]
  replace 1:address:shared:array:character, 171/«, 91  # '['
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
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
  1:address:shared:array:character <- new [ 
recipe foo [
  local-scope
  x:address:shared:point <- new point:type
  get x:address:shared:point, 1:offset
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  local-scope                                     ┊                                                 .
    .  x:address:shared:point <- new point:type        ┊                                                 .
    .  get x:address:shared:point, 1:offset            ┊                                                 .
    .]                                                 ┊                                                 .
    .foo: first ingredient of 'get' should be a contai↩┊                                                 .
    .ner, but got x:address:shared:point               ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario run-shows-non-literal-get-argument-warnings [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:shared:array:character <- new [ 
recipe foo [
  local-scope
  x:number <- copy 0
  y:address:shared:point <- new point:type
  get *y:address:shared:point, x:number
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  local-scope                                     ┊                                                 .
    .  x:number <- copy 0                              ┊                                                 .
    .  y:address:shared:point <- new point:type        ┊                                                 .
    .  get *y:address:shared:point, x:number           ┊                                                 .
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
  1:address:shared:array:character <- new [ 
recipe foo [
  local-scope
  x:number <- copy y:number
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  local-scope                                     ┊                                                 .
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
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .  errors found                                                                   run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  local-scope                                     ┊                                                 .
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
  1:address:shared:array:character <- new []
  # right editor contains an illegal instruction
  2:address:shared:array:character <- new [get 1234:number, foo:offset]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # check that screen prints error message in red
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
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
    .  errors found (0)                                                                                  .
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
  1:address:shared:array:character <- new []
  # right editor contains an illegal instruction
  2:address:shared:array:character <- new [get 1234:number, foo:offset]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run the code in the editors multiple times
  assume-console [
    press F4
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
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
  1:address:shared:array:character <- new [recipe foo [
  {
    loop
  }
]]
  # right editor contains an instruction
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  {                                               ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .    loop                                          ┊0                                               x.
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
  1:address:shared:array:character <- new [recipe foo [
local-scope
a:number <- next-ingredient
b:number <- next-ingredient
stash [dividing by], b
_, c:number <- divide-with-remainder a, b
reply b
]]
  2:address:shared:array:character <- new [foo 4, 0]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  # screen prints error message
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .local-scope                                       ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .a:number <- next-ingredient                       ┊0                                               x.
    .b:number <- next-ingredient                       ┊foo 4, 0                                         .
    .stash [dividing by], b                            ┊foo: divide by zero in '_, c:number <- divide-wi↩.
    ._, c:number <- divide-with-remainder a, b         ┊th-remainder a, b'                               .
    .reply b                                           ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .]                                                 ┊                                                 .
  ]
  # click on the call in the sandbox
  assume-console [
    left-click 4, 55
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # screen should expand trace
  screen-should-contain [
    .  errors found (0)                                                               run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .local-scope                                       ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .a:number <- next-ingredient                       ┊0                                               x.
    .b:number <- next-ingredient                       ┊foo 4, 0                                         .
    .stash [dividing by], b                            ┊dividing by 0                                    .
    ._, c:number <- divide-with-remainder a, b         ┊foo: divide by zero in '_, c:number <- divide-wi↩.
    .reply b                                           ┊th-remainder a, b'                               .
    .]                                                 ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
  ]
]

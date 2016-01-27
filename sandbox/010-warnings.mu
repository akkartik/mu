## handling malformed programs

container programming-environment-data [
  recipe-warnings:address:shared:array:character
]

# copy code from recipe editor, persist, load into mu, save any warnings
# test-recipes is a hook for testing
recipe! update-recipes env:address:shared:programming-environment-data, screen:address:shared:screen, test-recipes:address:shared:array:character -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  recipe-warnings:address:address:shared:array:character <- get-address *env, recipe-warnings:offset
  {
    break-if test-recipes
    in:address:shared:array:character <- restore [recipes.mu]
    *recipe-warnings <- reload in
  }
  {
    break-unless test-recipes
    *recipe-warnings <- reload test-recipes
  }
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
  data:address:shared:array:character <- get *sandbox, data:offset
  response:address:address:shared:array:character <- get-address *sandbox, response:offset
  warnings:address:address:shared:array:character <- get-address *sandbox, warnings:offset
  trace:address:address:shared:array:character <- get-address *sandbox, trace:offset
  fake-screen:address:address:shared:screen <- get-address *sandbox, screen:offset
  recipe-warnings:address:shared:array:character <- get *env, recipe-warnings:offset
  {
    break-unless recipe-warnings
    *warnings <- copy recipe-warnings
    reply
  }
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
    {
      break-unless env
      recipe-warnings:address:shared:array:character <- get *env, recipe-warnings:offset
      row, screen <- render screen, recipe-warnings, left, right, 1/red, row
    }
    row, screen <- render screen, sandbox-warnings, left, right, 1/red, row
    # don't try to print anything more for this sandbox
    jump +render-sandbox-end:label
  }
]

scenario run-shows-warnings-in-get [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
recipe foo [
  get 123:number, foo:offset
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found                                    .
    .                                                  .
  ]
]

scenario run-updates-status-with-first-erroneous-sandbox [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new []
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    # create invalid sandbox 1
    type [get foo, x:offset]
    press F4
    # create invalid sandbox 0
    type [get foo, x:offset]
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/empty-test-recipes
  ]
  # status line shows that error is in first sandbox
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .get foo, x:offset                                 .
    .expected a container                              .
    .missing type for foo in 'get foo, x:offset'       .
    .first ingredient of 'get' should be a container, ↩.
    .but got foo                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                                                x.
    .get foo, x:offset                                 .
    .expected a container                              .
    .missing type for foo in 'get foo, x:offset'       .
    .first ingredient of 'get' should be a container, ↩.
    .but got foo                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-updates-status-with-first-erroneous-sandbox-2 [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new []
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
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
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/empty-test-recipes
  ]
  # status line shows that error is in second sandbox
  screen-should-contain [
    .  errors found (1)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                                                x.
    .get foo, x:offset                                 .
    .expected a container                              .
    .missing type for foo in 'get foo, x:offset'       .
    .first ingredient of 'get' should be a container, ↩.
    .but got foo                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .2                                                x.
    .get foo, x:offset                                 .
    .expected a container                              .
    .missing type for foo in 'get foo, x:offset'       .
    .first ingredient of 'get' should be a container, ↩.
    .but got foo                                       .
  ]
]

scenario run-hides-warnings-from-past-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new [get foo, x:offset]  # invalid
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4  # generate error
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/empty-test-recipes
  assume-console [
    left-click 3, 10
    press ctrl-k
    type [add 2, 2]  # valid code
    press F4  # update sandbox
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # error should disappear
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-updates-warnings-for-shape-shifting-recipes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # define a shape-shifting recipe with an error
  1:address:shared:array:character <- new [recipe foo x:_elem -> z:_elem [
local-scope
load-ingredients
z <- add x, [a]
]]
  2:address:shared:array:character <- new [foo 2]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo 2                                             .
    .foo_2: 'add' requires number ingredients, but got↩.
    . [a]                                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # now rerun everything
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  # error should remain unchanged
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo 2                                             .
    .foo_2: 'add' requires number ingredients, but got↩.
    . [a]                                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-avoids-spurious-warnings-on-reloading-shape-shifting-recipes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # overload a well-known shape-shifting recipe
  1:address:shared:array:character <- new [recipe length l:address:shared:list:_elem -> n:number [
]]
  # call code that uses other variants of it, but not it itself
  2:address:shared:array:character <- new [x:address:shared:list:number <- copy 0
to-text x]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  # run it once
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  # no errors anywhere on screen (can't check anything else, since to-text will return an address)
  screen-should-contain-in-color 1/red, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                             <-                   .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # rerun everything
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  # still no errors
  screen-should-contain-in-color 1/red, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                             <-                   .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
  ]
]

scenario run-shows-missing-type-warnings [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
recipe foo [
  x <- copy 0
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-shows-unbalanced-bracket-warnings [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # recipe is incomplete (unbalanced '[')
  1:address:shared:array:character <- new [ 
recipe foo «
  x <- copy 0
]
  replace 1:address:shared:array:character, 171/«, 91  # '['
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-shows-get-on-non-container-warnings [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
recipe foo [
  x:address:shared:point <- new point:type
  get x:address:shared:point, 1:offset
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-shows-non-literal-get-argument-warnings [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
recipe foo [
  x:number <- copy 0
  y:address:shared:point <- new point:type
  get *y:address:shared:point, x:number
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-shows-warnings-everytime [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # try to run a file with an error
  1:address:shared:array:character <- new [ 
recipe foo [
  x:number <- copy y:number
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # rerun the file, check for the same error
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    # TODO: make this more specific
    .  errors found                 run (F4)           .
    .foo                                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-instruction-and-print-warnings [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  1:address:shared:array:character <- new [get 1:address:shared:point, 1:offset]
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .get 1:address:shared:point, 1:offset              .
    .first ingredient of 'get' should be a container, ↩.
    .but got 1:address:shared:point                    .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found (0)                                .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .first ingredient of 'get' should be a container,  .
    .but got 1:address:shared:point                    .
    .                                                  .
    .                                                  .
  ]
]

# TODO: print warnings in file even if you can't run a sandbox

scenario run-instruction-and-print-warnings-only-once [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  # editor contains an illegal instruction
  1:address:shared:array:character <- new [get 1234:number, foo:offset]
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  # run the code in the editors multiple times
  assume-console [
    press F4
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .get 1234:number, foo:offset                       .
    .unknown element foo in container number           .
    .first ingredient of 'get' should be a container, ↩.
    .but got 1234:number                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario sandbox-can-handle-infinite-loop [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # editor contains an infinite loop
  1:address:shared:array:character <- new [{
loop
}]
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .{                                                 .
    .loop                                              .
    .}                                                 .
    .took too long!                                    .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario sandbox-with-warnings-shows-trace [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
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
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  # run
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  # screen prints error message
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo 4, 0                                          .
    .foo: divide by zero in '_, c:number <- divide-wit↩.
    .h-remainder a, b'                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # click on the call in the sandbox
  assume-console [
    left-click 4, 15
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  # screen should expand trace
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo 4, 0                                          .
    .dividing by 0                                     .
    .foo: divide by zero in '_, c:number <- divide-wit↩.
    .h-remainder a, b'                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

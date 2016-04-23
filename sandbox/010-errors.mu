## handling malformed programs

container programming-environment-data [
  recipe-errors:address:shared:array:character
]

# copy code from recipe editor, persist, load into mu, save any errors
# test-recipes is a hook for testing
def! update-recipes env:address:shared:programming-environment-data, screen:address:shared:screen, test-recipes:address:shared:array:character -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  {
    break-if test-recipes
    recipe-errors:address:shared:array:character <- restore [recipes.mu]
  }
  {
    break-unless test-recipes
    recipe-errors <- reload test-recipes
  }
  *env <- put *env, recipe-errors:offset, recipe-errors
  # if recipe editor has errors, stop
  {
    break-unless recipe-errors
    update-status screen, [errors found     ], 1/red
    errors-found? <- copy 1/true
    return
  }
  errors-found? <- copy 0/false
]

before <render-components-end> [
  trace 11, [app], [render status]
  recipe-errors:address:shared:array:character <- get *env, recipe-errors:offset
  {
    break-unless recipe-errors
    update-status screen, [errors found     ], 1/red
  }
]

container programming-environment-data [
  error-index:number  # index of first sandbox with an error (or -1 if none)
]

after <programming-environment-initialization> [
  *result <- put *result, error-index:offset, -1
]

after <run-sandboxes-begin> [
  *env <- put *env, error-index:offset, -1
]

before <run-sandboxes-end> [
  {
    error-index:number <- get *env, error-index:offset
    sandboxes-completed-successfully?:boolean <- equal error-index, -1
    break-if sandboxes-completed-successfully?
    errors-found? <- copy 1/true
  }
]

before <render-components-end> [
  {
    break-if recipe-errors
    error-index:number <- get *env, error-index:offset
    sandboxes-completed-successfully?:boolean <- equal error-index, -1
    break-if sandboxes-completed-successfully?
    error-index-text:address:shared:array:character <- to-text error-index
    status:address:shared:array:character <- interpolate [errors found (_)    ], error-index-text
    update-status screen, status, 1/red
  }
]

container sandbox-data [
  errors:address:shared:array:character
]

def! update-sandbox sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data, idx:number -> sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  {
    recipe-errors:address:shared:array:character <- get *env, recipe-errors:offset
    break-unless recipe-errors
    *sandbox <- put *sandbox, errors:offset, recipe-errors
    return
  }
  data:address:shared:array:character <- get *sandbox, data:offset
  response:address:shared:array:character, errors:address:shared:array:character, fake-screen:address:shared:screen, trace:address:shared:array:character, completed?:boolean <- run-interactive data
  *sandbox <- put *sandbox, response:offset, response
  *sandbox <- put *sandbox, errors:offset, errors
  *sandbox <- put *sandbox, screen:offset, fake-screen
  *sandbox <- put *sandbox, trace:offset, trace
  {
    break-if errors
    break-if completed?:boolean
    errors <- new [took too long!
]
    *sandbox <- put *sandbox, errors:offset, errors
  }
  {
    break-unless errors
    error-index:number <- get *env, error-index:offset
    error-not-set?:boolean <- equal error-index, -1
    break-unless error-not-set?
    *env <- put *env, error-index:offset, idx
  }
]

# make sure we render any trace
after <render-sandbox-trace-done> [
  {
    sandbox-errors:address:shared:array:character <- get *sandbox, errors:offset
    break-unless sandbox-errors
    *sandbox <- put *sandbox, response-starting-row-on-screen:offset, 0  # no response
    {
      break-unless env
      recipe-errors:address:shared:array:character <- get *env, recipe-errors:offset
      row, screen <- render screen, recipe-errors, left, right, 1/red, row
    }
    row, screen <- render screen, sandbox-errors, left, right, 1/red, row
    # don't try to print anything more for this sandbox
    jump +render-sandbox-end:label
  }
]

scenario run-shows-errors-in-get [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
def foo [
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
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .foo: unknown element foo in container number      .
    .foo: first ingredient of 'get' should be a contai↩.
    .ner, but got 123:number                           .
    .foo: unknown element foo in container number      .
    .foo: first ingredient of 'get' should be a contai↩.
    .ner, but got 123:number                           .
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
  ]
]

scenario run-hides-errors-from-past-sandboxes [
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

scenario run-updates-errors-for-shape-shifting-recipes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # define a shape-shifting recipe with an error
  1:address:shared:array:character <- new [recipe foo x:_elem -> z:_elem [
local-scope
load-ingredients
y:address:number <- copy 0
z <- add x, y
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
    . y                                                .
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
    .foo_3: 'add' requires number ingredients, but got↩.
    . y                                                .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-avoids-spurious-errors-on-reloading-shape-shifting-recipes [
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

scenario run-shows-missing-type-errors [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
def foo [
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
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .foo: missing type for x in 'x <- copy 0'          .
    .foo: can't copy 0 to x; types don't match         .
    .foo: missing type for x in 'x <- copy 0'          .
    .foo: can't copy 0 to x; types don't match         .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-shows-unbalanced-bracket-errors [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # recipe is incomplete (unbalanced '[')
  1:address:shared:array:character <- new [ 
def foo «
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
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .9: unbalanced '\\\[' for recipe                      .
    .9: unbalanced '\\\[' for recipe                      .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario run-shows-get-on-non-container-errors [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
def foo [
  local-scope
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
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .foo: first ingredient of 'get' should be a contai↩.
    .ner, but got x:address:shared:point               .
  ]
]

scenario run-shows-non-literal-get-argument-errors [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  1:address:shared:array:character <- new [ 
def foo [
  local-scope
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
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .foo: second ingredient of 'get' should have type ↩.
    .'offset', but got x:number                        .
  ]
]

scenario run-shows-errors-everytime [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # try to run a file with an error
  1:address:shared:array:character <- new [ 
def foo [
  local-scope
  x:number <- copy y:number
]]
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .foo: use before set: y                            .
  ]
  # rerun the file, check for the same error
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .foo: use before set: y                            .
  ]
]

scenario run-instruction-and-print-errors [
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

scenario run-instruction-and-print-errors-only-once [
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

scenario sandbox-with-errors-shows-trace [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # generate a stash and a error
  1:address:shared:array:character <- new [recipe foo [
local-scope
a:number <- next-ingredient
b:number <- next-ingredient
stash [dividing by], b
_, c:number <- divide-with-remainder a, b
return b
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

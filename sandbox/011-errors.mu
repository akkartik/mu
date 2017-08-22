## handling malformed programs

container environment [
  recipe-errors:text
]

# load code from disk, save any errors
def! update-recipes env:&:environment, resources:&:resources, screen:&:screen -> errors-found?:bool, env:&:environment, screen:&:screen [
  local-scope
  load-ingredients
  in:text <- slurp resources, [lesson/recipes.mu]
  recipe-errors:text <- reload in
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

before <end-render-components> [
  trace 11, [app], [render status]
  recipe-errors:text <- get *env, recipe-errors:offset
  {
    break-unless recipe-errors
    update-status screen, [errors found     ], 1/red
  }
]

container environment [
  error-index:num  # index of first sandbox with an error (or -1 if none)
]

after <programming-environment-initialization> [
  *result <- put *result, error-index:offset, -1
]

after <begin-run-sandboxes> [
  *env <- put *env, error-index:offset, -1
]

before <end-run-sandboxes> [
  {
    error-index:num <- get *env, error-index:offset
    sandboxes-completed-successfully?:bool <- equal error-index, -1
    break-if sandboxes-completed-successfully?
    errors-found? <- copy 1/true
  }
]

before <end-render-components> [
  {
    break-if recipe-errors
    error-index:num <- get *env, error-index:offset
    sandboxes-completed-successfully?:bool <- equal error-index, -1
    break-if sandboxes-completed-successfully?
    error-index-text:text <- to-text error-index
    status:text <- interpolate [errors found (_)    ], error-index-text
    update-status screen, status, 1/red
  }
]

container sandbox [
  errors:text
]

def! update-sandbox sandbox:&:sandbox, env:&:environment, idx:num -> sandbox:&:sandbox, env:&:environment [
  local-scope
  load-ingredients
  {
    recipe-errors:text <- get *env, recipe-errors:offset
    break-unless recipe-errors
    *sandbox <- put *sandbox, errors:offset, recipe-errors
    return
  }
  data:text <- get *sandbox, data:offset
  response:text, errors:text, fake-screen:&:screen, trace:text, completed?:bool <- run-sandboxed data
  *sandbox <- put *sandbox, response:offset, response
  *sandbox <- put *sandbox, errors:offset, errors
  *sandbox <- put *sandbox, screen:offset, fake-screen
  *sandbox <- put *sandbox, trace:offset, trace
  {
    break-if errors
    break-if completed?
    errors <- new [took too long!
]
    *sandbox <- put *sandbox, errors:offset, errors
  }
  {
    break-unless errors
    error-index:num <- get *env, error-index:offset
    error-not-set?:bool <- equal error-index, -1
    break-unless error-not-set?
    *env <- put *env, error-index:offset, idx
  }
]

# make sure we render any trace
after <render-sandbox-trace-done> [
  {
    sandbox-errors:text <- get *sandbox, errors:offset
    break-unless sandbox-errors
    *sandbox <- put *sandbox, response-starting-row-on-screen:offset, 0  # no response
    {
      break-unless env
      recipe-errors:text <- get *env, recipe-errors:offset
      row, screen <- render-text screen, recipe-errors, left, right, 1/red, row
    }
    row, screen <- render-text screen, sandbox-errors, left, right, 1/red, row
    # don't try to print anything more for this sandbox
    jump +render-sandbox-end
  }
]

scenario run-shows-errors-in-get [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  get 123:num, foo:offset|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  screen-should-contain [
    .                               run (F4)           .
    .foo                                               .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .foo: unknown element 'foo' in container 'number'  .
    .foo: first ingredient of 'get' should be a contai↩.
    .ner, but got '123:num'                            .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found                                    .
    .                                                  .
  ]
]

scenario run-updates-status-with-first-erroneous-sandbox [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
  assume-console [
    # create invalid sandbox 1
    type [get foo, x:offset]
    press F4
    # create invalid sandbox 0
    type [get foo, x:offset]
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # status line shows that error is in first sandbox
  screen-should-contain [
    .  errors found (0)             run (F4)           .
  ]
]

scenario run-updates-status-with-first-erroneous-sandbox-2 [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
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
    event-loop screen, console, env, resources
  ]
  # status line shows that error is in second sandbox
  screen-should-contain [
    .  errors found (1)             run (F4)           .
  ]
]

scenario run-hides-errors-from-past-sandboxes [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [get foo, x:offset]  # invalid
  render-all screen, env, render
  assume-console [
    press F4  # generate error
  ]
  event-loop screen, console, env, resources
  assume-console [
    left-click 3, 10
    press ctrl-k
    type [add 2, 2]  # valid code
    press F4  # update sandbox
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # error should disappear
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario run-updates-errors-for-shape-shifting-recipes [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # define a shape-shifting recipe with an error
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo x:_elem -> z:_elem [|
      |  local-scope|
      |  load-ingredients|
      |  y:&:num <- copy 0|
      |  z <- add x, y|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo 2]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo 2                                             .
    .foo_2: 'add' requires number ingredients, but got↩.
    . 'y'                                              .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  # now rerun everything
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # error should remain unchanged
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo 2                                             .
    .foo_3: 'add' requires number ingredients, but got↩.
    . 'y'                                              .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario run-avoids-spurious-errors-on-reloading-shape-shifting-recipes [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # overload a well-known shape-shifting recipe
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe length l:&:list:_elem -> n:num [|
      |]|
    ]
  ]
  # call code that uses other variants of it, but not it itself
  test-sandbox:text <- new [x:&:list:num <- copy 0
to-text x]
  env:&:environment <- new-programming-environment resources, screen, test-sandbox
  render-all screen, env, render
  # run it once
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  # no errors anywhere on screen (can't check anything else, since to-text will return an address)
  screen-should-contain-in-color 1/red, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .             <-                                   .
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
    event-loop screen, console, env, resources
  ]
  # still no errors
  screen-should-contain-in-color 1/red, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .             <-                                   .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
  ]
]

scenario run-shows-missing-type-errors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  x <- copy 0|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .foo: missing type for 'x' in 'x <- copy 0'        .
  ]
]

scenario run-shows-unbalanced-bracket-errors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # recipe is incomplete (unbalanced '[')
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo \\\[|
      |  x <- copy 0|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .9: unbalanced '\\[' for recipe                      .
    .9: unbalanced '\\[' for recipe                      .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario run-shows-get-on-non-container-errors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  local-scope|
      |  x:&:point <- new point:type|
      |  get x:&:point, 1:offset|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .foo: first ingredient of 'get' should be a contai↩.
    .ner, but got 'x:&:point'                          .
  ]
]

scenario run-shows-non-literal-get-argument-errors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  local-scope|
      |  x:num <- copy 0|
      |  y:&:point <- new point:type|
      |  get *y:&:point, x:num|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .foo: second ingredient of 'get' should have type ↩.
    .'offset', but got 'x:num'                         .
  ]
]

scenario run-shows-errors-every-time [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # try to run a file with an error
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  local-scope|
      |  x:num <- copy y:num|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .foo: tried to read ingredient 'y' in 'x:num <- co↩.
    .py y:num' but it hasn't been written to yet       .
  ]
  # rerun the file, check for the same error
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found                 run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo                                               .
    .foo: tried to read ingredient 'y' in 'x:num <- co↩.
    .py y:num' but it hasn't been written to yet       .
  ]
]

scenario run-instruction-and-print-errors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  assume-resources [
  ]
  # editor contains an illegal instruction
  env:&:environment <- new-programming-environment resources, screen, [get 1:&:point, 1:offset]
  render-all screen, env, render
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # check that screen prints error message in red
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .get 1:&:point, 1:offset                           .
    .first ingredient of 'get' should be a container, ↩.
    .but got '1:&:point'                               .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  screen-should-contain-in-color 1/red, [
    .  errors found (0)                                .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .first ingredient of 'get' should be a container,  .
    .but got '1:&:point'                               .
    .                                                  .
    .                                                  .
  ]
]

scenario run-instruction-and-print-errors-only-once [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  assume-resources [
  ]
  # editor contains an illegal instruction
  env:&:environment <- new-programming-environment resources, screen, [get 1234:num, foo:offset]
  render-all screen, env, render
  # run the code in the editors multiple times
  assume-console [
    press F4
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .get 1234:num, foo:offset                          .
    .unknown element 'foo' in container 'number'       .
    .first ingredient of 'get' should be a container, ↩.
    .but got '1234:num'                                .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario sandbox-can-handle-infinite-loop [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  assume-resources [
  ]
  # editor contains an infinite loop
  test-sandbox:text <- new [{
loop
}]
  env:&:environment <- new-programming-environment resources, screen, test-sandbox
  render-all screen, env, render
  # run the sandbox
  assume-console [
    press F4
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .{                                                 .
    .loop                                              .
    .}                                                 .
    .took too long!                                    .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario sandbox-with-errors-shows-trace [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # generate a stash and a error
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  local-scope|
      |  a:num <- next-ingredient|
      |  b:num <- next-ingredient|
      |  stash [dividing by], b|
      |  _, c:num <- divide-with-remainder a, b|
      |  reply b|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo 4, 0]
  render-all screen, env, render
  # run
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  # screen prints error message
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo 4, 0                                          .
    .foo: divide by zero in '_, c:num <- divide-with-r↩.
    .emainder a, b'                                    .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  # click on the call in the sandbox
  assume-console [
    left-click 4, 15
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # screen should expand trace
  screen-should-contain [
    .  errors found (0)             run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .foo 4, 0                                          .
    .dividing by 0                                     .
    .14 instructions run                               .
    .foo: divide by zero in '_, c:num <- divide-with-r↩.
    .emainder a, b'                                    .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

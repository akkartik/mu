## handling malformed programs

container programming-environment-data [
  recipe-warnings:address:array:character
]

# copy code from recipe editor, persist, load into mu, save any warnings
recipe! update-recipes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  screen:address <- next-ingredient
  in:address:array:character <- restore [recipes.mu]
  recipe-warnings:address:address:array:character <- get-address *env, recipe-warnings:offset
  *recipe-warnings <- reload in
  # if recipe editor has errors, stop
  {
    break-unless *recipe-warnings
    status:address:array:character <- new [errors found]
    update-status screen, status, 1/red
    reply 1/errors-found, env/same-as-ingredient:0, screen/same-as-ingredient:1
  }
  reply 0/no-errors-found, env/same-as-ingredient:0, screen/same-as-ingredient:1
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

container sandbox-data [
  warnings:address:array:character
]

recipe! update-sandbox [
  local-scope
  sandbox:address:sandbox-data <- next-ingredient
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

scenario run-instruction-and-print-warnings [
  $close-trace  # trace too long
  assume-screen 50/width, 15/height
  1:address:array:character <- new [get 1:address:point, 1:offset]
  2:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .get 1:address:point, 1:offset                     .
    .interactive: first ingredient of 'get' should be ↩.
    .a container, but got 1:address:point              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  screen-should-contain-in-color 1/red, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .interactive: first ingredient of 'get' should be  .
    .a container, but got 1:address:point              .
    .                                                  .
    .                                                  .
  ]
]

scenario run-instruction-and-print-warnings-only-once [
  $close-trace  # trace too long
  assume-screen 50/width, 10/height
  # editor contains an illegal instruction
  1:address:array:character <- new [get 1234:number, foo:offset]
  2:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character
  # run the code in the editors multiple times
  assume-console [
    press F4
    press F4
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
  ]
  # check that screen prints error message just once
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .get 1234:number, foo:offset                       .
    .unknown element foo in container number           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario sandbox-can-handle-infinite-loop [
  $close-trace  # trace too long
  assume-screen 50/width, 20/height
  # editor contains an infinite loop
  1:address:array:character <- new [{
loop
}]
  2:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .{                                                 .
    .loop                                              .
    .}                                                 .
    .took too long!                                    .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario sandbox-with-warnings-shows-trace [
  $close-trace  # trace too long
  assume-screen 50/width, 10/height
  # generate a stash and a warning
  1:address:array:character <- new [stash [abc]
foo 4, 0]
  2:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character
  # run
  assume-console [
    press F4
  ]
  event-loop screen:address, console:address, 2:address:programming-environment-data
  # screen prints error message
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .stash [abc]                                       .
    .foo 4, 0                                          .
    .interactive: undefined operation in 'foo 4, 0'    .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # click on the call in the sandbox
  assume-console [
    left-click 4, 25
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
  ]
  # screen should expand trace
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .stash [abc]                                       .
    .foo 4, 0                                          .
    .abc                                               .
    .interactive: undefined operation in 'foo 4, 0'    .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

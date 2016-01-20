## handling malformed programs

container programming-environment-data [
  recipe-warnings:address:shared:array:character
]

# copy code from recipe editor, persist, load into mu, save any warnings
recipe! update-recipes env:address:shared:programming-environment-data, screen:address:shared:screen -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  in:address:shared:array:character <- restore [recipes.mu]
  recipe-warnings:address:address:shared:array:character <- get-address *env, recipe-warnings:offset
  *recipe-warnings <- reload in
  # if recipe editor has errors, stop
  {
    break-unless *recipe-warnings
    status:address:shared:array:character <- new [errors found]
    update-status screen, status, 1/red
  }
  errors-found? <- copy 0/false
]

before <render-components-end> [
  trace 11, [app], [render status]
  recipe-warnings:address:shared:array:character <- get *env, recipe-warnings:offset
  {
    break-unless recipe-warnings
    status:address:shared:array:character <- new [errors found]
    update-status screen, status, 1/red
  }
]

container sandbox-data [
  warnings:address:shared:array:character
]

recipe! update-sandbox sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data -> sandbox:address:shared:sandbox-data [
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
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .get 1:address:shared:point, 1:offset              .
    .first ingredient of 'get' should be a container, ↩.
    .but got 1:address:shared:point                    .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  screen-should-contain-in-color 1/red, [
    .                                                  .
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

# todo: print warnings in file even if you can't run a sandbox

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
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
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

# todo: scenario sandbox-with-warnings-shows-trace from edit/

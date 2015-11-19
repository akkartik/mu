## deleting sandboxes

scenario deleting-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  1:address:array:character <- new []
  2:address:array:character <- new []
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  # run a few commands
  assume-console [
    left-click 1, 80
    type [divide-with-remainder 11, 3]
    press F4
    type [add 2, 2]
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # delete second sandbox
  assume-console [
    left-click 7, 99
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
  # delete first sandbox
  assume-console [
    left-click 3, 99
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
]

after <global-touch> [
  # on a sandbox delete icon? process delete
  {
    was-delete?:boolean <- delete-sandbox *t, env
    break-unless was-delete?
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    show-screen screen
    loop +next-event:label
  }
]

recipe delete-sandbox t:touch-event, env:address:programming-environment-data -> was-delete?:boolean, env:address:programming-environment-data [
  local-scope
  load-ingredients
  click-column:number <- get t, column:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  right:number <- get *current-sandbox, right:offset
  at-right?:boolean <- equal click-column, right
  reply-unless at-right?, 0/false
  click-row:number <- get t, row:offset
  prev:address:address:sandbox-data <- get-address *env, sandbox:offset
  curr:address:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr
    # more sandboxes to check
    {
      target-row:number <- get *curr, starting-row-on-screen:offset
      delete-curr?:boolean <- equal target-row, click-row
      break-unless delete-curr?
      # delete this sandbox, rerender and stop
      *prev <- get *curr, next-sandbox:offset
      reply 1/true
    }
    prev <- get-address *curr, next-sandbox:offset
    curr <- get *curr, next-sandbox:offset
    loop
  }
  reply 0/false
]

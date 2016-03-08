## deleting sandboxes

scenario deleting-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  1:address:shared:array:character <- new []
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  # run a few commands
  assume-console [
    left-click 1, 0
    type [divide-with-remainder 11, 3]
    press F4
    type [add 2, 2]
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                                                x.
    .divide-with-remainder 11, 3                       .
    .3                                                 .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # delete second sandbox
  assume-console [
    left-click 7, 49
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
  ]
  # delete first sandbox
  assume-console [
    left-click 3, 49
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
  ]
]

after <global-touch> [
  # on a sandbox delete icon? process delete
  {
    was-delete?:boolean <- delete-sandbox *t, env
    break-unless was-delete?
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, current-sandbox, env
    show-screen screen
    loop +next-event:label
  }
]

def delete-sandbox t:touch-event, env:address:shared:programming-environment-data -> was-delete?:boolean, env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  click-column:number <- get t, column:offset
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  right:number <- get *current-sandbox, right:offset
  at-right?:boolean <- equal click-column, right
  return-unless at-right?, 0/false
  click-row:number <- get t, row:offset
  prev:address:address:shared:sandbox-data <- get-address *env, sandbox:offset
  curr:address:shared:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr
    # more sandboxes to check
    {
      target-row:number <- get *curr, starting-row-on-screen:offset
      delete-curr?:boolean <- equal target-row, click-row
      break-unless delete-curr?
      # delete this sandbox
      *prev <- get *curr, next-sandbox:offset
      # update sandbox count
      sandbox-count:address:number <- get-address *env, number-of-sandboxes:offset
      *sandbox-count <- subtract *sandbox-count, 1
      # if it's the last sandbox and if it was the only sandbox rendered, reset scroll
      {
        break-if *prev
        render-from:address:number <- get-address *env, render-from:offset
        reset-scroll?:boolean <- equal *render-from, *sandbox-count
        break-unless reset-scroll?
        *render-from <- copy -1
      }
      return 1/true  # force rerender
    }
    prev <- get-address *curr, next-sandbox:offset
    curr <- get *curr, next-sandbox:offset
    loop
  }
  return 0/false
]

scenario deleting-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:shared:array:character <- new []
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  render-all screen, 2:address:shared:programming-environment-data
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press down-arrow
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  screen-should-contain [
    .                              .  # menu
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 1, 1                      .
    .2                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                            x.
    .add 2, 2                      .
    .4                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
  ]
  # delete the second sandbox
  assume-console [
    left-click 6, 29
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 1, 1                      .
    .2                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              .
  ]
]

scenario deleting-top-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:shared:array:character <- new []
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  render-all screen, 2:address:shared:programming-environment-data
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press down-arrow
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  screen-should-contain [
    .                              .  # menu
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 1, 1                      .
    .2                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                            x.
    .add 2, 2                      .
    .4                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
  ]
  # delete the second sandbox
  assume-console [
    left-click 2, 29
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 2, 2                      .
    .4                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              .
  ]
]

scenario deleting-final-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:shared:array:character <- new []
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  render-all screen, 2:address:shared:programming-environment-data
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press down-arrow
    press down-arrow
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  screen-should-contain [
    .                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                            x.
    .add 2, 2                      .
    .4                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              .
  ]
  # delete the second sandbox
  assume-console [
    left-click 2, 29
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  # implicitly scroll up to first sandbox
  screen-should-contain [
    .                              .
    .                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 1, 1                      .
    .2                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              .
  ]
]

scenario deleting-updates-sandbox-count [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:shared:array:character <- new []
  2:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character
  render-all screen, 2:address:shared:programming-environment-data
  # create 2 sandboxes
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  screen-should-contain [
    .                              .
    .                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 1, 1                      .
    .2                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1                            x.
    .add 2, 2                      .
    .4                             .
  ]
  # delete the second sandbox, then try to scroll down twice
  assume-console [
    left-click 3, 29
    press down-arrow
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:programming-environment-data
  ]
  # shouldn't go past last sandbox
  screen-should-contain [
    .                              .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                            x.
    .add 2, 2                      .
    .4                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              .
  ]
]

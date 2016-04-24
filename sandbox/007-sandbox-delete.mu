## deleting sandboxes

scenario deleting-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  # run a few commands
  assume-console [
    left-click 1, 0
    type [divide-with-remainder 11, 3]
    press F4
    type [add 2, 2]
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    was-delete?:boolean <- delete-sandbox t, env
    break-unless was-delete?
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, current-sandbox, env
    show-screen screen
    loop +next-event:label
  }
]

def delete-sandbox t:touch-event, env:address:programming-environment-data -> was-delete?:boolean, env:address:programming-environment-data [
  local-scope
  load-ingredients
  click-column:number <- get t, column:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  right:number <- get *current-sandbox, right:offset
  at-right?:boolean <- equal click-column, right
  return-unless at-right?, 0/false
  click-row:number <- get t, row:offset
  {
    first:address:sandbox-data <- get *env, sandbox:offset
    reply-unless first, 0/false
    target-row:number <- get *first, starting-row-on-screen:offset
    delete-first?:boolean <- equal target-row, click-row
    break-unless delete-first?
    new-first:address:sandbox-data <- get *first, next-sandbox:offset
    *env <- put *env, sandbox:offset, new-first
    env <- fixup-delete env, new-first
    return 1/true  # force rerender
  }
  prev:address:sandbox-data <- get *env, sandbox:offset
  assert prev, [failed to find any sandboxes!]
  curr:address:sandbox-data <- get *prev, next-sandbox:offset
  {
    break-unless curr
    # more sandboxes to check
    {
      target-row:number <- get *curr, starting-row-on-screen:offset
      delete-curr?:boolean <- equal target-row, click-row
      break-unless delete-curr?
      # delete this sandbox
      next:address:sandbox-data <- get *curr, next-sandbox:offset
      *prev <- put *prev, next-sandbox:offset, next
      env <- fixup-delete env, next
      return 1/true  # force rerender
    }
    prev <- copy curr
    curr <- get *curr, next-sandbox:offset
    loop
  }
  return 0/false
]

def fixup-delete env:address:programming-environment-data, next:address:sandbox-data -> env:address:programming-environment-data [
  local-scope
  load-ingredients
  # update sandbox count
  sandbox-count:number <- get *env, number-of-sandboxes:offset
  sandbox-count <- subtract sandbox-count, 1
  *env <- put *env, number-of-sandboxes:offset, sandbox-count
  {
    break-if next
    # deleted sandbox was last
    render-from:number <- get *env, render-from:offset
    reset-scroll?:boolean <- equal render-from, sandbox-count
    break-unless reset-scroll?
    # deleted sandbox was only sandbox rendered, so reset scroll
    *env <- put *env, render-from:offset, -1
  }
]

scenario deleting-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press down-arrow
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press down-arrow
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data
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
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data
  # create 2 sandboxes
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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

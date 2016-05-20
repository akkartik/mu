## deleting sandboxes

scenario deleting-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  # run a few commands
  assume-console [
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
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .divide-with-remainder 11, 3                       .
    .3                                                 .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # delete second sandbox by clicking on left edge of 'delete' button
  assume-console [
    left-click 7, 34
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # delete first sandbox by clicking at right edge of 'delete' button
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
  ]
]

after <global-touch> [
  # support 'delete' button
  {
    delete?:boolean <- should-attempt-delete? click-row, click-column, env
    break-unless delete?
    delete?, env <- try-delete-sandbox click-row, env
    break-unless delete?
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, current-sandbox, env
    show-screen screen
    loop +next-event:label
  }
]

# some preconditions for attempting to delete a sandbox
def should-attempt-delete? click-row:number, click-column:number, env:address:programming-environment-data -> result:boolean [
  local-scope
  load-ingredients
  # are we below the sandbox editor?
  click-sandbox-area?:boolean <- click-on-sandbox-area? click-row, env
  reply-unless click-sandbox-area?, 0/false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:address:editor-data <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:number <- get *first-sandbox, left:offset
  sandbox-right-margin:number <- get *first-sandbox, right:offset
  _, _, _, _, delete-button-left:number <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  result <- within-range? click-column, delete-button-left, sandbox-right-margin
]

def try-delete-sandbox click-row:number, env:address:programming-environment-data -> clicked-on-delete-button?:boolean, env:address:programming-environment-data [
  local-scope
  load-ingredients
  # identify the sandbox to delete, if the click was actually on the 'delete' button
  sandbox:address:sandbox-data <- find-sandbox env, click-row
  return-unless sandbox, 0/false
  clicked-on-delete-button? <- copy 1/true
  env <- delete-sandbox env, sandbox
]

def delete-sandbox env:address:programming-environment-data, sandbox:address:sandbox-data -> env:address:programming-environment-data [
  local-scope
  load-ingredients
  curr-sandbox:address:sandbox-data <- get *env, sandbox:offset
  first-sandbox?:boolean <- equal curr-sandbox, sandbox
  {
    # first sandbox? pop
    break-unless first-sandbox?
    next-sandbox:address:sandbox-data <- get *curr-sandbox, next-sandbox:offset
    *env <- put *env, sandbox:offset, next-sandbox
  }
  {
    # not first sandbox?
    break-if first-sandbox?
    prev-sandbox:address:sandbox-data <- copy curr-sandbox
    curr-sandbox <- get *curr-sandbox, next-sandbox:offset
    {
      assert curr-sandbox, [sandbox not found! something is wrong.]
      found?:boolean <- equal curr-sandbox, sandbox
      break-if found?
      prev-sandbox <- copy curr-sandbox
      curr-sandbox <- get *curr-sandbox, next-sandbox:offset
      loop
    }
    # snip sandbox out of its list
    next-sandbox:address:sandbox-data <- get *curr-sandbox, next-sandbox:offset
    *prev-sandbox <- put *prev-sandbox, next-sandbox:offset, next-sandbox
  }
  # update sandbox count
  sandbox-count:number <- get *env, number-of-sandboxes:offset
  sandbox-count <- subtract sandbox-count, 1
  *env <- put *env, number-of-sandboxes:offset, sandbox-count
  # reset scroll if deleted sandbox was last
  {
    break-if next-sandbox
    render-from:number <- get *env, render-from:offset
    reset-scroll?:boolean <- equal render-from, sandbox-count
    break-unless reset-scroll?
    *env <- put *env, render-from:offset, -1
  }
]

scenario deleting-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
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
    press page-down
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
  ]
  # delete the second sandbox
  assume-console [
    left-click 6, 34
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario deleting-top-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
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
    press page-down
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
  ]
  # delete the second sandbox
  assume-console [
    left-click 2, 34
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario deleting-final-sandbox-after-scroll [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
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
    press page-down
    press page-down
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # delete the second sandbox
  assume-console [
    left-click 2, 34
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # implicitly scroll up to first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario deleting-updates-sandbox-count [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
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
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
  ]
  # delete the second sandbox, then try to scroll down twice
  assume-console [
    left-click 3, 34
    press page-down
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # shouldn't go past last sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

## deleting sandboxes

scenario deleting-sandboxes [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
  # run a few commands
  assume-console [
    type [divide-with-remainder 11, 3]
    press F4
    type [add 2, 2]
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
    .1   edit           copy           delete          .
    .divide-with-remainder 11, 3                       .
    .3                                                 .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  # delete second sandbox by clicking on left edge of 'delete' button
  assume-console [
    left-click 7, 34
  ]
  run [
    event-loop screen, console, env, resources
  ]
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
  # delete first sandbox by clicking at right edge of 'delete' button
  assume-console [
    left-click 3, 49
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

after <global-touch> [
  # support 'delete' button
  {
    delete?:bool <- should-attempt-delete? click-row, click-column, env
    break-unless delete?
    delete?, env <- try-delete-sandbox click-row, env
    break-unless delete?
    screen <- render-sandbox-side screen, env, render
    screen <- update-cursor screen, current-sandbox, env
    loop +next-event
  }
]

# some preconditions for attempting to delete a sandbox
def should-attempt-delete? click-row:num, click-column:num, env:&:environment -> result:bool [
  local-scope
  load-ingredients
  # are we below the sandbox editor?
  click-sandbox-area?:bool <- click-on-sandbox-area? click-row, env
  return-unless click-sandbox-area?, 0/false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:&:editor <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:num <- get *first-sandbox, left:offset
  sandbox-right-margin:num <- get *first-sandbox, right:offset
  _, _, _, _, delete-button-left:num <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  result <- within-range? click-column, delete-button-left, sandbox-right-margin
]

def try-delete-sandbox click-row:num, env:&:environment -> clicked-on-delete-button?:bool, env:&:environment [
  local-scope
  load-ingredients
  # identify the sandbox to delete, if the click was actually on the 'delete' button
  sandbox:&:sandbox <- find-sandbox env, click-row
  return-unless sandbox, 0/false
  clicked-on-delete-button? <- copy 1/true
  env <- delete-sandbox env, sandbox
]

def delete-sandbox env:&:environment, sandbox:&:sandbox -> env:&:environment [
  local-scope
  load-ingredients
  curr-sandbox:&:sandbox <- get *env, sandbox:offset
  first-sandbox?:bool <- equal curr-sandbox, sandbox
  {
    # first sandbox? pop
    break-unless first-sandbox?
    next-sandbox:&:sandbox <- get *curr-sandbox, next-sandbox:offset
    *env <- put *env, sandbox:offset, next-sandbox
  }
  {
    # not first sandbox?
    break-if first-sandbox?
    prev-sandbox:&:sandbox <- copy curr-sandbox
    curr-sandbox <- get *curr-sandbox, next-sandbox:offset
    {
      assert curr-sandbox, [sandbox not found! something is wrong.]
      found?:bool <- equal curr-sandbox, sandbox
      break-if found?
      prev-sandbox <- copy curr-sandbox
      curr-sandbox <- get *curr-sandbox, next-sandbox:offset
      loop
    }
    # snip sandbox out of its list
    next-sandbox:&:sandbox <- get *curr-sandbox, next-sandbox:offset
    *prev-sandbox <- put *prev-sandbox, next-sandbox:offset, next-sandbox
  }
  # update sandbox count
  sandbox-count:num <- get *env, number-of-sandboxes:offset
  sandbox-count <- subtract sandbox-count, 1
  *env <- put *env, number-of-sandboxes:offset, sandbox-count
  # reset scroll if deleted sandbox was last
  {
    break-if next-sandbox
    render-from:num <- get *env, render-from:offset
    reset-scroll?:bool <- equal render-from, sandbox-count
    break-unless reset-scroll?
    *env <- put *env, render-from:offset, -1
  }
]

scenario deleting-sandbox-after-scroll [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  # initialize environment
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press page-down
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
  ]
  # delete the second sandbox
  assume-console [
    left-click 6, 34
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario deleting-top-sandbox-after-scroll [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  # initialize environment
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
  # create 2 sandboxes and scroll to second
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
    press page-down
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
  ]
  # delete the second sandbox
  assume-console [
    left-click 2, 34
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario deleting-final-sandbox-after-scroll [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  # initialize environment
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
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
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .──────────────────────────────────────────────────.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  # delete the second sandbox
  assume-console [
    left-click 2, 34
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # implicitly scroll up to first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

scenario deleting-updates-sandbox-count [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  # initialize environment
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, []
  render-all screen, env, render
  # create 2 sandboxes
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
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
    event-loop screen, console, env, resources
  ]
  # shouldn't go past last sandbox
  screen-should-contain [
    .                               run (F4)           .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

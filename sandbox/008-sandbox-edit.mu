## editing sandboxes after they've been created

scenario clicking-on-a-sandbox-moves-it-to-editor [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 10/height
  # run something
  1:address:array:character <- new [add 2, 2]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
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
  # click somewhere on the sandbox
  assume-console [
    left-click 3, 4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # it pops back into editor
  screen-should-contain [
    .                               run (F4)           .
    .add 2, 2                                          .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .0add 2, 2                                         .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

after <global-touch> [
  # support 'edit' button
  {
    edit?:boolean <- should-attempt-edit? click-row, click-column, env
    break-unless edit?
    edit?, env <- try-edit-sandbox click-row, env
    break-unless edit?
    hide-screen screen
    screen <- render-sandbox-side screen, env, render
    screen <- update-cursor screen, current-sandbox, env
    show-screen screen
    loop +next-event:label
  }
]

# some preconditions for attempting to edit a sandbox
def should-attempt-edit? click-row:number, click-column:number, env:address:programming-environment-data -> result:boolean [
  local-scope
  load-ingredients
  # are we below the sandbox editor?
  click-sandbox-area?:boolean <- click-on-sandbox-area? click-row, env
  reply-unless click-sandbox-area?, 0/false
  # narrower, is the click in the columns spanning the 'edit' button?
  first-sandbox:address:editor-data <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:number <- get *first-sandbox, left:offset
  sandbox-right-margin:number <- get *first-sandbox, right:offset
  edit-button-left:number, edit-button-right:number, _ <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  edit-button-vertical-area?:boolean <- within-range? click-column, edit-button-left, edit-button-right
  reply-unless edit-button-vertical-area?, 0/false
  # finally, is sandbox editor empty?
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  result <- empty-editor? current-sandbox
]

def try-edit-sandbox click-row:number, env:address:programming-environment-data -> clicked-on-edit-button?:boolean, env:address:programming-environment-data [
  local-scope
  load-ingredients
  # identify the sandbox to edit, if the click was actually on the 'edit' button
  sandbox:address:sandbox-data <- find-sandbox env, click-row
  return-unless sandbox, 0/false
  clicked-on-edit-button? <- copy 1/true
  # 'edit' button = 'copy' button + 'delete' button
  text:address:array:character <- get *sandbox, data:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  current-sandbox <- insert-text current-sandbox, text
  env <- delete-sandbox env, sandbox
  # reset scroll
  *env <- put *env, render-from:offset, -1
]

scenario sandbox-with-print-can-be-edited [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # run a print instruction
  1:address:array:character <- new [print-integer screen, 4]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .print-integer screen, 4                           .
    .screen:                                           .
    .  .4                             .                .
    .  .                              .                .
    .  .                              .                .
    .  .                              .                .
    .  .                              .                .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # edit the sandbox
  assume-console [
    left-click 3, 18
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .print-integer screen, 4                           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
  ]
]

scenario editing-sandbox-after-scrolling-resets-scroll [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # initialize environment
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data, render
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
  # edit the second sandbox
  assume-console [
    left-click 2, 10
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .add 2, 2                                          .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario editing-sandbox-updates-sandbox-count [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # initialize environment
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data, render
  # create 2 sandboxes and scroll to second
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
  ]
  # edit the second sandbox, then resave
  assume-console [
    left-click 3, 10
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # no change in contents
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
  ]
  # now try to scroll past end
  assume-console [
    press page-down
    press page-down
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # screen should show just final sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

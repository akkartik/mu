## editing sandboxes after they've been created

scenario clicking-on-a-sandbox-moves-it-to-editor [
  trace-until 100/app  # trace too long
  assume-screen 40/width, 10/height
  # run something
  1:address:array:character <- new [add 2, 2]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                                        .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .add 2, 2                                .
    .4                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
    .                                        .
    .                                        .
  ]
  # click somewhere on the sandbox
  assume-console [
    left-click 3, 0
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # it pops back into editor
  screen-should-contain [
    .                     run (F4)           .
    .add 2, 2                                .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                     run (F4)           .
    .0add 2, 2                               .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
    .                                        .
  ]
]

after <global-touch> [
  # below editor? pop appropriate sandbox contents back into sandbox editor provided it's empty
  {
    sandbox-left-margin:number <- get *current-sandbox, left:offset
    click-column:number <- get *t, column:offset
    on-sandbox-side?:boolean <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:address:sandbox-data <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
    click-row:number <- get *t, row:offset
    below-sandbox-editor?:boolean <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    empty-sandbox-editor?:boolean <- empty-editor? current-sandbox
    break-unless empty-sandbox-editor?  # make the user hit F4 before editing a new sandbox
    # identify the sandbox to edit and remove it from the sandbox list
    sandbox:address:sandbox-data <- extract-sandbox env, click-row
    text:address:array:character <- get *sandbox, data:offset
    current-sandbox <- insert-text current-sandbox, text
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, current-sandbox
    show-screen screen
    loop +next-event:label
  }
]

recipe empty-editor? editor:address:editor-data -> result:boolean [
  local-scope
  load-ingredients
  head:address:duplex-list:character <- get *editor, data:offset
  first:address:duplex-list:character <- next head
  result <- not first
]

recipe extract-sandbox env:address:programming-environment-data, click-row:number -> result:address:sandbox-data [
  local-scope
  load-ingredients
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:address:address:sandbox-data <- get-address *env, sandbox:offset
  start:number <- get **sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:boolean <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  {
    next-sandbox:address:sandbox-data <- get **sandbox, next-sandbox:offset
    break-unless next-sandbox
    # if click-row < sandbox.next-sandbox.starting-row-on-screen, break
    next-start:number <- get *next-sandbox, starting-row-on-screen:offset
    found?:boolean <- lesser-than click-row, next-start
    break-if found?
    sandbox <- get-address **sandbox, next-sandbox:offset
    loop
  }
  # snip sandbox out of its list
  result <- copy *sandbox
  *sandbox <- copy next-sandbox
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
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .print-integer screen, 4                           .
    .screen:                                           .
    .  .4                             .                .
    .  .                              .                .
    .  .                              .                .
    .  .                              .                .
    .  .                              .                .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # edit the sandbox
  assume-console [
    left-click 3, 70
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

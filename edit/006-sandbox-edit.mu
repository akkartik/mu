## editing sandboxes after they've been created

scenario clicking-on-a-sandbox-moves-it-to-editor [
  trace-until 100/app  # trace too long
  assume-screen 40/width, 10/height
  # basic recipe
  1:address:array:character <- new [ 
recipe foo [
  reply 4
]]
  # run it
  2:address:array:character <- new [foo]
  assume-console [
    press F4
  ]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  reply 4           ┊0                 x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                  .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click somewhere in the first row of the sandbox
  assume-console [
    left-click 3, 30
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # it pops back into editor
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊foo                .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  reply 4           ┊                   .
    .]                   ┊                   .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                   .
    .                    ┊                   .
    .                    ┊                   .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊0foo               .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  reply 4           ┊                   .
    .]                   ┊                   .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                   .
    .                    ┊                   .
    .                    ┊                   .
  ]
]

after <global-touch> [
  # below sandbox editor? pop appropriate sandbox contents back into sandbox editor
  {
    sandbox-left-margin:number <- get *current-sandbox, left:offset
    click-column:number <- get t, column:offset
    on-sandbox-side?:boolean <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:address:sandbox-data <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
    click-row:number <- get t, row:offset
    below-sandbox-editor?:boolean <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    empty-sandbox-editor?:boolean <- empty-editor? current-sandbox
    break-unless empty-sandbox-editor?  # don't clobber existing contents
    # identify the sandbox to edit and remove it from the sandbox list
    sandbox:address:sandbox-data <- extract-sandbox env, click-row
    break-unless sandbox
    text:address:array:character <- get *sandbox, data:offset
    current-sandbox <- insert-text current-sandbox, text
    *env <- put *env, render-from:offset, -1
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    show-screen screen
    loop +next-event:label
  }
]

def empty-editor? editor:address:editor-data -> result:boolean [
  local-scope
  load-ingredients
  head:address:duplex-list:character <- get *editor, data:offset
  first:address:duplex-list:character <- next head
  result <- not first
]

def extract-sandbox env:address:programming-environment-data, click-row:number -> result:address:sandbox-data, env:address:programming-environment-data [
  local-scope
  load-ingredients
  curr-sandbox:address:sandbox-data <- get *env, sandbox:offset
  start:number <- get *curr-sandbox, starting-row-on-screen:offset
  in-editor?:boolean <- lesser-than click-row, start
  return-if in-editor?, 0
  first-sandbox?:boolean <- equal click-row, start
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
      next-sandbox:address:sandbox-data <- get *curr-sandbox, next-sandbox:offset
      break-unless next-sandbox
      # if click-row < sandbox.next-sandbox.starting-row-on-screen, break
      next-start:number <- get *next-sandbox, starting-row-on-screen:offset
      found?:boolean <- lesser-than click-row, next-start
      break-if found?
      prev-sandbox <- copy curr-sandbox
      curr-sandbox <- copy next-sandbox
      loop
    }
    # snip sandbox out of its list
    *prev-sandbox <- put *prev-sandbox, next-sandbox:offset, next-sandbox
  }
  result <- copy curr-sandbox
  # update sandbox count
  sandbox-count:number <- get *env, number-of-sandboxes:offset
  sandbox-count <- subtract sandbox-count, 1
  *env <- put *env, number-of-sandboxes:offset, sandbox-count
  # position cursor in sandbox editor
  *env <- put *env, sandbox-in-focus?:offset, 1/true
]

scenario sandbox-with-print-can-be-edited [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an instruction
  2:address:array:character <- new [print-integer screen, 4]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
    .                                                  ┊print-integer screen, 4                          .
    .                                                  ┊screen:                                          .
    .                                                  ┊  .4                             .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # edit the sandbox
  assume-console [
    left-click 3, 70
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊print-integer screen, 4                          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
]

scenario editing-sandbox-after-scrolling-resets-scroll [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:array:character <- new []
  2:address:array:character <- new []
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
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
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # edit the second sandbox
  assume-console [
    left-click 2, 20
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # second sandbox shows in editor; scroll resets to display first sandbox
  screen-should-contain [
    .                              .
    .               ┊add 2, 2      .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario editing-sandbox-updates-sandbox-count [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:array:character <- new []
  2:address:array:character <- new []
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  # create 2 sandboxes
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  screen-should-contain [
    .                              .
    .               ┊              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
  ]
  # edit the second sandbox, then resave
  assume-console [
    left-click 3, 20
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # no change in contents
  screen-should-contain [
    .                              .
    .               ┊              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
  ]
  # now try to scroll past end
  assume-console [
    press down-arrow
    press down-arrow
    press down-arrow
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # screen should show just final sandbox
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

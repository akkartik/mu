## editing sandboxes after they've been created

scenario clicking-on-a-sandbox-moves-it-to-editor [
  $close-trace  # trace too long
  assume-screen 40/width, 10/height
  # basic recipe
  1:address:array:character <- new [ 
recipe foo [
  add 2, 2
]]
  # run it
  2:address:array:character <- new [foo]
  assume-console [
    press F4
  ]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊                   .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                  x.
    .]                   ┊foo                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                  .
    .                    ┊━━━━━━━━━━━━━━━━━━━.
    .                    ┊                   .
  ]
  # click somewhere on the sandbox
  assume-console [
    left-click 3, 30
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # it pops back into editor
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊foo                .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                   .
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
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                     run (F4)           .
    .                    ┊0foo               .
    .recipe foo [        ┊━━━━━━━━━━━━━━━━━━━.
    .  add 2, 2          ┊                   .
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
    break-unless empty-sandbox-editor?  # don't clobber existing contents
    # identify the sandbox to edit and remove it from the sandbox list
    sandbox:address:sandbox-data <- extract-sandbox env, click-row
    text:address:array:character <- get *sandbox, data:offset
    current-sandbox <- insert-text current-sandbox, text
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    show-screen screen
    loop +next-event:label
  }
]

recipe empty-editor? [
  local-scope
  editor:address:editor-data <- next-ingredient
  head:address:duplex-list <- get *editor, data:offset
  first:address:duplex-list <- next-duplex head
  result:boolean <- not first
  reply result
]

recipe extract-sandbox [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  click-row:number <- next-ingredient
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
  result:address:sandbox-data <- copy *sandbox
  *sandbox <- copy next-sandbox
  # position cursor in sandbox editor
  sandbox-in-focus?:address:boolean <- get-address *env, sandbox-in-focus?:offset
  *sandbox-in-focus? <- copy 1/true
  reply result
]

scenario sandbox-with-print-can-be-edited [
  $close-trace  # trace too long
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an instruction
  2:address:array:character <- new [print-integer screen:address, 4]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the sandbox
  assume-console [
    press F4
  ]
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊print-integer screen:address, 4                  .
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
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊print-integer screen:address, 4                  .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
]

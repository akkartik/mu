## clicking on the code typed into a sandbox toggles its trace

scenario sandbox-click-on-code-toggles-app-trace [
  $close-trace  # trace too long
  assume-screen 40/width, 10/height
  # run a stash instruction
  1:address:array:character <- new [stash [abc]]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character
  event-loop screen:address, console:address, 2:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                                        .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .stash [abc]                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
  ]
  # click on the code in the sandbox
  assume-console [
    left-click 4, 21
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # trace now printed and cursor shouldn't have budged
  screen-should-contain [
    .                     run (F4)           .
    .␣                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .stash [abc]                             .
    .abc                                     .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                        .
    .                                        .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .                                        .
    .abc                                     .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
  ]
  # click again on the same region
  assume-console [
    left-click 4, 25
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # trace hidden again
  screen-should-contain [
    .                     run (F4)           .
    .␣                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .stash [abc]                             .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
  ]
]

scenario sandbox-shows-app-trace-and-result [
  $close-trace  # trace too long
  assume-screen 40/width, 10/height
  # run a stash instruction and some code
  1:address:array:character <- new [stash [abc]
add 2, 2]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character
  event-loop screen:address, console:address, 2:address:programming-environment-data
  screen-should-contain [
    .                     run (F4)           .
    .                                        .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .stash [abc]                             .
    .add 2, 2                                .
    .4                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
  ]
  # click on the code in the sandbox
  assume-console [
    left-click 4, 21
  ]
  run [
    event-loop screen:address, console:address, 2:address:programming-environment-data
  ]
  # trace now printed above result
  screen-should-contain [
    .                     run (F4)           .
    .                                        .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                       x.
    .stash [abc]                             .
    .add 2, 2                                .
    .abc                                     .
    .4                                       .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                        .
  ]
]

container sandbox-data [
  trace:address:array:character
  display-trace?:boolean
]

# replaced in a later layer
recipe! update-sandbox [
  local-scope
  sandbox:address:sandbox-data <- next-ingredient
  data:address:array:character <- get *sandbox, data:offset
  response:address:address:array:character <- get-address *sandbox, response:offset
  trace:address:address:array:character <- get-address *sandbox, trace:offset
  fake-screen:address:address:screen <- get-address *sandbox, screen:offset
  *response, _, *fake-screen, *trace <- run-interactive data
]

# clicks on sandbox code toggle its display-trace? flag
after <global-touch> [
  # check if it's inside the code of any sandbox
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
    # identify the sandbox whose code is being clicked on
    sandbox:address:sandbox-data <- find-click-in-sandbox-code env, click-row
    break-unless sandbox
    # toggle its display-trace? property
    x:address:boolean <- get-address *sandbox, display-trace?:offset
    *x <- not *x
    hide-screen screen
    screen <- render-sandbox-side screen, env, 1/clear
    screen <- update-cursor screen, current-sandbox
    # no change in cursor
    show-screen screen
    loop +next-event:label
  }
]

recipe find-click-in-sandbox-code [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  click-row:number <- next-ingredient
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  start:number <- get *sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:boolean <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  # while click-row < sandbox.next-sandbox.starting-row-on-screen
  {
    next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
    break-unless next-sandbox
    next-start:number <- get *next-sandbox, starting-row-on-screen:offset
    found?:boolean <- lesser-than click-row, next-start
    break-if found?
    sandbox <- copy next-sandbox
    loop
  }
  # return sandbox if click is in its code region
  code-ending-row:number <- get *sandbox, code-ending-row-on-screen:offset
  click-above-response?:boolean <- lesser-than click-row, code-ending-row
  start:number <- get *sandbox, starting-row-on-screen:offset
  click-below-menu?:boolean <- greater-than click-row, start
  click-on-sandbox-code?:boolean <- and click-above-response?, click-below-menu?
  {
    break-if click-on-sandbox-code?
    reply 0/no-click-in-sandbox-output
  }
  reply sandbox
]

# when rendering a sandbox, dump its trace before response/warning if display-trace? property is set
after <render-sandbox-results> [
  {
    display-trace?:boolean <- get *sandbox, display-trace?:offset
    break-unless display-trace?
    sandbox-trace:address:array:character <- get *sandbox, trace:offset
    break-unless sandbox-trace  # nothing to print; move on
    row, screen <- render-string, screen, sandbox-trace, left, right, 245/grey, row
  }
  <render-sandbox-trace-done>
]

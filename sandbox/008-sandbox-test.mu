## clicking on sandbox results to 'fix' them and turn sandboxes into tests

scenario sandbox-click-on-result-toggles-color-to-green [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # basic recipe
  1:address:shared:array:character <- new [ 
recipe foo [
  reply 4
]]
  # run it
  2:address:shared:array:character <- new [foo]
  assume-console [
    press F4
  ]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 2:address:shared:array:character
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # click on the '4' in the result
  assume-console [
    left-click 5, 21
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/test-recipes
  ]
  # color toggles to green
  screen-should-contain-in-color 2/green, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .4                                                 .
    .                                                  .
  ]
  # cursor should remain unmoved
  run [
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  screen-should-contain [
    .                               run (F4)           .
    .␣                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0                                                x.
    .foo                                               .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # now change the result
  1:address:shared:array:character <- new [ 
recipe foo [
  reply 3
]]
  # then rerun
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data, 1:address:shared:array:character/new-test-recipes
  ]
  # result turns red
  screen-should-contain-in-color 1/red, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .3                                                 .
    .                                                  .
  ]
]

# clicks on sandbox responses save it as 'expected'
after <global-touch> [
  # check if it's inside the output of any sandbox
  {
    sandbox-left-margin:number <- get *current-sandbox, left:offset
    click-column:number <- get *t, column:offset
    on-sandbox-side?:boolean <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:address:shared:sandbox-data <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
    click-row:number <- get *t, row:offset
    below-sandbox-editor?:boolean <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    # identify the sandbox whose output is being clicked on
    sandbox:address:shared:sandbox-data <- find-click-in-sandbox-output env, click-row
    break-unless sandbox
    # toggle its expected-response, and save session
    sandbox <- toggle-expected-response sandbox
    save-sandboxes env
    hide-screen screen
    screen <- render-sandbox-side screen, env, 1/clear
    screen <- update-cursor screen, current-sandbox, env
    # no change in cursor
    show-screen screen
    loop +next-event:label
  }
]

# this requires tracking where responses begin for every sandbox
container sandbox-data [
  response-starting-row-on-screen:number
]

recipe find-click-in-sandbox-output env:address:shared:programming-environment-data, click-row:number -> sandbox:address:shared:sandbox-data [
  local-scope
  load-ingredients
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:address:shared:sandbox-data <- get *env, sandbox:offset
  start:number <- get *sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:boolean <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  # while click-row < sandbox.next-sandbox.starting-row-on-screen
  {
    next-sandbox:address:shared:sandbox-data <- get *sandbox, next-sandbox:offset
    break-unless next-sandbox
    next-start:number <- get *next-sandbox, starting-row-on-screen:offset
    found?:boolean <- lesser-than click-row, next-start
    break-if found?
    sandbox <- copy next-sandbox
    loop
  }
  # return sandbox if click is in its output region
  response-starting-row:number <- get *sandbox, response-starting-row-on-screen:offset
  reply-unless response-starting-row, 0/no-click-in-sandbox-output
  click-in-response?:boolean <- greater-or-equal click-row, response-starting-row
  reply-unless click-in-response?, 0/no-click-in-sandbox-output
  reply sandbox
]

recipe toggle-expected-response sandbox:address:shared:sandbox-data -> sandbox:address:shared:sandbox-data [
  local-scope
  load-ingredients
  expected-response:address:address:shared:array:character <- get-address *sandbox, expected-response:offset
  {
    # if expected-response is set, reset
    break-unless *expected-response
    *expected-response <- copy 0
    reply sandbox/same-as-ingredient:0
  }
  # if not, current response is the expected response
  response:address:shared:array:character <- get *sandbox, response:offset
  *expected-response <- copy response
]

# when rendering a sandbox, color it in red/green if expected response exists
after <render-sandbox-response> [
  {
    break-unless sandbox-response
    response-starting-row:address:number <- get-address *sandbox, response-starting-row-on-screen:offset
    *response-starting-row <- copy row
    expected-response:address:shared:array:character <- get *sandbox, expected-response:offset
    break-unless expected-response  # fall-through to print in grey
    response-is-expected?:boolean <- equal expected-response, sandbox-response
    {
      break-if response-is-expected?:boolean
      row, screen <- render screen, sandbox-response, left, right, 1/red, row
    }
    {
      break-unless response-is-expected?:boolean
      row, screen <- render screen, sandbox-response, left, right, 2/green, row
    }
    jump +render-sandbox-end:label
  }
]

before <end-render-sandbox-reset-hidden> [
  $log sandbox, [resetting response starting row]
  tmp:address:number <- get-address *sandbox, response-starting-row-on-screen:offset
  *tmp <- copy 0
]

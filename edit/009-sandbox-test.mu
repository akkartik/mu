## clicking on sandbox results to 'fix' them and turn sandboxes into tests

scenario sandbox-click-on-result-toggles-color-to-green [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
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
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # click on the '4' in the result
  assume-console [
    left-click 5, 51
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # color toggles to green
  screen-should-contain-in-color 2/green, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   4                                                .
    .                                                                                                    .
    .                                                                                                    .
  ]
  # cursor should remain unmoved
  run [
    4:character/cursor <- copy 9251/␣
    print screen:address:screen, 4:character/cursor
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .␣                                                 ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
  ]
  # now change the result
  # then rerun
  assume-console [
    left-click 3, 11  # cursor to end of line
    press backspace
    type [3]
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data
  ]
  # result turns red
  screen-should-contain-in-color 1/red, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   3                                                .
    .                                                                                                    .
    .                                                                                                    .
  ]
]

# this requires tracking a couple more things
container sandbox-data [
  response-starting-row-on-screen:number
  expected-response:address:array:character
]

# include expected response when saving or restoring a sandbox
before <end-save-sandbox> [
  {
    expected-response:address:array:character <- get *curr, expected-response:offset
    break-unless expected-response
    filename <- append filename, [.out]
    save filename, expected-response
  }
]

before <end-restore-sandbox> [
  {
    filename <- append filename, [.out]
    contents <- restore filename
    break-unless contents
    *curr <- put *curr, expected-response:offset, contents
  }
]

# clicks on sandbox responses save it as 'expected'
after <global-touch> [
  # check if it's inside the output of any sandbox
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
    # identify the sandbox whose output is being clicked on
    sandbox:address:sandbox-data <- find-click-in-sandbox-output env, click-row
    break-unless sandbox
    # toggle its expected-response, and save session
    sandbox <- toggle-expected-response sandbox
    save-sandboxes env
    hide-screen screen
    screen <- render-sandbox-side screen, env, 1/clear
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    # no change in cursor
    show-screen screen
    loop +next-event:label
  }
]

def find-click-in-sandbox-output env:address:programming-environment-data, click-row:number -> sandbox:address:sandbox-data [
  local-scope
  load-ingredients
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
  # return sandbox if click is in its output region
  response-starting-row:number <- get *sandbox, response-starting-row-on-screen:offset
  return-unless response-starting-row, 0/no-click-in-sandbox-output
  click-in-response?:boolean <- greater-or-equal click-row, response-starting-row
  return-unless click-in-response?, 0/no-click-in-sandbox-output
  return sandbox
]

def toggle-expected-response sandbox:address:sandbox-data -> sandbox:address:sandbox-data [
  local-scope
  load-ingredients
  expected-response:address:array:character <- get *sandbox, expected-response:offset
  {
    # if expected-response is set, reset
    break-unless expected-response
    *sandbox <- put *sandbox, expected-response:offset, 0
  }
  {
    # if not, set expected response to the current response
    break-if expected-response
    response:address:array:character <- get *sandbox, response:offset
    *sandbox <- put *sandbox, expected-response:offset, response
  }
]

# when rendering a sandbox, color it in red/green if expected response exists
after <render-sandbox-response> [
  {
    break-unless sandbox-response
    *sandbox <- put *sandbox, response-starting-row-on-screen:offset, row
    expected-response:address:array:character <- get *sandbox, expected-response:offset
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
  *sandbox <- put *sandbox, response-starting-row-on-screen:offset, 0
]

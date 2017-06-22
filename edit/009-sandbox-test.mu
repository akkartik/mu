## clicking on sandbox results to 'fix' them and turn sandboxes into tests

scenario sandbox-click-on-result-toggles-color-to-green [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # basic recipe
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  reply 4|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  render-all screen, env, render
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  reply 4                                         ┊─────────────────────────────────────────────────.
    .]                                                 ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # click on the '4' in the result
  assume-console [
    left-click 5, 51
  ]
  run [
    event-loop screen, console, env, resources
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
    cursor:char <- copy 9251/␣
    print screen, cursor
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .␣ecipe foo [                                      ┊                                                 .
    .  reply 4                                         ┊─────────────────────────────────────────────────.
    .]                                                 ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # now change the result
  # then rerun
  assume-console [
    left-click 2, 11  # cursor to end of line
    press backspace
    type [3]
    press F4
  ]
  run [
    event-loop screen, console, env, resources
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
container sandbox [
  response-starting-row-on-screen:num
  expected-response:text
]

# include expected response when saving or restoring a sandbox
before <end-save-sandbox> [
  {
    expected-response:text <- get *curr, expected-response:offset
    break-unless expected-response
    filename <- append filename, [.out]
    resources <- dump resources, filename, expected-response
  }
]

before <end-restore-sandbox> [
  {
    filename <- append filename, [.out]
    contents <- slurp resources, filename
    break-unless contents
    *curr <- put *curr, expected-response:offset, contents
  }
]

# clicks on sandbox responses save it as 'expected'
after <global-touch> [
  # check if it's inside the output of any sandbox
  {
    sandbox-left-margin:num <- get *current-sandbox, left:offset
    click-column:num <- get t, column:offset
    on-sandbox-side?:bool <- greater-or-equal click-column, sandbox-left-margin
    break-unless on-sandbox-side?
    first-sandbox:&:sandbox <- get *env, sandbox:offset
    break-unless first-sandbox
    first-sandbox-begins:num <- get *first-sandbox, starting-row-on-screen:offset
    click-row:num <- get t, row:offset
    below-sandbox-editor?:bool <- greater-or-equal click-row, first-sandbox-begins
    break-unless below-sandbox-editor?
    # identify the sandbox whose output is being clicked on
    sandbox:&:sandbox <- find-click-in-sandbox-output env, click-row
    break-unless sandbox
    # toggle its expected-response, and save session
    sandbox <- toggle-expected-response sandbox
    save-sandboxes env, resources
    screen <- render-sandbox-side screen, env, render
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    loop +next-event
  }
]

def find-click-in-sandbox-output env:&:environment, click-row:num -> sandbox:&:sandbox [
  local-scope
  load-ingredients
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox:&:sandbox <- get *env, sandbox:offset
  start:num <- get *sandbox, starting-row-on-screen:offset
  clicked-on-sandboxes?:bool <- greater-or-equal click-row, start
  assert clicked-on-sandboxes?, [extract-sandbox called on click to sandbox editor]
  # while click-row < sandbox.next-sandbox.starting-row-on-screen
  {
    next-sandbox:&:sandbox <- get *sandbox, next-sandbox:offset
    break-unless next-sandbox
    next-start:num <- get *next-sandbox, starting-row-on-screen:offset
    found?:bool <- lesser-than click-row, next-start
    break-if found?
    sandbox <- copy next-sandbox
    loop
  }
  # return sandbox if click is in its output region
  response-starting-row:num <- get *sandbox, response-starting-row-on-screen:offset
  return-unless response-starting-row, 0/no-click-in-sandbox-output
  click-in-response?:bool <- greater-or-equal click-row, response-starting-row
  return-unless click-in-response?, 0/no-click-in-sandbox-output
  return sandbox
]

def toggle-expected-response sandbox:&:sandbox -> sandbox:&:sandbox [
  local-scope
  load-ingredients
  expected-response:text <- get *sandbox, expected-response:offset
  {
    # if expected-response is set, reset
    break-unless expected-response
    *sandbox <- put *sandbox, expected-response:offset, 0
  }
  {
    # if not, set expected response to the current response
    break-if expected-response
    response:text <- get *sandbox, response:offset
    *sandbox <- put *sandbox, expected-response:offset, response
  }
]

# when rendering a sandbox, color it in red/green if expected response exists
after <render-sandbox-response> [
  {
    break-unless sandbox-response
    *sandbox <- put *sandbox, response-starting-row-on-screen:offset, row
    expected-response:text <- get *sandbox, expected-response:offset
    break-unless expected-response  # fall-through to print in grey
    response-is-expected?:bool <- equal expected-response, sandbox-response
    {
      break-if response-is-expected?
      row, screen <- render-text screen, sandbox-response, left, right, 1/red, row
    }
    {
      break-unless response-is-expected?:bool
      row, screen <- render-text screen, sandbox-response, left, right, 2/green, row
    }
    jump +render-sandbox-end
  }
]

before <end-render-sandbox-reset-hidden> [
  *sandbox <- put *sandbox, response-starting-row-on-screen:offset, 0
]

## clicking on the code typed into a sandbox toggles its trace

scenario sandbox-click-on-code-toggles-app-trace [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # basic recipe
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  stash [abc]|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  stash [abc]                                     ┊─────────────────────────────────────────────────.
    .]                                                 ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # click on the code in the sandbox
  assume-console [
    left-click 4, 51
  ]
  run [
    event-loop screen, console, env, resources
    cursor:char <- copy 9251/␣
    print screen, cursor
  ]
  # trace now printed and cursor shouldn't have budged
  screen-should-contain [
    .                                                                                 run (F4)           .
    .␣ecipe foo [                                      ┊                                                 .
    .  stash [abc]                                     ┊─────────────────────────────────────────────────.
    .]                                                 ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊abc                                              .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊abc                                              .
  ]
  # click again on the same region
  assume-console [
    left-click 4, 55
  ]
  run [
    event-loop screen, console, env, resources
    print screen, cursor
  ]
  # trace hidden again
  screen-should-contain [
    .                                                                                 run (F4)           .
    .␣ecipe foo [                                      ┊                                                 .
    .  stash [abc]                                     ┊─────────────────────────────────────────────────.
    .]                                                 ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
]

scenario sandbox-shows-app-trace-and-result [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # basic recipe
  assume-resources [
    [lesson/recipes.mu] <- [
      |recipe foo [|
      |  stash [abc]|
      |  reply 4|
      |]|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [foo]
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  stash [abc]                                     ┊─────────────────────────────────────────────────.
    .  reply 4                                         ┊0   edit       copy       to recipe    delete    .
    .]                                                 ┊foo                                              .
    .                                                  ┊4                                                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # click on the code in the sandbox
  assume-console [
    left-click 4, 51
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # trace now printed above result
  screen-should-contain [
    .                                                                                 run (F4)           .
    .recipe foo [                                      ┊                                                 .
    .  stash [abc]                                     ┊─────────────────────────────────────────────────.
    .  reply 4                                         ┊0   edit       copy       to recipe    delete    .
    .]                                                 ┊foo                                              .
    .                                                  ┊abc                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊8 instructions run                               .
    .                                                  ┊4                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
]

scenario clicking-on-app-trace-does-nothing [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [stash 123456789]
  # create and expand the trace
  assume-console [
    press F4
    left-click 4, 51
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊stash 123456789                                  .
    .                                                  ┊123456789                                        .
  ]
  # click on the stash under the edit-button region (or any of the other buttons, really)
  assume-console [
    left-click 5, 57
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # no change; doesn't die
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊stash 123456789                                  .
    .                                                  ┊123456789                                        .
  ]
]

container sandbox [
  trace:text
  display-trace?:bool
]

# replaced in a later layer
def! update-sandbox sandbox:&:sandbox, env:&:environment, idx:num -> sandbox:&:sandbox, env:&:environment [
  local-scope
  load-ingredients
  data:text <- get *sandbox, data:offset
  response:text, _, fake-screen:&:screen, trace:text <- run-sandboxed data
  *sandbox <- put *sandbox, response:offset, response
  *sandbox <- put *sandbox, screen:offset, fake-screen
  *sandbox <- put *sandbox, trace:offset, trace
]

# clicks on sandbox code toggle its display-trace? flag
after <global-touch> [
  # check if it's inside the code of any sandbox
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
    # identify the sandbox whose code is being clicked on
    sandbox:&:sandbox <- find-click-in-sandbox-code env, click-row
    break-unless sandbox
    # toggle its display-trace? property
    x:bool <- get *sandbox, display-trace?:offset
    x <- not x
    *sandbox <- put *sandbox, display-trace?:offset, x
    screen <- render-sandbox-side screen, env, render
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    loop +next-event
  }
]

def find-click-in-sandbox-code env:&:environment, click-row:num -> sandbox:&:sandbox [
  local-scope
  load-ingredients
  # assert click-row >= sandbox.starting-row-on-screen
  sandbox <- get *env, sandbox:offset
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
  # return sandbox if click is in its code region
  code-ending-row:num <- get *sandbox, code-ending-row-on-screen:offset
  click-above-response?:bool <- lesser-than click-row, code-ending-row
  start:num <- get *sandbox, starting-row-on-screen:offset
  click-below-menu?:bool <- greater-than click-row, start
  click-on-sandbox-code?:bool <- and click-above-response?, click-below-menu?
  {
    break-if click-on-sandbox-code?
    return 0/no-click-in-sandbox-output
  }
  return sandbox
]

# when rendering a sandbox, dump its trace before response/warning if display-trace? property is set
after <render-sandbox-results> [
  {
    display-trace?:bool <- get *sandbox, display-trace?:offset
    break-unless display-trace?
    sandbox-trace:text <- get *sandbox, trace:offset
    break-unless sandbox-trace  # nothing to print; move on
    row, screen <- render-text screen, sandbox-trace, left, right, 245/grey, row
  }
  <render-sandbox-trace-done>
]

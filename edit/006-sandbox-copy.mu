## the 'copy' button makes it easy to duplicate a sandbox, and thence to
## see code operate in multiple situations

scenario copy-a-sandbox-to-editor [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  render-all screen, env, render
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # click at left edge of 'copy' button
  assume-console [
    left-click 3, 69
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # it copies into editor
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊add 1, 1                                         .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊0add 1, 1                                        .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
]

scenario copy-a-sandbox-to-editor-2 [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  render-all screen, env, render
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # click at right edge of 'copy' button (just before 'delete')
  assume-console [
    left-click 3, 76
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # it copies into editor
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊add 1, 1                                         .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊0add 1, 1                                        .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
]

after <global-touch> [
  # support 'copy' button
  {
    copy?:bool <- should-attempt-copy? click-row, click-column, env
    break-unless copy?
    copy?, env <- try-copy-sandbox click-row, env
    break-unless copy?
    screen <- render-sandbox-side screen, env, render
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    loop +next-event
  }
]

# some preconditions for attempting to copy a sandbox
def should-attempt-copy? click-row:num, click-column:num, env:&:environment -> result:bool [
  local-scope
  load-inputs
  # are we below the sandbox editor?
  click-sandbox-area?:bool <- click-on-sandbox-area? click-row, click-column, env
  return-unless click-sandbox-area?, false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:&:editor <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:num <- get *first-sandbox, left:offset
  sandbox-right-margin:num <- get *first-sandbox, right:offset
  _, _, copy-button-left:num, copy-button-right:num <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  copy-button-vertical-area?:bool <- within-range? click-column, copy-button-left, copy-button-right
  return-unless copy-button-vertical-area?, false
  # finally, is sandbox editor empty?
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  result <- empty-editor? current-sandbox
]

def try-copy-sandbox click-row:num, env:&:environment -> clicked-on-copy-button?:bool, env:&:environment [
  local-scope
  load-inputs
  # identify the sandbox to copy, if the click was actually on the 'copy' button
  sandbox:&:sandbox <- find-sandbox env, click-row
  return-unless sandbox, false
  clicked-on-copy-button? <- copy true
  text:text <- get *sandbox, data:offset
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  current-sandbox <- insert-text current-sandbox, text
  # reset scroll
  *env <- put *env, render-from:offset, -1
  # position cursor in sandbox editor
  *env <- put *env, sandbox-in-focus?:offset, true
]

def find-sandbox env:&:environment, click-row:num -> result:&:sandbox [
  local-scope
  load-inputs
  curr-sandbox:&:sandbox <- get *env, sandbox:offset
  {
    break-unless curr-sandbox
    start:num <- get *curr-sandbox, starting-row-on-screen:offset
    found?:bool <- equal click-row, start
    return-if found?, curr-sandbox
    curr-sandbox <- get *curr-sandbox, next-sandbox:offset
    loop
  }
  return 0/not-found
]

def click-on-sandbox-area? click-row:num, click-column:num, env:&:environment -> result:bool [
  local-scope
  load-inputs
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  sandbox-left-margin:num <- get *current-sandbox, left:offset
  on-sandbox-side?:bool <- greater-or-equal click-column, sandbox-left-margin
  return-unless on-sandbox-side?, false
  first-sandbox:&:sandbox <- get *env, sandbox:offset
  return-unless first-sandbox, false
  first-sandbox-begins:num <- get *first-sandbox, starting-row-on-screen:offset
  result <- greater-or-equal click-row, first-sandbox-begins
]

def empty-editor? editor:&:editor -> result:bool [
  local-scope
  load-inputs
  head:&:duplex-list:char <- get *editor, data:offset
  first:&:duplex-list:char <- next head
  result <- not first
]

def within-range? x:num, low:num, high:num -> result:bool [
  local-scope
  load-inputs
  not-too-far-left?:bool <- greater-or-equal x, low
  not-too-far-right?:bool <- lesser-or-equal x, high
  result <- and not-too-far-left? not-too-far-right?
]

scenario copy-fails-if-sandbox-editor-not-empty [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  render-all screen, env, render
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # type something into the sandbox editor, then click on the 'copy' button
  assume-console [
    left-click 2, 70  # put cursor in sandbox editor
    type [0]  # type something
    left-click 3, 70  # click 'copy' button
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # copy doesn't happen
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊0                                                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊01                                               .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
]

## the 'to recipe' button makes it easy to create a function out of a sandbox

scenario copy-a-sandbox-to-recipe-side [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  render-all screen, env, render
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .                                                  ┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # click at left edge of 'copy' button
  assume-console [
    left-click 3, 78
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # it copies into recipe side
  screen-should-contain [
    .                                                                                 run (F4)           .
    .add 1, 1                                          ┊                                                 .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
  # cursor should be at the top left of the recipe side
  assume-console [
    type [0]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .0add 1, 1                                         ┊                                                 .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊0   edit       copy       to recipe    delete    .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊add 1, 1                                         .
    .                                                  ┊2                                                .
    .                                                  ┊─────────────────────────────────────────────────.
    .                                                  ┊                                                 .
  ]
]

after <global-touch> [
  # support 'copy to recipe' button
  {
    copy?:bool <- should-copy-to-recipe? click-row, click-column, env
    break-unless copy?
    modified?:bool <- prepend-sandbox-into-recipe-side click-row, env
    break-unless modified?
    *env <- put *env, sandbox-in-focus?:offset, false
    screen <- render-recipes screen, env, render
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    loop +next-event
  }
]

# some preconditions for attempting to copy a sandbox into the recipe side
def should-copy-to-recipe? click-row:num, click-column:num, env:&:environment -> result:bool [
  local-scope
  load-inputs
  # are we below the sandbox editor?
  click-sandbox-area?:bool <- click-on-sandbox-area? click-row, click-column, env
  return-unless click-sandbox-area?, false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:&:editor <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:num <- get *first-sandbox, left:offset
  sandbox-right-margin:num <- get *first-sandbox, right:offset
  _, _, _, _, recipe-button-left:num, recipe-button-right:num <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  result <- within-range? click-column, recipe-button-left, recipe-button-right
]

def prepend-sandbox-into-recipe-side click-row:num, env:&:environment -> clicked-on-copy-to-recipe-button?:bool, env:&:environment [
  local-scope
  load-inputs
  sandbox:&:sandbox <- find-sandbox env, click-row
  return-unless sandbox, false
  recipe-editor:&:editor <- get *env, recipes:offset
  recipe-data:&:duplex-list:char <- get *recipe-editor, data:offset
  # make the newly inserted code easy to delineate
  newline:char <- copy 10
  insert newline, recipe-data
  insert newline, recipe-data
  # insert code from the selected sandbox
  sandbox-data:text <- get *sandbox, data:offset
  insert recipe-data, sandbox-data
  # reset cursor
  *recipe-editor <- put *recipe-editor, top-of-screen:offset, recipe-data
  *recipe-editor <- put *recipe-editor, before-cursor:offset, recipe-data
  *recipe-editor <- put *recipe-editor, cursor-row:offset, 1
  *recipe-editor <- put *recipe-editor, cursor-column:offset, 0
  return true
]

## the 'copy' button makes it easy to duplicate a sandbox, and thence to
## see code operate in multiple situations

scenario copy-a-sandbox-to-editor [
  local-scope
  trace-until 50/app  # trace too long
  assume-screen 50/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # click at left edge of 'copy' button
  assume-console [
    left-click 3, 19
  ]
  run [
    event-loop screen, console, env
  ]
  # it copies into editor
  screen-should-contain [
    .                               run (F4)           .
    .add 1, 1                                          .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                               run (F4)           .
    .0add 1, 1                                         .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
]

scenario copy-a-sandbox-to-editor-2 [
  local-scope
  trace-until 50/app  # trace too long
  assume-screen 50/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # click at right edge of 'copy' button (just before 'delete')
  assume-console [
    left-click 3, 33
  ]
  run [
    event-loop screen, console, env, resources
  ]
  # it copies into editor
  screen-should-contain [
    .                               run (F4)           .
    .add 1, 1                                          .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                               run (F4)           .
    .0add 1, 1                                         .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
    .                                                  .
    .                                                  .
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
    screen <- update-cursor screen, current-sandbox, env
    loop +next-event
  }
]

# some preconditions for attempting to copy a sandbox
def should-attempt-copy? click-row:num, click-column:num, env:&:environment -> result:bool [
  local-scope
  load-ingredients
  # are we below the sandbox editor?
  click-sandbox-area?:bool <- click-on-sandbox-area? click-row, env
  return-unless click-sandbox-area?, 0/false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:&:editor <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:num <- get *first-sandbox, left:offset
  sandbox-right-margin:num <- get *first-sandbox, right:offset
  _, _, copy-button-left:num, copy-button-right:num, _ <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  copy-button-vertical-area?:bool <- within-range? click-column, copy-button-left, copy-button-right
  return-unless copy-button-vertical-area?, 0/false
  # finally, is sandbox editor empty?
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  result <- empty-editor? current-sandbox
]

def try-copy-sandbox click-row:num, env:&:environment -> clicked-on-copy-button?:bool, env:&:environment [
  local-scope
  load-ingredients
  # identify the sandbox to copy, if the click was actually on the 'copy' button
  sandbox:&:sandbox <- find-sandbox env, click-row
  return-unless sandbox, 0/false
  clicked-on-copy-button? <- copy 1/true
  text:text <- get *sandbox, data:offset
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  current-sandbox <- insert-text current-sandbox, text
  # reset scroll
  *env <- put *env, render-from:offset, -1
]

def find-sandbox env:&:environment, click-row:num -> result:&:sandbox [
  local-scope
  load-ingredients
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

def click-on-sandbox-area? click-row:num, env:&:environment -> result:bool [
  local-scope
  load-ingredients
  first-sandbox:&:sandbox <- get *env, sandbox:offset
  return-unless first-sandbox, 0/false
  first-sandbox-begins:num <- get *first-sandbox, starting-row-on-screen:offset
  result <- greater-or-equal click-row, first-sandbox-begins
]

def empty-editor? editor:&:editor -> result:bool [
  local-scope
  load-ingredients
  head:&:duplex-list:char <- get *editor, data:offset
  first:&:duplex-list:char <- next head
  result <- not first
]

def within-range? x:num, low:num, high:num -> result:bool [
  local-scope
  load-ingredients
  not-too-far-left?:bool <- greater-or-equal x, low
  not-too-far-right?:bool <- lesser-or-equal x, high
  result <- and not-too-far-left? not-too-far-right?
]

scenario copy-fails-if-sandbox-editor-not-empty [
  local-scope
  trace-until 50/app  # trace too long
  assume-screen 50/width, 10/height
  # empty recipes
  assume-resources [
  ]
  env:&:environment <- new-programming-environment resources, screen, [add 1, 1]  # contents of sandbox editor
  # run it
  assume-console [
    press F4
  ]
  event-loop screen, console, env, resources
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  # type something into the sandbox editor, then click on the 'copy' button
  assume-console [
    left-click 2, 20  # put cursor in sandbox editor
    type [0]  # type something
    left-click 3, 20  # click 'copy' button
  ]
  run [
    event-loop screen, console, env
  ]
  # copy doesn't happen
  screen-should-contain [
    .                               run (F4)           .
    .0                                                 .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    event-loop screen, console, env, resources
  ]
  screen-should-contain [
    .                               run (F4)           .
    .01                                                .
    .──────────────────────────────────────────────────.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .──────────────────────────────────────────────────.
    .                                                  .
  ]
]

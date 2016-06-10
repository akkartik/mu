## the 'copy' button makes it easy to duplicate a sandbox, and thence to
## see code operate in multiple situations

scenario copy-a-sandbox-to-editor [
  trace-until 50/app  # trace too long
  assume-screen 50/width, 10/height
  1:address:array:character <- new [add 1, 1]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # click at left edge of 'copy' button
  assume-console [
    left-click 3, 19
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # it copies into editor
  screen-should-contain [
    .                               run (F4)           .
    .add 1, 1                                          .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .0add 1, 1                                         .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
]

scenario copy-a-sandbox-to-editor-2 [
  trace-until 50/app  # trace too long
  assume-screen 50/width, 10/height
  1:address:array:character <- new [add 1, 1]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # click at right edge of 'copy' button
  assume-console [
    left-click 3, 33
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # it copies into editor
  screen-should-contain [
    .                               run (F4)           .
    .add 1, 1                                          .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .0add 1, 1                                         .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
    .                                                  .
    .                                                  .
  ]
]

after <global-touch> [
  # support 'copy' button
  {
    copy?:boolean <- should-attempt-copy? click-row, click-column, env
    break-unless copy?
    copy?, env <- try-copy-sandbox click-row, env
    break-unless copy?
    hide-screen screen
    screen <- render-sandbox-side screen, env
    screen <- update-cursor screen, current-sandbox, env
    show-screen screen
    loop +next-event:label
  }
]

# some preconditions for attempting to copy a sandbox
def should-attempt-copy? click-row:number, click-column:number, env:address:programming-environment-data -> result:boolean [
  local-scope
  load-ingredients
  # are we below the sandbox editor?
  click-sandbox-area?:boolean <- click-on-sandbox-area? click-row, env
  reply-unless click-sandbox-area?, 0/false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:address:editor-data <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:number <- get *first-sandbox, left:offset
  sandbox-right-margin:number <- get *first-sandbox, right:offset
  _, _, copy-button-left:number, copy-button-right:number, _ <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  copy-button-vertical-area?:boolean <- within-range? click-column, copy-button-left, copy-button-right
  reply-unless copy-button-vertical-area?, 0/false
  # finally, is sandbox editor empty?
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  result <- empty-editor? current-sandbox
]

def try-copy-sandbox click-row:number, env:address:programming-environment-data -> clicked-on-copy-button?:boolean, env:address:programming-environment-data [
  local-scope
  load-ingredients
  # identify the sandbox to copy, if the click was actually on the 'copy' button
  sandbox:address:sandbox-data <- find-sandbox env, click-row
  return-unless sandbox, 0/false
  clicked-on-copy-button? <- copy 1/true
  text:address:array:character <- get *sandbox, data:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  current-sandbox <- insert-text current-sandbox, text
  # reset scroll
  *env <- put *env, render-from:offset, -1
]

def find-sandbox env:address:programming-environment-data, click-row:number -> result:address:sandbox-data [
  local-scope
  load-ingredients
  curr-sandbox:address:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr-sandbox
    start:number <- get *curr-sandbox, starting-row-on-screen:offset
    found?:boolean <- equal click-row, start
    return-if found?, curr-sandbox
    curr-sandbox <- get *curr-sandbox, next-sandbox:offset
    loop
  }
  return 0/not-found
]

def click-on-sandbox-area? click-row:number, env:address:programming-environment-data -> result:boolean [
  local-scope
  load-ingredients
  first-sandbox:address:sandbox-data <- get *env, sandbox:offset
  return-unless first-sandbox, 0/false
  first-sandbox-begins:number <- get *first-sandbox, starting-row-on-screen:offset
  result <- greater-or-equal click-row, first-sandbox-begins
]

def empty-editor? editor:address:editor-data -> result:boolean [
  local-scope
  load-ingredients
  head:address:duplex-list:character <- get *editor, data:offset
  first:address:duplex-list:character <- next head
  result <- not first
]

def within-range? x:number, low:number, high:number -> result:boolean [
  local-scope
  load-ingredients
  not-too-far-left?:boolean <- greater-or-equal x, low
  not-too-far-right?:boolean <- lesser-or-equal x, high
  result <- and not-too-far-left? not-too-far-right?
]

scenario copy-fails-if-sandbox-editor-not-empty [
  trace-until 50/app  # trace too long
  assume-screen 50/width, 10/height
  1:address:array:character <- new [add 1, 1]
  assume-console [
    press F4
  ]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # type something into the sandbox editor, then click on the 'copy' button
  assume-console [
    left-click 2, 20  # put cursor in sandbox editor
    type [0]  # type something
    left-click 3, 20  # click 'copy' button
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # copy doesn't happen
  screen-should-contain [
    .                               run (F4)           .
    .0                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  screen-should-contain [
    .                               run (F4)           .
    .01                                                .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

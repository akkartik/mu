## the 'copy' button makes it easy to duplicate a sandbox, and thence to
## see code operate in multiple situations

scenario copy-a-sandbox-to-editor [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # basic recipe
  1:text <- new [ 
recipe foo [
  reply 4
]]
  # run it
  2:text <- new [foo]
  assume-console [
    press F4
  ]
  3:&:programming-environment-data <- new-programming-environment screen:&:screen, 1:text, 2:text
  event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
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
  # click at left edge of 'copy' button
  assume-console [
    left-click 3, 69
  ]
  run [
    event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
  ]
  # it copies into editor
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊0foo                                             .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario copy-a-sandbox-to-editor-2 [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # basic recipe
  1:text <- new [ 
recipe foo [
  reply 4
]]
  # run it
  2:text <- new [foo]
  assume-console [
    press F4
  ]
  3:&:programming-environment-data <- new-programming-environment screen:&:screen, 1:text, 2:text
  event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
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
  # click at right edge of 'copy' button (just before 'delete')
  assume-console [
    left-click 3, 84
  ]
  run [
    event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
  ]
  # it copies into editor
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊foo                                              .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # cursor should be in the right place
  assume-console [
    type [0]
  ]
  run [
    event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊0foo                                             .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
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
    hide-screen screen
    screen <- render-sandbox-side screen, env, render
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    show-screen screen
    loop +next-event:label
  }
]

# some preconditions for attempting to copy a sandbox
def should-attempt-copy? click-row:num, click-column:num, env:&:programming-environment-data -> result:bool [
  local-scope
  load-ingredients
  # are we below the sandbox editor?
  click-sandbox-area?:bool <- click-on-sandbox-area? click-row, click-column, env
  reply-unless click-sandbox-area?, 0/false
  # narrower, is the click in the columns spanning the 'copy' button?
  first-sandbox:&:editor-data <- get *env, current-sandbox:offset
  assert first-sandbox, [!!]
  sandbox-left-margin:num <- get *first-sandbox, left:offset
  sandbox-right-margin:num <- get *first-sandbox, right:offset
  _, _, copy-button-left:num, copy-button-right:num, _ <- sandbox-menu-columns sandbox-left-margin, sandbox-right-margin
  copy-button-vertical-area?:bool <- within-range? click-column, copy-button-left, copy-button-right
  reply-unless copy-button-vertical-area?, 0/false
  # finally, is sandbox editor empty?
  current-sandbox:&:editor-data <- get *env, current-sandbox:offset
  result <- empty-editor? current-sandbox
]

def try-copy-sandbox click-row:num, env:&:programming-environment-data -> clicked-on-copy-button?:bool, env:&:programming-environment-data [
  local-scope
  load-ingredients
  # identify the sandbox to copy, if the click was actually on the 'copy' button
  sandbox:&:sandbox-data <- find-sandbox env, click-row
  return-unless sandbox, 0/false
  clicked-on-copy-button? <- copy 1/true
  text:text <- get *sandbox, data:offset
  current-sandbox:&:editor-data <- get *env, current-sandbox:offset
  current-sandbox <- insert-text current-sandbox, text
  # reset scroll
  *env <- put *env, render-from:offset, -1
  # position cursor in sandbox editor
  *env <- put *env, sandbox-in-focus?:offset, 1/true
]

def find-sandbox env:&:programming-environment-data, click-row:num -> result:&:sandbox-data [
  local-scope
  load-ingredients
  curr-sandbox:&:sandbox-data <- get *env, sandbox:offset
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

def click-on-sandbox-area? click-row:num, click-column:num, env:&:programming-environment-data -> result:bool [
  local-scope
  load-ingredients
  current-sandbox:&:editor-data <- get *env, current-sandbox:offset
  sandbox-left-margin:num <- get *current-sandbox, left:offset
  on-sandbox-side?:bool <- greater-or-equal click-column, sandbox-left-margin
  return-unless on-sandbox-side?, 0/false
  first-sandbox:&:sandbox-data <- get *env, sandbox:offset
  return-unless first-sandbox, 0/false
  first-sandbox-begins:num <- get *first-sandbox, starting-row-on-screen:offset
  result <- greater-or-equal click-row, first-sandbox-begins
]

def empty-editor? editor:&:editor-data -> result:bool [
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
  trace-until 100/app  # trace too long
  assume-screen 100/width, 10/height
  # basic recipe
  1:text <- new [ 
recipe foo [
  reply 4
]]
  # run it
  2:text <- new [foo]
  assume-console [
    press F4
  ]
  3:&:programming-environment-data <- new-programming-environment screen:&:screen, 1:text, 2:text
  event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
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
  # type something into the sandbox editor, then click on the 'copy' button
  assume-console [
    left-click 2, 70  # put cursor in sandbox editor
    type [0]  # type something
    left-click 3, 70  # click 'copy' button
  ]
  run [
    event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
  ]
  # copy doesn't happen
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊0                                                .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # cursor should be in the right place
  assume-console [
    type [1]
  ]
  run [
    event-loop screen:&:screen, console:&:console, 3:&:programming-environment-data
  ]
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊01                                               .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .  reply 4                                         ┊0   edit          copy            delete         .
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

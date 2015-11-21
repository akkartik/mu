## running code from the editor and creating sandboxes
#
# Running code in the sandbox editor prepends its contents to a list of
# (non-editable) sandboxes below the editor, showing the result and a maybe
# few other things.

container programming-environment-data [
  sandbox:address:sandbox-data  # list of sandboxes, from top to bottom
]

container sandbox-data [
  data:address:array:character
  response:address:array:character
  expected-response:address:array:character
  # coordinates to track clicks
  starting-row-on-screen:number
  code-ending-row-on-screen:number  # past end of code
  response-starting-row-on-screen:number
  screen:address:screen  # prints in the sandbox go here
  next-sandbox:address:sandbox-data
]

scenario run-and-show-results [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  # sandbox editor contains an instruction without storing outputs
  1:address:array:character <- new [divide-with-remainder 11, 3]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .divide-with-remainder 11, 3                       .
    .3                                                 .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  screen-should-contain-in-color 7/white, [
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
    .divide-with-remainder 11, 3                       .
    .                                                  .
    .                                                  .
    .                                                  .
    .                                                  .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                  .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .                                                  .
    .3                                                 .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # run another command
  assume-console [
    left-click 1, 80
    type [add 2, 2]
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # check that screen prints both sandboxes
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .divide-with-remainder 11, 3                       .
    .3                                                 .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

after <global-keypress> [
  # F4? load all code and run all sandboxes.
  {
    do-run?:boolean <- equal *k, 65532/F4
    break-unless do-run?
    status:address:array:character <- new [running...  ]
    screen <- update-status screen, status, 245/grey
    error?:boolean, env, screen <- run-sandboxes env, screen
    # F4 might update warnings and results on both sides
    screen <- render-all screen, env
    {
      break-if error?
      status:address:array:character <- new [            ]
      screen <- update-status screen, status, 245/grey
    }
    screen <- update-cursor screen, current-sandbox
    loop +next-event:label
  }
]

recipe run-sandboxes env:address:programming-environment-data, screen:address:screen -> errors-found?:boolean, env:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  errors-found?:boolean, env, screen <- update-recipes env, screen
  reply-if errors-found?
  # check contents of editor
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  {
    sandbox-contents:address:array:character <- editor-contents current-sandbox
    break-unless sandbox-contents
    # if contents exist, first save them
    # run them and turn them into a new sandbox-data
    new-sandbox:address:sandbox-data <- new sandbox-data:type
    data:address:address:array:character <- get-address *new-sandbox, data:offset
    *data <- copy sandbox-contents
    # push to head of sandbox list
    dest:address:address:sandbox-data <- get-address *env, sandbox:offset
    next:address:address:sandbox-data <- get-address *new-sandbox, next-sandbox:offset
    *next <- copy *dest
    *dest <- copy new-sandbox
    # clear sandbox editor
    init:address:address:duplex-list:character <- get-address *current-sandbox, data:offset
    *init <- push 167/§, 0/tail
    top-of-screen:address:address:duplex-list:character <- get-address *current-sandbox, top-of-screen:offset
    *top-of-screen <- copy *init
  }
  # save all sandboxes before running, just in case we die when running
  save-sandboxes env
  # run all sandboxes
  curr:address:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr
    curr <- update-sandbox curr, env
    curr <- get *curr, next-sandbox:offset
    loop
  }
  reply 0/no-errors-found, env/same-as-ingredient:0, screen/same-as-ingredient:1
]

# load code from recipes.mu
# replaced in a later layer (whereupon errors-found? will actually be set)
recipe update-recipes env:address:programming-environment-data, screen:address:screen -> errors-found?:boolean, env:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  in:address:array:character <- restore [recipes.mu]  # newlayer: persistence
  reload in
  errors-found? <- copy 0/false
]

# replaced in a later layer
recipe update-sandbox sandbox:address:sandbox-data -> sandbox:address:sandbox-data [
  local-scope
  load-ingredients
  data:address:array:character <- get *sandbox, data:offset
  response:address:address:array:character <- get-address *sandbox, response:offset
  fake-screen:address:address:screen <- get-address *sandbox, screen:offset
  *response, _, *fake-screen <- run-interactive data
]

recipe update-status screen:address:screen, msg:address:array:character, color:number -> screen:address:screen [
  local-scope
  load-ingredients
  screen <- move-cursor screen, 0, 2
  screen <- print-string screen, msg, color, 238/grey/background
]

recipe save-sandboxes env:address:programming-environment-data [
  local-scope
  load-ingredients
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >/dev/null 2>/dev/null]  # some shells can't handle '>&'
  curr:address:sandbox-data <- get *env, sandbox:offset
  suffix:address:array:character <- new [.out]
  idx:number <- copy 0
  {
    break-unless curr
    data:address:array:character <- get *curr, data:offset
    filename:address:array:character <- integer-to-decimal-string idx
    save filename, data
    {
      expected-response:address:array:character <- get *curr, expected-response:offset
      break-unless expected-response
      filename <- string-append filename, suffix
      save filename, expected-response
    }
    idx <- add idx, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

recipe! render-sandbox-side screen:address:screen, env:address:programming-environment-data -> screen:address:screen [
  local-scope
  load-ingredients
  trace 11, [app], [render sandbox side]
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, column:number, screen, current-sandbox <- render screen, current-sandbox
  clear-screen-from screen, row, column, left, right
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row, env
  clear-rest-of-screen screen, row, left, left, right
]

recipe render-sandboxes screen:address:screen, sandbox:address:sandbox-data, left:number, right:number, row:number -> row:number, screen:address:screen [
  local-scope
  load-ingredients
  env:address:programming-environment-data, _/optional <- next-ingredient
  reply-unless sandbox
  screen-height:number <- screen-height screen
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?:boolean
  # render sandbox menu
  row <- add row, 1
  screen <- move-cursor screen, row, left
  clear-line-delimited screen, left, right
  print-character screen, 120/x, 245/grey
  # save menu row so we can detect clicks to it later
  starting-row:address:number <- get-address *sandbox, starting-row-on-screen:offset
  *starting-row <- copy row
  # render sandbox contents
  row <- add row, 1
  screen <- move-cursor screen, row, left
  sandbox-data:address:array:character <- get *sandbox, data:offset
  row, screen <- render-code-string screen, sandbox-data, left, right, row
  code-ending-row:address:number <- get-address *sandbox, code-ending-row-on-screen:offset
  *code-ending-row <- copy row
  # render sandbox warnings, screen or response, in that order
  response-starting-row:address:number <- get-address *sandbox, response-starting-row-on-screen:offset
  sandbox-response:address:array:character <- get *sandbox, response:offset
  <render-sandbox-results>
  {
    sandbox-screen:address:screen <- get *sandbox, screen:offset
    empty-screen?:boolean <- fake-screen-is-empty? sandbox-screen
    break-if empty-screen?
    row, screen <- render-screen screen, sandbox-screen, left, right, row
  }
  {
    break-unless empty-screen?
    *response-starting-row <- copy row
    <render-sandbox-response>
    row, screen <- render-string screen, sandbox-response, left, right, 245/grey, row
  }
  +render-sandbox-end
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # draw solid line after sandbox
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  # draw next sandbox
  next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
  row, screen <- render-sandboxes screen, next-sandbox, left, right, row
]

# assumes programming environment has no sandboxes; restores them from previous session
recipe restore-sandboxes env:address:programming-environment-data -> env:address:programming-environment-data [
  local-scope
  load-ingredients
  # read all scenarios, pushing them to end of a list of scenarios
  suffix:address:array:character <- new [.out]
  idx:number <- copy 0
  curr:address:address:sandbox-data <- get-address *env, sandbox:offset
  {
    filename:address:array:character <- integer-to-decimal-string idx
    contents:address:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
    # create new sandbox for file
    *curr <- new sandbox-data:type
    data:address:address:array:character <- get-address **curr, data:offset
    *data <- copy contents
    # restore expected output for sandbox if it exists
    {
      filename <- string-append filename, suffix
      contents <- restore filename
      break-unless contents
      expected-response:address:address:array:character <- get-address **curr, expected-response:offset
      *expected-response <- copy contents
    }
    +continue
    idx <- add idx, 1
    curr <- get-address **curr, next-sandbox:offset
    loop
  }
]

# print the fake sandbox screen to 'screen' with appropriate delimiters
# leave cursor at start of next line
recipe render-screen screen:address:screen, sandbox-screen:address:screen, left:number, right:number, row:number -> row:number, screen:address:screen [
  local-scope
  load-ingredients
  reply-unless sandbox-screen
  # print 'screen:'
  header:address:array:character <- new [screen:]
  row <- render-string screen, header, left, right, 245/grey, row
  screen <- move-cursor screen, row, left
  # start printing sandbox-screen
  column:number <- copy left
  s-width:number <- screen-width sandbox-screen
  s-height:number <- screen-height sandbox-screen
  buf:address:array:screen-cell <- get *sandbox-screen, data:offset
  stop-printing:number <- add left, s-width, 3
  max-column:number <- min stop-printing, right
  i:number <- copy 0
  len:number <- length *buf
  screen-height:number <- screen-height screen
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    column <- copy left
    screen <- move-cursor screen, row, column
    # initial leader for each row: two spaces and a '.'
    print-character screen, 32/space, 245/grey
    print-character screen, 32/space, 245/grey
    print-character screen, 46/full-stop, 245/grey
    column <- add left, 3
    {
      # print row
      row-done?:boolean <- greater-or-equal column, max-column
      break-if row-done?
      curr:screen-cell <- index *buf, i
      c:character <- get curr, contents:offset
      color:number <- get curr, color:offset
      {
        # damp whites down to grey
        white?:boolean <- equal color, 7/white
        break-unless white?
        color <- copy 245/grey
      }
      print-character screen, c, color
      column <- add column, 1
      i <- add i, 1
      loop
    }
    # print final '.'
    print-character screen, 46/full-stop, 245/grey
    column <- add column, 1
    {
      # clear rest of current line
      line-done?:boolean <- greater-than column, right
      break-if line-done?
      print-character screen, 32/space
      column <- add column, 1
      loop
    }
    row <- add row, 1
    loop
  }
]

scenario run-instruction-manages-screen-per-sandbox [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # editor contains an instruction
  1:address:array:character <- new [print-integer screen, 4]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  # run the code in the editor
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # check that it prints a little toy screen
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                 x.
    .print-integer screen, 4                           .
    .screen:                                           .
    .  .4                             .                .
    .  .                              .                .
    .  .                              .                .
    .  .                              .                .
    .  .                              .                .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

recipe editor-contents editor:address:editor-data -> result:address:array:character [
  local-scope
  load-ingredients
  buf:address:buffer <- new-buffer 80
  curr:address:duplex-list:character <- get *editor, data:offset
  # skip § sentinel
  assert curr, [editor without data is illegal; must have at least a sentinel]
  curr <- next curr
  reply-unless curr, 0
  {
    break-unless curr
    c:character <- get *curr, value:offset
    buffer-append buf, c
    curr <- next curr
    loop
  }
  result <- buffer-to-array buf
]

scenario editor-provides-edited-contents [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address:screen, 0/left, 10/right
  assume-console [
    left-click 1, 2
    type [def]
  ]
  run [
    editor-event-loop screen:address:screen, console:address:console, 2:address:editor-data
    3:address:array:character <- editor-contents 2:address:editor-data
    4:array:character <- copy *3:address:array:character
  ]
  memory-should-contain [
    4:array:character <- [abdefc]
  ]
]

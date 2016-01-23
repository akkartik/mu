## running code from the editor and creating sandboxes
#
# Running code in the sandbox editor prepends its contents to a list of
# (non-editable) sandboxes below the editor, showing the result and a maybe
# few other things.

recipe! main [
  local-scope
  open-console
  initial-recipe:address:shared:array:character <- restore [recipes.mu]
  initial-sandbox:address:shared:array:character <- new []
  hide-screen 0/screen
  env:address:shared:programming-environment-data <- new-programming-environment 0/screen, initial-recipe, initial-sandbox
  env <- restore-sandboxes env
  render-all 0/screen, env
  event-loop 0/screen, 0/console, env
  # never gets here
]

container programming-environment-data [
  sandbox:address:shared:sandbox-data  # list of sandboxes, from top to bottom
  first-sandbox-to-render:address:shared:sandbox-data  # 0 = display current-sandbox editor
  first-sandbox-index:number
]

container sandbox-data [
  data:address:shared:array:character
  response:address:shared:array:character
  expected-response:address:shared:array:character
  # coordinates to track clicks
  starting-row-on-screen:number
  code-ending-row-on-screen:number  # past end of code
  response-starting-row-on-screen:number
  screen:address:shared:screen  # prints in the sandbox go here
  next-sandbox:address:shared:sandbox-data
]

scenario run-and-show-results [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 15/height
  # recipe editor is empty
  1:address:shared:array:character <- new []
  # sandbox editor contains an instruction without storing outputs
  2:address:shared:array:character <- new [divide-with-remainder 11, 3]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   divide-with-remainder 11, 3                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊                                                 .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # sandbox title in reverse video
  screen-should-contain-in-color 240/dark-grey, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   0                                                .
  ]
  # run another command
  assume-console [
    left-click 1, 80
    type [add 2, 2]
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊1                                               x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

after <global-keypress> [
  # F4? load all code and run all sandboxes.
  {
    do-run?:boolean <- equal *k, 65532/F4
    break-unless do-run?
#?     $log [F4 pressed]
    status:address:shared:array:character <- new [running...       ]
    screen <- update-status screen, status, 245/grey
    error?:boolean, env, screen <- run-sandboxes env, screen
    # F4 might update warnings and results on both sides
#?     $print [render-all begin], 10/newline
    screen <- render-all screen, env
#?     $print [render-all end], 10/newline
    {
      break-if error?
      status:address:shared:array:character <- new [                 ]
      screen <- update-status screen, status, 245/grey
    }
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?, env
    loop +next-event:label
  }
]

recipe run-sandboxes env:address:shared:programming-environment-data, screen:address:shared:screen -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  errors-found?:boolean, env, screen <- update-recipes env, screen
  reply-if errors-found?
  # check contents of right editor (sandbox)
  <run-sandboxes-begin>
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  {
    sandbox-contents:address:shared:array:character <- editor-contents current-sandbox
    break-unless sandbox-contents
    # if contents exist, first save them
    # run them and turn them into a new sandbox-data
    new-sandbox:address:shared:sandbox-data <- new sandbox-data:type
    data:address:address:shared:array:character <- get-address *new-sandbox, data:offset
    *data <- copy sandbox-contents
    # push to head of sandbox list
    dest:address:address:shared:sandbox-data <- get-address *env, sandbox:offset
    next:address:address:shared:sandbox-data <- get-address *new-sandbox, next-sandbox:offset
    *next <- copy *dest
    *dest <- copy new-sandbox
    # clear sandbox editor
    init:address:address:shared:duplex-list:character <- get-address *current-sandbox, data:offset
    *init <- push 167/§, 0/tail
    top-of-screen:address:address:shared:duplex-list:character <- get-address *current-sandbox, top-of-screen:offset
    *top-of-screen <- copy *init
  }
  # save all sandboxes before running, just in case we die when running
  save-sandboxes env
  # run all sandboxes
  curr:address:shared:sandbox-data <- get *env, sandbox:offset
  idx:number <- copy 0
  {
    break-unless curr
    curr <- update-sandbox curr, env, idx
    curr <- get *curr, next-sandbox:offset
    idx <- add idx, 1
    loop
  }
  <run-sandboxes-end>
]

# copy code from recipe editor, persist, load into mu
# replaced in a later layer (whereupon errors-found? will actually be set)
recipe update-recipes env:address:shared:programming-environment-data, screen:address:shared:screen -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  recipes:address:shared:editor-data <- get *env, recipes:offset
  in:address:shared:array:character <- editor-contents recipes
  save [recipes.mu], in  # newlayer: persistence
  reload in
  errors-found? <- copy 0/false
]

# replaced in a later layer
recipe! update-sandbox sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data, idx:number -> sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  data:address:shared:array:character <- get *sandbox, data:offset
  response:address:address:shared:array:character <- get-address *sandbox, response:offset
  fake-screen:address:address:shared:screen <- get-address *sandbox, screen:offset
  *response, _, *fake-screen <- run-interactive data
]

recipe update-status screen:address:shared:screen, msg:address:shared:array:character, color:number -> screen:address:shared:screen [
  local-scope
  load-ingredients
  screen <- move-cursor screen, 0, 2
  screen <- print screen, msg, color, 238/grey/background
]

recipe save-sandboxes env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >/dev/null 2>/dev/null]  # some shells can't handle '>&'
  curr:address:shared:sandbox-data <- get *env, sandbox:offset
  suffix:address:shared:array:character <- new [.out]
  idx:number <- copy 0
  {
    break-unless curr
    data:address:shared:array:character <- get *curr, data:offset
    filename:address:shared:array:character <- to-text idx
    save filename, data
    {
      expected-response:address:shared:array:character <- get *curr, expected-response:offset
      break-unless expected-response
      filename <- append filename, suffix
      save filename, expected-response
    }
    idx <- add idx, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

recipe! render-sandbox-side screen:address:shared:screen, env:address:shared:programming-environment-data -> screen:address:shared:screen [
  local-scope
  load-ingredients
#?   $log [render sandbox side]
  trace 11, [app], [render sandbox side]
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  <render-sandbox-side-special-cases>
  row:number, column:number, screen, current-sandbox <- render screen, current-sandbox
  clear-screen-from screen, row, column, left, right
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:shared:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row, 0
  clear-rest-of-screen screen, row, left, right
]

recipe render-sandboxes screen:address:shared:screen, sandbox:address:shared:sandbox-data, left:number, right:number, row:number, idx:number -> row:number, screen:address:shared:screen, sandbox:address:shared:sandbox-data [
  local-scope
  load-ingredients
#?   $log [render sandbox]
  reply-unless sandbox
  screen-height:number <- screen-height screen
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?:boolean
  # render sandbox menu
  row <- add row, 1
  screen <- move-cursor screen, row, left
  print screen, idx, 240/dark-grey
  clear-line-delimited screen, left, right
  delete-icon:character <- copy 120/x
  print screen, delete-icon, 245/grey
  # save menu row so we can detect clicks to it later
  starting-row:address:number <- get-address *sandbox, starting-row-on-screen:offset
  *starting-row <- copy row
  # render sandbox contents
  row <- add row, 1
  screen <- move-cursor screen, row, left
  sandbox-data:address:shared:array:character <- get *sandbox, data:offset
  row, screen <- render-code screen, sandbox-data, left, right, row
  code-ending-row:address:number <- get-address *sandbox, code-ending-row-on-screen:offset
  *code-ending-row <- copy row
  # render sandbox warnings, screen or response, in that order
  response-starting-row:address:number <- get-address *sandbox, response-starting-row-on-screen:offset
  sandbox-response:address:shared:array:character <- get *sandbox, response:offset
  <render-sandbox-results>
  {
    sandbox-screen:address:shared:screen <- get *sandbox, screen:offset
    empty-screen?:boolean <- fake-screen-is-empty? sandbox-screen
    break-if empty-screen?
    row, screen <- render-screen screen, sandbox-screen, left, right, row
  }
  {
    break-unless empty-screen?
    *response-starting-row <- copy row
    <render-sandbox-response>
    row, screen <- render screen, sandbox-response, left, right, 245/grey, row
  }
  +render-sandbox-end
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?
  # draw solid line after sandbox
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  # draw next sandbox
  next-sandbox:address:shared:sandbox-data <- get *sandbox, next-sandbox:offset
  next-idx:number <- add idx, 1
  row, screen <- render-sandboxes screen, next-sandbox, left, right, row, next-idx
]

# assumes programming environment has no sandboxes; restores them from previous session
recipe restore-sandboxes env:address:shared:programming-environment-data -> env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  # read all scenarios, pushing them to end of a list of scenarios
  suffix:address:shared:array:character <- new [.out]
  idx:number <- copy 0
  curr:address:address:shared:sandbox-data <- get-address *env, sandbox:offset
  {
    filename:address:shared:array:character <- to-text idx
    contents:address:shared:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
    # create new sandbox for file
    *curr <- new sandbox-data:type
    data:address:address:shared:array:character <- get-address **curr, data:offset
    *data <- copy contents
    # restore expected output for sandbox if it exists
    {
      filename <- append filename, suffix
      contents <- restore filename
      break-unless contents
      expected-response:address:address:shared:array:character <- get-address **curr, expected-response:offset
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
recipe render-screen screen:address:shared:screen, sandbox-screen:address:shared:screen, left:number, right:number, row:number -> row:number, screen:address:shared:screen [
  local-scope
  load-ingredients
  reply-unless sandbox-screen
  # print 'screen:'
  header:address:shared:array:character <- new [screen:]
  row <- render screen, header, left, right, 245/grey, row
  screen <- move-cursor screen, row, left
  # start printing sandbox-screen
  column:number <- copy left
  s-width:number <- screen-width sandbox-screen
  s-height:number <- screen-height sandbox-screen
  buf:address:shared:array:screen-cell <- get *sandbox-screen, data:offset
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
    space:character <- copy 32/space
    print screen, space, 245/grey
    print screen, space, 245/grey
    full-stop:character <- copy 46/period
    print screen, full-stop, 245/grey
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
      print screen, c, color
      column <- add column, 1
      i <- add i, 1
      loop
    }
    # print final '.'
    print screen, full-stop, 245/grey
    column <- add column, 1
    {
      # clear rest of current line
      line-done?:boolean <- greater-than column, right
      break-if line-done?
      print screen, space
      column <- add column, 1
      loop
    }
    row <- add row, 1
    loop
  }
]

scenario run-updates-results [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 12/height
  # define a recipe (no indent for the 'add' line below so column numbers are more obvious)
  1:address:shared:array:character <- new [ 
recipe foo [
z:number <- add 2, 2
reply z
]]
  # sandbox editor contains an instruction without storing outputs
  2:address:shared:array:character <- new [foo]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2, 2                              ┊0                                               x.
    .reply z                                           ┊foo                                              .
    .]                                                 ┊4                                                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # make a change (incrementing one of the args to 'add'), then rerun
  assume-console [
    left-click 3, 28  # one past the value of the second arg
    press backspace
    type [3]
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # check that screen updates the result on the right
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2, 3                              ┊0                                               x.
    .reply z                                           ┊foo                                              .
    .]                                                 ┊5                                                .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-manages-screen-per-sandbox [
  trace-until 100/app  # trace too long
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:shared:array:character <- new []
  # right editor contains an instruction
  2:address:shared:array:character <- new [print-integer screen, 4]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  # run the code in the editor
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # check that it prints a little toy screen
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊0                                               x.
    .                                                  ┊print-integer screen, 4                          .
    .                                                  ┊screen:                                          .
    .                                                  ┊  .4                             .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

recipe editor-contents editor:address:shared:editor-data -> result:address:shared:array:character [
  local-scope
  load-ingredients
  buf:address:shared:buffer <- new-buffer 80
  curr:address:shared:duplex-list:character <- get *editor, data:offset
  # skip § sentinel
  assert curr, [editor without data is illegal; must have at least a sentinel]
  curr <- next curr
  reply-unless curr, 0
  {
    break-unless curr
    c:character <- get *curr, value:offset
    buf <- append buf, c
    curr <- next curr
    loop
  }
  result <- buffer-to-array buf
]

scenario editor-provides-edited-contents [
  assume-screen 10/width, 5/height
  1:address:shared:array:character <- new [abc]
  2:address:shared:editor-data <- new-editor 1:address:shared:array:character, screen:address:shared:screen, 0/left, 10/right
  assume-console [
    left-click 1, 2
    type [def]
  ]
  run [
    editor-event-loop screen:address:shared:screen, console:address:shared:console, 2:address:shared:editor-data
    3:address:shared:array:character <- editor-contents 2:address:shared:editor-data
    4:array:character <- copy *3:address:shared:array:character
  ]
  memory-should-contain [
    4:array:character <- [abdefc]
  ]
]

# scrolling through sandboxes

scenario scrolling-down-past-bottom-of-sandbox-editor [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize sandbox side
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new [add 2, 2]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  render-all screen, 3:address:shared:programming-environment-data
  assume-console [
    # create a sandbox
    press F4
    # switch to sandbox editor and type in 2 lines
    press ctrl-n
    type [abc
]
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  screen-should-contain [
    .                              .  # minor: F4 clears menu tooltip in very narrow screens
    .               ┊abc           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊␣             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 2, 2      .
  ]
  # hit 'down' at bottom of sandbox editor
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊␣            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # hit 'up'
  assume-console [
    press up-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  # sandbox editor displays again
  screen-should-contain [
    .                              .  # minor: F4 clears menu tooltip in very narrow screens
    .               ┊abc           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊␣             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 2, 2      .
  ]
]

# down on sandbox side updates first-sandbox-to-render when sandbox editor has cursor at bottom
after <global-keypress> [
  {
    break-unless *sandbox-in-focus?
    down?:boolean <- equal *k, 65516/down-arrow
    break-unless down?
    sandbox-bottom:number <- get *current-sandbox, bottom:offset
    sandbox-cursor:number <- get *current-sandbox, cursor-row:offset
    sandbox-cursor-on-last-line?:boolean <- equal sandbox-bottom, sandbox-cursor
    break-unless sandbox-cursor-on-last-line?
    sandbox:address:shared:sandbox-data <- get *env, sandbox:offset
    break-unless sandbox
    first-sandbox-to-render:address:address:shared:sandbox-data <- get-address *env, first-sandbox-to-render:offset
    # if first-sandbox-to-render is set, slide it down if possible
    {
      break-unless *first-sandbox-to-render
      next:address:shared:sandbox-data <- get **first-sandbox-to-render, next-sandbox:offset
      break-unless next
      *first-sandbox-to-render <- copy next
      first-sandbox-index:address:number <- get-address *env, first-sandbox-index:offset
      *first-sandbox-index <- add *first-sandbox-index, 1
    }
    # if first-sandbox-to-render is not set, set it to first sandbox
    {
      break-if *first-sandbox-to-render
      *first-sandbox-to-render <- copy sandbox
    }
    hide-screen screen
    screen <- render-sandbox-side screen, env
    show-screen screen
    jump +finish-event:label
  }
]

# render-sandbox-side takes first-sandbox-to-render into account
after <render-sandbox-side-special-cases> [
  {
    first-sandbox-to-render:address:shared:sandbox-data <- get *env, first-sandbox-to-render:offset
    break-unless first-sandbox-to-render
    row:number <- copy 1  # skip menu
    draw-horizontal screen, row, left, right, 9473/horizontal-double
    first-sandbox-index:number <- get *env, first-sandbox-index:offset
    row, screen <- render-sandboxes screen, first-sandbox-to-render, left, right, row, first-sandbox-index
    clear-rest-of-screen screen, row, left, right
    reply
  }
]

# update-cursor takes first-sandbox-to-render into account
after <update-cursor-special-cases> [
  {
    break-unless sandbox-in-focus?
    first-sandbox-to-render:address:shared:sandbox-data <- get *env, first-sandbox-to-render:offset
    break-unless first-sandbox-to-render
    cursor-column:number <- get *current-sandbox, left:offset
    screen <- move-cursor screen, 2/row, cursor-column  # highlighted sandbox will always start at row 2
    reply
  }
]

# 'up' on sandbox side is like 'down': updates first-sandbox-to-render when necessary
after <global-keypress> [
  {
    break-unless *sandbox-in-focus?
    up?:boolean <- equal *k, 65517/up-arrow
    break-unless up?
    first-sandbox-to-render:address:address:shared:sandbox-data <- get-address *env, first-sandbox-to-render:offset
    break-unless *first-sandbox-to-render
    {
      break-unless *first-sandbox-to-render
      *first-sandbox-to-render <- previous-sandbox env, *first-sandbox-to-render
      first-sandbox-index:address:number <- get-address *env, first-sandbox-index:offset
      *first-sandbox-index <- subtract *first-sandbox-index, 1
    }
    hide-screen screen
    screen <- render-sandbox-side screen, env
    show-screen screen
    jump +finish-event:label
  }
]

# sandbox belonging to 'env' whose next-sandbox is 'in'
# return 0 if there's no such sandbox, either because 'in' doesn't exist in 'env', or because it's the first sandbox
recipe previous-sandbox env:address:shared:programming-environment-data, in:address:shared:sandbox-data -> out:address:shared:sandbox-data [
  local-scope
  load-ingredients
  curr:address:shared:sandbox-data <- get *env, sandbox:offset
  reply-unless curr, 0/nil
  next:address:shared:sandbox-data <- get *curr, next-sandbox:offset
  {
    reply-unless next, 0/nil
    found?:boolean <- equal next, in
    break-if found?
    curr <- copy next
    next <- get *curr, next-sandbox:offset
    loop
  }
  reply curr
]

scenario scrolling-down-on-recipe-side [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize sandbox side and create a sandbox
  1:address:shared:array:character <- new [ 
]
  # create a sandbox
  2:address:shared:array:character <- new [add 2, 2]
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  render-all screen, 3:address:shared:programming-environment-data
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # hit 'down' in recipe editor
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                              .
    .               ┊              .
    .␣              ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊0            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario scrolling-through-multiple-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new []
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  render-all screen, 3:address:shared:programming-environment-data
  # create 2 sandboxes
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  screen-should-contain [
    .                              .
    .               ┊␣             .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
  ]
  # hit 'down'
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊␣            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
  ]
  # hit 'down' again
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # just second sandbox displayed
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
    .               ┊              .
  ]
  # hit 'down' again
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # no change
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
    .               ┊              .
  ]
  # hit 'up'
  assume-console [
    press up-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # back to displaying both sandboxes without editor
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
    .               ┊━━━━━━━━━━━━━━.
  ]
  # hit 'up' again
  assume-console [
    press up-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  # back to displaying both sandboxes as well as editor
  screen-should-contain [
    .                              .
    .               ┊␣             .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
  ]
  # hit 'up' again
  assume-console [
    press up-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # no change
  screen-should-contain [
    .                              .
    .               ┊␣             .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊1            x.
    .               ┊add 2, 2      .
    .               ┊4             .
  ]
]

## running code from the editor and creating sandboxes
#
# Running code in the sandbox editor prepends its contents to a list of
# (non-editable) sandboxes below the editor, showing the result and a maybe
# few other things.

def! main [
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
  render-from:number
  number-of-sandboxes:number
]

after <programming-environment-initialization> [
  *result <- put *result, render-from:offset, -1
]

container sandbox-data [
  data:address:shared:array:character
  response:address:shared:array:character
  # coordinates to track clicks
  # constraint: will be 0 for sandboxes at positions before env.render-from
  starting-row-on-screen:number
  code-ending-row-on-screen:number  # past end of code
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
    screen <- update-status screen, [running...       ], 245/grey
    error?:boolean, env, screen <- run-sandboxes env, screen
    # F4 might update warnings and results on both sides
    screen <- render-all screen, env
    {
      break-if error?
      screen <- update-status screen, [                 ], 245/grey
    }
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    loop +next-event:label
  }
]

def run-sandboxes env:address:shared:programming-environment-data, screen:address:shared:screen -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  errors-found?:boolean, env, screen <- update-recipes env, screen
  return-if errors-found?
  # check contents of right editor (sandbox)
  <run-sandboxes-begin>
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  {
    sandbox-contents:address:shared:array:character <- editor-contents current-sandbox
    break-unless sandbox-contents
    # if contents exist, first save them
    # run them and turn them into a new sandbox-data
    new-sandbox:address:shared:sandbox-data <- new sandbox-data:type
    *new-sandbox <- put *new-sandbox, data:offset, sandbox-contents
    # push to head of sandbox list
    dest:address:shared:sandbox-data <- get *env, sandbox:offset
    *new-sandbox <- put *new-sandbox, next-sandbox:offset, dest
    *env <- put *env, sandbox:offset, new-sandbox
    # update sandbox count
    sandbox-count:number <- get *env, number-of-sandboxes:offset
    sandbox-count <- add sandbox-count, 1
    *env <- put *env, number-of-sandboxes:offset, sandbox-count
    # clear sandbox editor
    init:address:shared:duplex-list:character <- push 167/§, 0/tail
    *current-sandbox <- put *current-sandbox, data:offset, init
    *current-sandbox <- put *current-sandbox, top-of-screen:offset, init
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
def update-recipes env:address:shared:programming-environment-data, screen:address:shared:screen -> errors-found?:boolean, env:address:shared:programming-environment-data, screen:address:shared:screen [
  local-scope
  load-ingredients
  recipes:address:shared:editor-data <- get *env, recipes:offset
  in:address:shared:array:character <- editor-contents recipes
  save [recipes.mu], in  # newlayer: persistence
  reload in
  errors-found? <- copy 0/false
]

# replaced in a later layer
def! update-sandbox sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data, idx:number -> sandbox:address:shared:sandbox-data, env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  data:address:shared:array:character <- get *sandbox, data:offset
  response:address:shared:array:character, _, fake-screen:address:shared:screen <- run-interactive data
  *sandbox <- put *sandbox, response:offset, response
  *sandbox <- put *sandbox, screen:offset, fake-screen
]

def update-status screen:address:shared:screen, msg:address:shared:array:character, color:number -> screen:address:shared:screen [
  local-scope
  load-ingredients
  screen <- move-cursor screen, 0, 2
  screen <- print screen, msg, color, 238/grey/background
]

def save-sandboxes env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >/dev/null 2>/dev/null]  # some shells can't handle '>&'
  curr:address:shared:sandbox-data <- get *env, sandbox:offset
  idx:number <- copy 0
  {
    break-unless curr
    data:address:shared:array:character <- get *curr, data:offset
    filename:address:shared:array:character <- to-text idx
    save filename, data
    <end-save-sandbox>
    idx <- add idx, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

def! render-sandbox-side screen:address:shared:screen, env:address:shared:programming-environment-data -> screen:address:shared:screen, env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  trace 11, [app], [render sandbox side]
  current-sandbox:address:shared:editor-data <- get *env, current-sandbox:offset
  row:number, column:number <- copy 1, 0
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  # render sandbox editor
  render-from:number <- get *env, render-from:offset
  {
    render-current-sandbox?:boolean <- equal render-from, -1
    break-unless render-current-sandbox?
    row, column, screen, current-sandbox <- render screen, current-sandbox
    clear-screen-from screen, row, column, left, right
    row <- add row, 1
  }
  # render sandboxes
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:shared:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row, render-from
  clear-rest-of-screen screen, row, left, right
]

def render-sandboxes screen:address:shared:screen, sandbox:address:shared:sandbox-data, left:number, right:number, row:number, render-from:number, idx:number -> row:number, screen:address:shared:screen, sandbox:address:shared:sandbox-data [
  local-scope
  load-ingredients
  return-unless sandbox
  screen-height:number <- screen-height screen
  at-bottom?:boolean <- greater-or-equal row, screen-height
  return-if at-bottom?:boolean
  hidden?:boolean <- lesser-than idx, render-from
  {
    break-if hidden?
    # render sandbox menu
    row <- add row, 1
    screen <- move-cursor screen, row, left
    print screen, idx, 240/dark-grey
    clear-line-delimited screen, left, right
    delete-icon:character <- copy 120/x
    print screen, delete-icon, 245/grey
    # save menu row so we can detect clicks to it later
    *sandbox <- put *sandbox, starting-row-on-screen:offset, row
    # render sandbox contents
    row <- add row, 1
    screen <- move-cursor screen, row, left
    sandbox-data:address:shared:array:character <- get *sandbox, data:offset
    row, screen <- render-code screen, sandbox-data, left, right, row
    *sandbox <- put *sandbox, code-ending-row-on-screen:offset, row
    # render sandbox warnings, screen or response, in that order
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
      <render-sandbox-response>
      row, screen <- render screen, sandbox-response, left, right, 245/grey, row
    }
    +render-sandbox-end
    at-bottom?:boolean <- greater-or-equal row, screen-height
    return-if at-bottom?
    # draw solid line after sandbox
    draw-horizontal screen, row, left, right, 9473/horizontal-double
  }
  # if hidden, reset row attributes
  {
    break-unless hidden?
    *sandbox <- put *sandbox, starting-row-on-screen:offset, 0
    *sandbox <- put *sandbox, code-ending-row-on-screen:offset, 0
    <end-render-sandbox-reset-hidden>
  }
  # draw next sandbox
  next-sandbox:address:shared:sandbox-data <- get *sandbox, next-sandbox:offset
  next-idx:number <- add idx, 1
  row, screen <- render-sandboxes screen, next-sandbox, left, right, row, render-from, next-idx
]

# assumes programming environment has no sandboxes; restores them from previous session
def restore-sandboxes env:address:shared:programming-environment-data -> env:address:shared:programming-environment-data [
  local-scope
  load-ingredients
  # read all scenarios, pushing them to end of a list of scenarios
  idx:number <- copy 0
  curr:address:shared:sandbox-data <- copy 0
  prev:address:shared:sandbox-data <- copy 0
  {
    filename:address:shared:array:character <- to-text idx
    contents:address:shared:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
    # create new sandbox for file
    curr <- new sandbox-data:type
    *curr <- put *curr, data:offset, contents
    # restore expected output for sandbox if it exists
    {
      filename <- append filename, [.out]
      contents <- restore filename
      break-unless contents
      <end-restore-sandbox>
    }
    +continue
    idx <- add idx, 1
    {
      break-unless prev
      *prev <- put *prev, next-sandbox:offset, curr
    }
    prev <- copy curr
    loop
  }
  *env <- put *env, sandbox:offset, curr
  # update sandbox count
  *env <- put *env, number-of-sandboxes:offset, idx
]

# print the fake sandbox screen to 'screen' with appropriate delimiters
# leave cursor at start of next line
def render-screen screen:address:shared:screen, sandbox-screen:address:shared:screen, left:number, right:number, row:number -> row:number, screen:address:shared:screen [
  local-scope
  load-ingredients
  return-unless sandbox-screen
  # print 'screen:'
  row <- render screen, [screen:], left, right, 245/grey, row
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
local-scope
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
    .local-scope                                       ┊0                                               x.
    .z:number <- add 2, 2                              ┊foo                                              .
    .reply z                                           ┊4                                                .
    .]                                                 ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
    .                                                  ┊                                                 .
  ]
  # make a change (incrementing one of the args to 'add'), then rerun
  assume-console [
    left-click 4, 28  # one past the value of the second arg
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
    .local-scope                                       ┊0                                               x.
    .z:number <- add 2, 3                              ┊foo                                              .
    .reply z                                           ┊5                                                .
    .]                                                 ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊                                                 .
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

def editor-contents editor:address:shared:editor-data -> result:address:shared:array:character [
  local-scope
  load-ingredients
  buf:address:shared:buffer <- new-buffer 80
  curr:address:shared:duplex-list:character <- get *editor, data:offset
  # skip § sentinel
  assert curr, [editor without data is illegal; must have at least a sentinel]
  curr <- next curr
  return-unless curr, 0
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

# down on sandbox side updates render-from when sandbox editor has cursor at bottom
after <global-keypress> [
  {
    break-unless sandbox-in-focus?
    down?:boolean <- equal *k, 65516/down-arrow
    break-unless down?
    sandbox-bottom:number <- get *current-sandbox, bottom:offset
    sandbox-cursor:number <- get *current-sandbox, cursor-row:offset
    sandbox-cursor-on-last-line?:boolean <- equal sandbox-bottom, sandbox-cursor
    break-unless sandbox-cursor-on-last-line?
    sandbox:address:shared:sandbox-data <- get *env, sandbox:offset
    break-unless sandbox
    # slide down if possible
    {
      render-from:number <- get *env, render-from:offset
      number-of-sandboxes:number <- get *env, number-of-sandboxes:offset
      max:number <- subtract number-of-sandboxes, 1
      at-end?:boolean <- greater-or-equal render-from, max
      jump-if at-end?, +finish-event:label  # render nothing
      render-from <- add render-from, 1
      *env <- put *env, render-from:offset, render-from
    }
    hide-screen screen
    screen <- render-sandbox-side screen, env
    show-screen screen
    jump +finish-event:label
  }
]

# update-cursor takes render-from into account
after <update-cursor-special-cases> [
  {
    break-unless sandbox-in-focus?
    render-from:number <- get *env, render-from:offset
    scrolling?:boolean <- greater-or-equal render-from, 0
    break-unless scrolling?
    cursor-column:number <- get *current-sandbox, left:offset
    screen <- move-cursor screen, 2/row, cursor-column  # highlighted sandbox will always start at row 2
    return
  }
]

# 'up' on sandbox side is like 'down': updates render-from when necessary
after <global-keypress> [
  {
    break-unless sandbox-in-focus?
    up?:boolean <- equal *k, 65517/up-arrow
    break-unless up?
    render-from:number <- get *env, render-from:offset
    at-beginning?:boolean <- equal render-from, -1
    break-if at-beginning?
    render-from <- subtract render-from, 1
    *env <- put *env, render-from:offset, render-from
    hide-screen screen
    screen <- render-sandbox-side screen, env
    show-screen screen
    jump +finish-event:label
  }
]

# sandbox belonging to 'env' whose next-sandbox is 'in'
# return 0 if there's no such sandbox, either because 'in' doesn't exist in 'env', or because it's the first sandbox
def previous-sandbox env:address:shared:programming-environment-data, in:address:shared:sandbox-data -> out:address:shared:sandbox-data [
  local-scope
  load-ingredients
  curr:address:shared:sandbox-data <- get *env, sandbox:offset
  return-unless curr, 0/nil
  next:address:shared:sandbox-data <- get *curr, next-sandbox:offset
  {
    return-unless next, 0/nil
    found?:boolean <- equal next, in
    break-if found?
    curr <- copy next
    next <- get *curr, next-sandbox:offset
    loop
  }
  return curr
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
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  # hit 'down' in recipe editor
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
    4:character/cursor <- copy 9251/␣
    print screen:address:shared:screen, 4:character/cursor
  ]
  # cursor moves down on recipe side
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
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  4:character/cursor <- copy 9251/␣
  print screen:address:shared:screen, 4:character/cursor
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

scenario scrolling-manages-sandbox-index-correctly [
  trace-until 100/app  # trace too long
  assume-screen 30/width, 10/height
  # initialize environment
  1:address:shared:array:character <- new []
  2:address:shared:array:character <- new []
  3:address:shared:programming-environment-data <- new-programming-environment screen:address:shared:screen, 1:address:shared:array:character, 2:address:shared:array:character
  render-all screen, 3:address:shared:programming-environment-data
  # create a sandbox
  assume-console [
    press ctrl-n
    type [add 1, 1]
    press F4
  ]
  event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  screen-should-contain [
    .                              .
    .               ┊              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # hit 'down' and 'up' a couple of times. sandbox index should be stable
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # hit 'up' again
  assume-console [
    press up-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # back to displaying both sandboxes as well as editor
  screen-should-contain [
    .                              .
    .               ┊              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊0            x.
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # hit 'down'
  assume-console [
    press down-arrow
  ]
  run [
    event-loop screen:address:shared:screen, console:address:shared:console, 3:address:shared:programming-environment-data
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                              .
    .               ┊━━━━━━━━━━━━━━.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊0            x.  # no change
    .               ┊add 1, 1      .
    .               ┊2             .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

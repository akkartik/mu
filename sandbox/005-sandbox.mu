## running code from the editor and creating sandboxes
#
# Running code in the sandbox editor prepends its contents to a list of
# (non-editable) sandboxes below the editor, showing the result and a maybe
# few other things.
#
# This layer draws the menubar buttons non-editable sandboxes but they don't
# do anything yet. Later layers implement each button.

container programming-environment-data [
  sandbox:address:sandbox-data  # list of sandboxes, from top to bottom
  render-from:number
  number-of-sandboxes:number
]

after <programming-environment-initialization> [
  *result <- put *result, render-from:offset, -1
]

container sandbox-data [
  data:address:array:character
  response:address:array:character
  # coordinates to track clicks
  # constraint: will be 0 for sandboxes at positions before env.render-from
  starting-row-on-screen:number
  code-ending-row-on-screen:number  # past end of code
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
    .0   edit           copy           delete          .
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
    .                                                  .
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
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
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
    do-run?:boolean <- equal k, 65532/F4
    break-unless do-run?
    screen <- update-status screen, [running...       ], 245/grey
    test-recipes:address:array:character, _/optional <- next-ingredient
    error?:boolean, env, screen <- run-sandboxes env, screen, test-recipes
#?     test-recipes <- copy 0  # abandon
    # F4 might update warnings and results on both sides
    screen <- render-all screen, env, render
    {
      break-if error?
      screen <- update-status screen, [                 ], 245/grey
    }
    screen <- update-cursor screen, current-sandbox, env
    loop +next-event:label
  }
]

def run-sandboxes env:address:programming-environment-data, screen:address:screen, test-recipes:address:array:character -> errors-found?:boolean, env:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  errors-found?:boolean, env, screen <- update-recipes env, screen, test-recipes
  # check contents of editor
  <run-sandboxes-begin>
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  {
    sandbox-contents:address:array:character <- editor-contents current-sandbox
    break-unless sandbox-contents
    # if contents exist, first save them
    # run them and turn them into a new sandbox-data
    new-sandbox:address:sandbox-data <- new sandbox-data:type
    *new-sandbox <- put *new-sandbox, data:offset, sandbox-contents
    # push to head of sandbox list
    dest:address:sandbox-data <- get *env, sandbox:offset
    *new-sandbox <- put *new-sandbox, next-sandbox:offset, dest
    *env <- put *env, sandbox:offset, new-sandbox
    # update sandbox count
    sandbox-count:number <- get *env, number-of-sandboxes:offset
    sandbox-count <- add sandbox-count, 1
    *env <- put *env, number-of-sandboxes:offset, sandbox-count
    # clear sandbox editor
    init:address:duplex-list:character <- push 167/§, 0/tail
    *current-sandbox <- put *current-sandbox, data:offset, init
    *current-sandbox <- put *current-sandbox, top-of-screen:offset, init
  }
  # save all sandboxes before running, just in case we die when running
  save-sandboxes env
  # run all sandboxes
  curr:address:sandbox-data <- get *env, sandbox:offset
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

# load code from recipes.mu, or from test-recipes in tests
# replaced in a later layer (whereupon errors-found? will actually be set)
def update-recipes env:address:programming-environment-data, screen:address:screen, test-recipes:address:array:character -> errors-found?:boolean, env:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  {
    break-if test-recipes
    in:address:array:character <- restore [recipes.mu]  # newlayer: persistence
    reload in
  }
  {
    break-unless test-recipes
    reload test-recipes
  }
  errors-found? <- copy 0/false
]

# replaced in a later layer
def! update-sandbox sandbox:address:sandbox-data, env:address:programming-environment-data, idx:number -> sandbox:address:sandbox-data, env:address:programming-environment-data [
  local-scope
  load-ingredients
  data:address:array:character <- get *sandbox, data:offset
  response:address:array:character, _, fake-screen:address:screen <- run-interactive data
  *sandbox <- put *sandbox, response:offset, response
  *sandbox <- put *sandbox, screen:offset, fake-screen
]

def update-status screen:address:screen, msg:address:array:character, color:number -> screen:address:screen [
  local-scope
  load-ingredients
  screen <- move-cursor screen, 0, 2
  screen <- print screen, msg, color, 238/grey/background
]

def save-sandboxes env:address:programming-environment-data [
  local-scope
  load-ingredients
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >/dev/null 2>/dev/null]  # some shells can't handle '>&'
  curr:address:sandbox-data <- get *env, sandbox:offset
  idx:number <- copy 0
  {
    break-unless curr
    data:address:array:character <- get *curr, data:offset
    filename:address:array:character <- to-text idx
    save filename, data
    <end-save-sandbox>
    idx <- add idx, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

def! render-sandbox-side screen:address:screen, env:address:programming-environment-data, {render-editor: (recipe (address screen) (address editor-data) -> number number (address screen) (address editor-data))} -> screen:address:screen, env:address:programming-environment-data [
  local-scope
  load-ingredients
  trace 11, [app], [render sandbox side]
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  row:number, column:number <- copy 1, 0
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  # render sandbox editor
  render-from:number <- get *env, render-from:offset
  {
    render-current-sandbox?:boolean <- equal render-from, -1
    break-unless render-current-sandbox?
    row, column, screen, current-sandbox <- call render-editor, screen, current-sandbox
    clear-screen-from screen, row, column, left, right
    row <- add row, 1
  }
  # render sandboxes
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row, render-from, 0, env
  clear-rest-of-screen screen, row, left, right
]

def render-sandboxes screen:address:screen, sandbox:address:sandbox-data, left:number, right:number, row:number, render-from:number, idx:number -> row:number, screen:address:screen, sandbox:address:sandbox-data [
  local-scope
  load-ingredients
  env:address:programming-environment-data, _/optional <- next-ingredient
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
    screen <- render-sandbox-menu screen, idx, left, right
    # save menu row so we can detect clicks to it later
    *sandbox <- put *sandbox, starting-row-on-screen:offset, row
    # render sandbox contents
    row <- add row, 1
    screen <- move-cursor screen, row, left
    sandbox-data:address:array:character <- get *sandbox, data:offset
    row, screen <- render-code screen, sandbox-data, left, right, row
    *sandbox <- put *sandbox, code-ending-row-on-screen:offset, row
    # render sandbox warnings, screen or response, in that order
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
      <render-sandbox-response>
      row, screen <- render-text screen, sandbox-response, left, right, 245/grey, row
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
  next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
  next-idx:number <- add idx, 1
  row, screen <- render-sandboxes screen, next-sandbox, left, right, row, render-from, next-idx, env
]

def render-sandbox-menu screen:address:screen, sandbox-index:number, left:number, right:number -> screen:address:screen [
  local-scope
  load-ingredients
  move-cursor-to-column screen, left
  edit-button-left:number, edit-button-right:number, copy-button-left:number, copy-button-right:number, delete-button-left:number <- sandbox-menu-columns left, right
  print screen, sandbox-index, 232/dark-grey, 245/grey
  start-buttons:number <- subtract edit-button-left, 1
  clear-line-until screen, start-buttons, 245/grey
  print screen, [edit], 232/black, 94/background-orange
  clear-line-until screen, edit-button-right, 94/background-orange
  _, col:number <- cursor-position screen
  at-start-of-copy-button?:boolean <- equal col, copy-button-left
  assert at-start-of-copy-button?, [aaa]
  print screen, [copy], 232/black, 58/background-green
  clear-line-until screen, copy-button-right, 58/background-green
  _, col:number <- cursor-position screen
  at-start-of-delete-button?:boolean <- equal col, delete-button-left
  assert at-start-of-delete-button?, [bbb]
  print screen, [delete], 232/black, 52/background-red
  clear-line-until screen, right, 52/background-red
]

# divide up the menu bar for a sandbox into 3 segments, for edit/copy/delete buttons
# delete-button-right == right
# all left/right pairs are inclusive
def sandbox-menu-columns left:number, right:number -> edit-button-left:number, edit-button-right:number, copy-button-left:number, copy-button-right:number, delete-button-left:number [
  local-scope
  load-ingredients
  start-buttons:number <- add left, 4/space-for-sandbox-index
  buttons-space:number <- subtract right, start-buttons
  button-width:number <- divide-with-remainder buttons-space, 3  # integer division
  buttons-wide-enough?:boolean <- greater-or-equal button-width, 8
  assert buttons-wide-enough?, [sandbox must be at least 30 or so characters wide]
  edit-button-left:number <- copy start-buttons
  copy-button-left:number <- add start-buttons, button-width
  edit-button-right:number <- subtract copy-button-left, 1
  delete-button-left:number <- subtract right, button-width
  copy-button-right:number <- subtract delete-button-left, 1
]

# print a text 's' to 'editor' in 'color' starting at 'row'
# clear rest of last line, move cursor to next line
def render-text screen:address:screen, s:address:array:character, left:number, right:number, color:number, row:number -> row:number, screen:address:screen [
  local-scope
  load-ingredients
  return-unless s
  column:number <- copy left
  screen <- move-cursor screen, row, column
  screen-height:number <- screen-height screen
  i:number <- copy 0
  len:number <- length *s
  {
    +next-character
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    c:character <- index *s, i
    {
      # at right? wrap.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      wrap-icon:character <- copy 8617/loop-back-to-left
      print screen, wrap-icon, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      loop +next-character:label  # retry i
    }
    i <- add i, 1
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # clear rest of line in this window
      {
        done?:boolean <- greater-than column, right
        break-if done?
        space:character <- copy 32/space
        print screen, space
        column <- add column, 1
        loop
      }
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      loop +next-character:label
    }
    print screen, c, color
    column <- add column, 1
    loop
  }
  was-at-left?:boolean <- equal column, left
  clear-line-until screen, right
  {
    break-if was-at-left?
    row <- add row, 1
  }
  move-cursor screen, row, left
]

# assumes programming environment has no sandboxes; restores them from previous session
def! restore-sandboxes env:address:programming-environment-data -> env:address:programming-environment-data [
  local-scope
  load-ingredients
  # read all scenarios, pushing them to end of a list of scenarios
  idx:number <- copy 0
  curr:address:sandbox-data <- copy 0
  prev:address:sandbox-data <- copy 0
  {
    filename:address:array:character <- to-text idx
    contents:address:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
                           # todo: handle empty sandbox
    # create new sandbox for file
    curr <- new sandbox-data:type
    *curr <- put *curr, data:offset, contents
    <end-restore-sandbox>
    {
      break-if idx
      *env <- put *env, sandbox:offset, curr
    }
    {
      break-unless idx
      *prev <- put *prev, next-sandbox:offset, curr
    }
    idx <- add idx, 1
    prev <- copy curr
    loop
  }
  # update sandbox count
  *env <- put *env, number-of-sandboxes:offset, idx
]

# print the fake sandbox screen to 'screen' with appropriate delimiters
# leave cursor at start of next line
def render-screen screen:address:screen, sandbox-screen:address:screen, left:number, right:number, row:number -> row:number, screen:address:screen [
  local-scope
  load-ingredients
  return-unless sandbox-screen
  # print 'screen:'
  row <- render-text screen, [screen:], left, right, 245/grey, row
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
  assume-screen 50/width, 12/height
  # define a recipe (no indent for the 'add' line below so column numbers are more obvious)
  1:address:array:character <- new [ 
def foo [
local-scope
z:number <- add 2, 2
return z
]]
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address:screen, 2:address:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data, 1:address:array:character/recipes
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .foo                                               .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # make a change (incrementing one of the args to 'add'), then rerun
  1:address:array:character <- new [ 
def foo [
local-scope
z:number <- add 2, 3
return z
]]
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address:screen, console:address:console, 3:address:programming-environment-data, 1:address:array:character/recipes
  ]
  # check that screen updates the result on the right
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .foo                                               .
    .5                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
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
    .0   edit           copy           delete          .
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

def editor-contents editor:address:editor-data -> result:address:array:character [
  local-scope
  load-ingredients
  buf:address:buffer <- new-buffer 80
  curr:address:duplex-list:character <- get *editor, data:offset
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

# scrolling through sandboxes

scenario scrolling-down-past-bottom-of-sandbox-editor [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # initialize
  1:address:array:character <- new [add 2, 2]
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data, render
  assume-console [
    # create a sandbox
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  screen-should-contain [
    .                               run (F4)           .
    .                                                  .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-down'
  assume-console [
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
    3:character/cursor <- copy 9251/␣
    print screen:address:screen, 3:character/cursor
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .␣   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-up'
  assume-console [
    press page-up
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
    3:character/cursor <- copy 9251/␣
    print screen:address:screen, 3:character/cursor
  ]
  # sandbox editor displays again
  screen-should-contain [
    .                               run (F4)           .
    .␣                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

# page-down updates render-from to scroll sandboxes
after <global-keypress> [
  {
    page-down?:boolean <- equal k, 65518/page-down
    break-unless page-down?
    sandbox:address:sandbox-data <- get *env, sandbox:offset
    break-unless sandbox
    # slide down if possible
    {
      render-from:number <- get *env, render-from:offset
      number-of-sandboxes:number <- get *env, number-of-sandboxes:offset
      max:number <- subtract number-of-sandboxes, 1
      at-end?:boolean <- greater-or-equal render-from, max
      break-if at-end?
      render-from <- add render-from, 1
      *env <- put *env, render-from:offset, render-from
    }
    hide-screen screen
    screen <- render-sandbox-side screen, env, render
    show-screen screen
    jump +finish-event:label
  }
]

# update-cursor takes render-from into account
after <update-cursor-special-cases> [
  {
    render-from:number <- get *env, render-from:offset
    scrolling?:boolean <- greater-or-equal render-from, 0
    break-unless scrolling?
    cursor-column:number <- get *current-sandbox, left:offset
    screen <- move-cursor screen, 2/row, cursor-column  # highlighted sandbox will always start at row 2
    return
  }
]

# 'page-up' is like 'page-down': updates first-sandbox-to-render when necessary
after <global-keypress> [
  {
    page-up?:boolean <- equal k, 65519/page-up
    break-unless page-up?
    render-from:number <- get *env, render-from:offset
    at-beginning?:boolean <- equal render-from, -1
    break-if at-beginning?
    render-from <- subtract render-from, 1
    *env <- put *env, render-from:offset, render-from
    hide-screen screen
    screen <- render-sandbox-side screen, env, render
    show-screen screen
    jump +finish-event:label
  }
]

# sandbox belonging to 'env' whose next-sandbox is 'in'
# return 0 if there's no such sandbox, either because 'in' doesn't exist in 'env', or because it's the first sandbox
def previous-sandbox env:address:programming-environment-data, in:address:sandbox-data -> out:address:sandbox-data [
  local-scope
  load-ingredients
  curr:address:sandbox-data <- get *env, sandbox:offset
  return-unless curr, 0/nil
  next:address:sandbox-data <- get *curr, next-sandbox:offset
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

scenario scrolling-through-multiple-sandboxes [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # initialize environment
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data, render
  # create 2 sandboxes
  assume-console [
    press ctrl-n
    type [add 2, 2]
    press F4
    type [add 1, 1]
    press F4
  ]
  event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  3:character/cursor <- copy 9251/␣
  print screen:address:screen, 3:character/cursor
  screen-should-contain [
    .                               run (F4)           .
    .␣                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-down'
  assume-console [
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
    3:character/cursor <- copy 9251/␣
    print screen:address:screen, 3:character/cursor
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .␣   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-down' again
  assume-console [
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # just second sandbox displayed
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-down' again
  assume-console [
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # no change
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-up'
  assume-console [
    press page-up
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # back to displaying both sandboxes without editor
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-up' again
  assume-console [
    press page-up
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
    3:character/cursor <- copy 9251/␣
    print screen:address:screen, 3:character/cursor
  ]
  # back to displaying both sandboxes as well as editor
  screen-should-contain [
    .                               run (F4)           .
    .␣                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-up' again
  assume-console [
    press page-up
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
    3:character/cursor <- copy 9251/␣
    print screen:address:screen, 3:character/cursor
  ]
  # no change
  screen-should-contain [
    .                               run (F4)           .
    .␣                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .1   edit           copy           delete          .
    .add 2, 2                                          .
    .4                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

scenario scrolling-manages-sandbox-index-correctly [
  trace-until 100/app  # trace too long
  assume-screen 50/width, 20/height
  # initialize environment
  1:address:array:character <- new []
  2:address:programming-environment-data <- new-programming-environment screen:address:screen, 1:address:array:character
  render-all screen, 2:address:programming-environment-data, render
  # create a sandbox
  assume-console [
    press ctrl-n
    type [add 1, 1]
    press F4
  ]
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
  # hit 'page-down' and 'page-up' a couple of times. sandbox index should be stable
  assume-console [
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
  # hit 'page-up' again
  assume-console [
    press page-up
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # back to displaying both sandboxes as well as editor
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
  # hit 'page-down'
  assume-console [
    press page-down
  ]
  run [
    event-loop screen:address:screen, console:address:console, 2:address:programming-environment-data
  ]
  # sandbox editor hidden; first sandbox displayed
  # cursor moves to first sandbox
  screen-should-contain [
    .                               run (F4)           .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .0   edit           copy           delete          .  # no change
    .add 1, 1                                          .
    .2                                                 .
    .━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  .
  ]
]

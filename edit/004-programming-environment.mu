## putting the environment together out of editors
#
# Consists of one editor on the left for recipes and one on the right for the
# sandbox.

def! main [
  local-scope
  open-console
  clear-screen 0/screen  # non-scrolling app
  env:&:environment <- new-programming-environment 0/filesystem, 0/screen
  render-all 0/screen, env, render
  event-loop 0/screen, 0/console, env, 0/filesystem
]

container environment [
  recipes:&:editor
  current-sandbox:&:editor
  sandbox-in-focus?:bool  # false => cursor in recipes; true => cursor in current-sandbox
]

def new-programming-environment resources:&:resources, screen:&:screen, test-sandbox-editor-contents:text -> result:&:environment [
  local-scope
  load-inputs
  width:num <- screen-width screen
  result <- new environment:type
  # recipe editor on the left
  initial-recipe-contents:text <- slurp resources, [lesson/recipes.mu]  # ignore errors
  divider:num, _ <- divide-with-remainder width, 2
  recipes:&:editor <- new-editor initial-recipe-contents, 0/left, divider/right
  # sandbox editor on the right
  sandbox-left:num <- add divider, 1
  current-sandbox:&:editor <- new-editor test-sandbox-editor-contents, sandbox-left, width/right
  *result <- put *result, recipes:offset, recipes
  *result <- put *result, current-sandbox:offset, current-sandbox
  *result <- put *result, sandbox-in-focus?:offset, false
  <programming-environment-initialization>
]

def event-loop screen:&:screen, console:&:console, env:&:environment, resources:&:resources -> screen:&:screen, console:&:console, env:&:environment, resources:&:resources [
  local-scope
  load-inputs
  recipes:&:editor <- get *env, recipes:offset
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  sandbox-in-focus?:bool <- get *env, sandbox-in-focus?:offset
  # if we fall behind we'll stop updating the screen, but then we have to
  # render the entire screen when we catch up.
  # todo: test this
  render-recipes-on-no-more-events?:bool <- copy false
  render-sandboxes-on-no-more-events?:bool <- copy false
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, found?:bool, quit?:bool, console <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    <handle-event>
    # check for global events that will trigger regardless of which editor has focus
    {
      k:num, is-keycode?:bool <- maybe-convert e:event, keycode:variant
      break-unless is-keycode?
      <global-keypress>
    }
    {
      c:char, is-unicode?:bool <- maybe-convert e:event, text:variant
      break-unless is-unicode?
      <global-type>
    }
    # 'touch' event - send to both sides, see what picks it up
    {
      t:touch-event, is-touch?:bool <- maybe-convert e:event, touch:variant
      break-unless is-touch?
      # ignore all but 'left-click' events for now
      # todo: test this
      touch-type:num <- get t, type:offset
      is-left-click?:bool <- equal touch-type, 65513/mouse-left
      loop-unless is-left-click?, +next-event
      click-row:num <- get t, row:offset
      click-column:num <- get t, column:offset
      # later exceptions for non-editor touches will go here
      <global-touch>
      # send to both editors
      _ <- move-cursor recipes, screen, t
      sandbox-in-focus?:bool <- move-cursor current-sandbox, screen, t
      *env <- put *env, sandbox-in-focus?:offset, sandbox-in-focus?
      screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
      loop +next-event
    }
    # 'resize' event - redraw editor
    # todo: test this after supporting resize in assume-console
    {
      r:resize-event, is-resize?:bool <- maybe-convert e:event, resize:variant
      break-unless is-resize?
      env, screen <- resize screen, env
      screen <- render-all screen, env, render-without-moving-cursor
      loop +next-event
    }
    # if it's not global and not a touch event, send to appropriate editor
    {
      sandbox-in-focus?:bool <- get *env, sandbox-in-focus?:offset
      {
        break-if sandbox-in-focus?
        render?:bool <- handle-keyboard-event screen, recipes, e:event
        render-recipes-on-no-more-events? <- or render?, render-recipes-on-no-more-events?
      }
      {
        break-unless sandbox-in-focus?
        render?:bool <- handle-keyboard-event screen, current-sandbox, e:event
        render-sandboxes-on-no-more-events? <- or render?, render-sandboxes-on-no-more-events?
      }
      more-events?:bool <- has-more-events? console
      {
        break-if more-events?
        {
          break-unless render-recipes-on-no-more-events?
          render-recipes-on-no-more-events? <- copy false
          screen <- render-recipes screen, env, render
        }
        {
          break-unless render-sandboxes-on-no-more-events?
          render-sandboxes-on-no-more-events? <- copy false
          screen <- render-sandbox-side screen, env, render
        }
      }
      screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    }
    loop
  }
]

def resize screen:&:screen, env:&:environment -> env:&:environment, screen:&:screen [
  local-scope
  load-inputs
  clear-screen screen  # update screen dimensions
  width:num <- screen-width screen
  divider:num, _ <- divide-with-remainder width, 2
  # update recipe editor
  recipes:&:editor <- get *env, recipes:offset
  right:num <- subtract divider, 1
  *recipes <- put *recipes, right:offset, right
  # reset cursor (later we'll try to preserve its position)
  *recipes <- put *recipes, cursor-row:offset, 1
  *recipes <- put *recipes, cursor-column:offset, 0
  # update sandbox editor
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  left:num <- add divider, 1
  *current-sandbox <- put *current-sandbox, left:offset, left
  right:num <- subtract width, 1
  *current-sandbox <- put *current-sandbox, right:offset, right
  # reset cursor (later we'll try to preserve its position)
  *current-sandbox <- put *current-sandbox, cursor-row:offset, 1
  *current-sandbox <- put *current-sandbox, cursor-column:offset, left
]

# Variant of 'render' that updates cursor-row and cursor-column based on
# before-cursor (rather than the other way around). If before-cursor moves
# off-screen, it resets cursor-row and cursor-column.
def render-without-moving-cursor screen:&:screen, editor:&:editor -> last-row:num, last-column:num, screen:&:screen, editor:&:editor [
  local-scope
  load-inputs
  return-unless editor, 1/top, 0/left
  left:num <- get *editor, left:offset
  screen-height:num <- screen-height screen
  right:num <- get *editor, right:offset
  curr:&:duplex-list:char <- get *editor, top-of-screen:offset
  prev:&:duplex-list:char <- copy curr  # just in case curr becomes null and we can't compute prev
  curr <- next curr
  color:num <- copy 7/white
  row:num <- copy 1/top
  column:num <- copy left
  # save before-cursor
  old-before-cursor:&:duplex-list:char <- get *editor, before-cursor:offset
  # initialze cursor-row/cursor-column/before-cursor to the top of the screen
  # by default
  *editor <- put *editor, cursor-row:offset, row
  *editor <- put *editor, cursor-column:offset, column
  top-of-screen:&:duplex-list:char <- get *editor, top-of-screen:offset
  *editor <- put *editor, before-cursor:offset, top-of-screen
  screen <- move-cursor screen, row, column
  {
    +next-character
    break-unless curr
    off-screen?:bool <- greater-or-equal row, screen-height
    break-if off-screen?
    # if we find old-before-cursor still on the new resized screen, update
    # editor.cursor-row and editor.cursor-column based on
    # old-before-cursor
    {
      at-cursor?:bool <- equal old-before-cursor, prev
      break-unless at-cursor?
      *editor <- put *editor, cursor-row:offset, row
      *editor <- put *editor, cursor-column:offset, column
      *editor <- put *editor, before-cursor:offset, old-before-cursor
    }
    c:char <- get *curr, value:offset
    <character-c-received>
    {
      # newline? move to left rather than 0
      newline?:bool <- equal c, 10/newline
      break-unless newline?
      # clear rest of line in this window
      clear-line-until screen, right
      # skip to next line
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      curr <- next curr
      prev <- next prev
      loop +next-character
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:bool <- equal column, right
      break-unless at-right?
      # print wrap icon
      wrap-icon:char <- copy 8617/loop-back-to-left
      print screen, wrap-icon, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      # don't increment curr
      loop +next-character
    }
    print screen, c, color
    curr <- next curr
    prev <- next prev
    column <- add column, 1
    loop
  }
  # save first character off-screen
  *editor <- put *editor, bottom-of-screen:offset, curr
  *editor <- put *editor, bottom:offset, row
  return row, column
]

scenario point-at-multiple-editors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  assume-resources [
    [lesson/recipes.mu] <- [
      |abc|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [def]  # contents of sandbox editor
  # focus on both sides
  assume-console [
    left-click 1, 1
    left-click 1, 17
  ]
  # check cursor column in each
  run [
    event-loop screen, console, env, resources
    recipes:&:editor <- get *env, recipes:offset
    5:num/raw <- get *recipes, cursor-column:offset
    sandbox:&:editor <- get *env, current-sandbox:offset
    7:num/raw <- get *sandbox, cursor-column:offset
  ]
  memory-should-contain [
    5 <- 1
    7 <- 17
  ]
]

scenario edit-multiple-editors [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  assume-resources [
    [lesson/recipes.mu] <- [
      |abc|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [def]  # contents of sandbox
  render-all screen, env, render
  # type one letter in each of them
  assume-console [
    left-click 1, 1
    type [0]
    left-click 1, 17
    type [1]
  ]
  run [
    event-loop screen, console, env, resources
    recipes:&:editor <- get *env, recipes:offset
    5:num/raw <- get *recipes, cursor-column:offset
    sandbox:&:editor <- get *env, current-sandbox:offset
    7:num/raw <- get *sandbox, cursor-column:offset
  ]
  screen-should-contain [
    .           run (F4)           .  # this line has a different background, but we don't test that yet
    .a0bc           ┊d1ef          .
    .               ┊──────────────.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊              .
    .               ┊              .
  ]
  memory-should-contain [
    5 <- 2  # cursor column of recipe editor
    7 <- 18  # cursor column of sandbox editor
  ]
  # show the cursor at the right window
  run [
    cursor:char <- copy 9251/␣
    print screen, cursor
  ]
  screen-should-contain [
    .           run (F4)           .
    .a0bc           ┊d1␣f          .
    .               ┊──────────────.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊              .
    .               ┊              .
  ]
]

scenario editor-in-focus-keeps-cursor [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 30/width, 5/height
  assume-resources [
    [lesson/recipes.mu] <- [
      |abc|
    ]
  ]
  env:&:environment <- new-programming-environment resources, screen, [def]
  render-all screen, env, render
  # initialize programming environment and highlight cursor
  assume-console []
  run [
    event-loop screen, console, env, resources
    cursor:char <- copy 9251/␣
    print screen, cursor
  ]
  # is cursor at the right place?
  screen-should-contain [
    .           run (F4)           .
    .␣bc            ┊def           .
    .               ┊──────────────.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊              .
    .               ┊              .
  ]
  # now try typing a letter
  assume-console [
    type [z]
  ]
  run [
    event-loop screen, console, env, resources
    cursor:char <- copy 9251/␣
    print screen, cursor
  ]
  # cursor should still be right
  screen-should-contain [
    .           run (F4)           .
    .z␣bc           ┊def           .
    .               ┊──────────────.
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊              .
    .               ┊              .
  ]
]

scenario backspace-in-sandbox-editor-joins-lines [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 30/width, 5/height
  assume-resources [
  ]
  # initialize sandbox side with two lines
  test-sandbox-editor-contents:text <- new [abc
def]
  env:&:environment <- new-programming-environment resources, screen, test-sandbox-editor-contents
  render-all screen, env, render
  screen-should-contain [
    .           run (F4)           .
    .               ┊abc           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊def           .
    .               ┊──────────────.
    .               ┊              .
  ]
  # position cursor at start of second line and hit backspace
  assume-console [
    left-click 2, 16
    press backspace
  ]
  run [
    event-loop screen, console, env, resources
    cursor:char <- copy 9251/␣
    print screen, cursor
  ]
  # cursor moves to end of old line
  screen-should-contain [
    .           run (F4)           .
    .               ┊abc␣ef        .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊──────────────.
    .               ┊              .
  ]
]

type render-recipe = (recipe (address screen) (address editor) -> number number (address screen) (address editor))

def render-all screen:&:screen, env:&:environment, render-editor:render-recipe -> screen:&:screen, env:&:environment [
  local-scope
  load-inputs
  trace 10, [app], [render all]
  # top menu
  trace 11, [app], [render top menu]
  width:num <- screen-width screen
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:num <- subtract width, 20
  button-on-screen?:bool <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  print screen, [ run (F4) ], 255/white, 161/reddish
  # dotted line down the middle
  trace 11, [app], [render divider]
  divider:num, _ <- divide-with-remainder width, 2
  height:num <- screen-height screen
  draw-vertical screen, divider, 1/top, height, 9482/vertical-dotted
  #
  screen <- render-recipes screen, env, render-editor
  screen <- render-sandbox-side screen, env, render-editor
  <end-render-components>  # no early returns permitted
  #
  recipes:&:editor <- get *env, recipes:offset
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  sandbox-in-focus?:bool <- get *env, sandbox-in-focus?:offset
  screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
]

def render-recipes screen:&:screen, env:&:environment, render-editor:render-recipe -> screen:&:screen, env:&:environment [
  local-scope
  load-inputs
  trace 11, [app], [render recipes]
  old-top-idx:num <- save-top-idx screen
  recipes:&:editor <- get *env, recipes:offset
  # render recipes
  left:num <- get *recipes, left:offset
  right:num <- get *recipes, right:offset
  row:num, column:num, screen <- call render-editor, screen, recipes
  <end-render-recipe-components>
  # draw dotted line after recipes
  draw-horizontal screen, row, left, right, 9480/horizontal-dotted
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
  #
  assert-no-scroll screen, old-top-idx
]

# replaced in a later layer
def render-sandbox-side screen:&:screen, env:&:environment, render-editor:render-recipe -> screen:&:screen, env:&:environment [
  local-scope
  load-inputs
  trace 11, [app], [render sandboxes]
  old-top-idx:num <- save-top-idx screen
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  left:num <- get *current-sandbox, left:offset
  right:num <- get *current-sandbox, right:offset
  row:num, column:num, screen, current-sandbox <- call render-editor, screen, current-sandbox
  # draw solid line after code (you'll see why in later layers)
  draw-horizontal screen, row, left, right
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
  #
  assert-no-scroll screen, old-top-idx
]

def update-cursor screen:&:screen, recipes:&:editor, current-sandbox:&:editor, sandbox-in-focus?:bool, env:&:environment -> screen:&:screen [
  local-scope
  load-inputs
  <update-cursor-special-cases>
  {
    break-if sandbox-in-focus?
    cursor-row:num <- get *recipes, cursor-row:offset
    cursor-column:num <- get *recipes, cursor-column:offset
  }
  {
    break-unless sandbox-in-focus?
    cursor-row:num <- get *current-sandbox, cursor-row:offset
    cursor-column:num <- get *current-sandbox, cursor-column:offset
  }
  screen <- move-cursor screen, cursor-row, cursor-column
]

# ctrl-n - switch focus
# todo: test this

after <global-type> [
  {
    switch-side?:bool <- equal c, 14/ctrl-n
    break-unless switch-side?
    sandbox-in-focus?:bool <- get *env, sandbox-in-focus?:offset
    sandbox-in-focus? <- not sandbox-in-focus?
    *env <- put *env, sandbox-in-focus?:offset, sandbox-in-focus?
    screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?, env
    loop +next-event
  }
]

## helpers

def draw-vertical screen:&:screen, col:num, y:num, bottom:num -> screen:&:screen [
  local-scope
  load-inputs
  style:char, style-found?:bool <- next-input
  {
    break-if style-found?
    style <- copy 9474/vertical
  }
  color:num, color-found?:bool <- next-input
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  {
    continue?:bool <- lesser-than y, bottom
    break-unless continue?
    screen <- move-cursor screen, y, col
    print screen, style, color
    y <- add y, 1
    loop
  }
]

scenario backspace-over-text [
  local-scope
  trace-until 100/app  # trace too long
  assume-screen 50/width, 15/height
  # recipes.mu is empty
  assume-resources [
  ]
  # sandbox editor contains an instruction without storing outputs
  env:&:environment <- new-programming-environment resources, screen, []
  # run the code in the editors
  assume-console [
    type [a]
    press backspace
  ]
  run [
    event-loop screen, console, env, resources
    10:num/raw <- get *screen, cursor-row:offset
    11:num/raw <- get *screen, cursor-column:offset
  ]
  memory-should-contain [
    10 <- 1
    11 <- 0
  ]
]

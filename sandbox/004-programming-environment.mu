## putting the environment together out of editors

def! main [
  local-scope
  open-console
  clear-screen 0/screen  # non-scrolling app
  env:&:environment <- new-programming-environment 0/filesystem, 0/screen
  render-all 0/screen, env, render
  event-loop 0/screen, 0/console, env, 0/filesystem
]

container environment [
  current-sandbox:&:editor
]

def new-programming-environment resources:&:resources, screen:&:screen, test-sandbox-editor-contents:text -> result:&:environment [
  local-scope
  load-ingredients
  width:num <- screen-width screen
  result <- new environment:type
  # sandbox editor
  current-sandbox:&:editor <- new-editor test-sandbox-editor-contents, 0/left, width/right
  *result <- put *result, current-sandbox:offset, current-sandbox
  <programming-environment-initialization>
]

def event-loop screen:&:screen, console:&:console, env:&:environment, resources:&:resources -> screen:&:screen, console:&:console, env:&:environment, resources:&:resources [
  local-scope
  load-ingredients
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  # if we fall behind we'll stop updating the screen, but then we have to
  # render the entire screen when we catch up.
  # todo: test this
  render-all-on-no-more-events?:bool <- copy 0/false
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
    # 'touch' event
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
      move-cursor-in-editor screen, current-sandbox, t
      screen <- update-cursor screen, current-sandbox, env
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
    # not global and not a touch event
    {
      render?:bool <- handle-keyboard-event screen, current-sandbox, e:event
      break-unless render?
      # try to batch up rendering if there are more events queued up
      render-all-on-no-more-events? <- or render-all-on-no-more-events?, render?
      more-events?:bool <- has-more-events? console
      {
        break-if more-events?
        break-unless render-all-on-no-more-events?
        render-all-on-no-more-events? <- copy 0/false
        screen <- render-all screen, env, render
      }
      +finish-event
      screen <- update-cursor screen, current-sandbox, env
    }
    loop
  }
]

def resize screen:&:screen, env:&:environment -> env:&:environment, screen:&:screen [
  local-scope
  load-ingredients
  clear-screen screen  # update screen dimensions
  width:num <- screen-width screen
  # update sandbox editor
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  right:num <- subtract width, 1
  *current-sandbox <- put *current-sandbox right:offset, right
  # reset cursor
  *current-sandbox <- put *current-sandbox, cursor-row:offset, 1
  *current-sandbox <- put *current-sandbox, cursor-column:offset, 0
]

# Variant of 'render' that updates cursor-row and cursor-column based on
# before-cursor (rather than the other way around). If before-cursor moves
# off-screen, it resets cursor-row and cursor-column.
def render-without-moving-cursor screen:&:screen, editor:&:editor -> last-row:num, last-column:num, screen:&:screen, editor:&:editor [
  local-scope
  load-ingredients
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

def render-all screen:&:screen, env:&:environment, {render-editor: (recipe (address screen) (address editor) -> number number (address screen) (address editor))} -> screen:&:screen, env:&:environment [
  local-scope
  load-ingredients
  trace 10, [app], [render all]
  old-top-idx:num <- save-top-idx screen
  # top menu
  trace 11, [app], [render top menu]
  width:num <- screen-width screen
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:num <- subtract width, 20
  button-on-screen?:bool <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  print screen, [ run (F4) ], 255/white, 161/reddish
  #
  screen <- render-sandbox-side screen, env, render-editor
  <render-components-end>  # no early returns permitted
  #
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  screen <- update-cursor screen, current-sandbox, env
  #
  assert-no-scroll screen, old-top-idx
]

# replaced in a later layer
def render-sandbox-side screen:&:screen, env:&:environment, {render-editor: (recipe (address screen) (address editor) -> number number (address screen) (address editor))} -> screen:&:screen, env:&:environment [
  local-scope
  load-ingredients
  current-sandbox:&:editor <- get *env, current-sandbox:offset
  left:num <- get *current-sandbox, left:offset
  right:num <- get *current-sandbox, right:offset
  row:num, column:num, screen, current-sandbox <- call render-editor, screen, current-sandbox
  clear-line-until screen, right
  row <- add row, 1
  # draw solid line after code (you'll see why in later layers)
  draw-horizontal screen, row, left, right
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
]

def update-cursor screen:&:screen, current-sandbox:&:editor, env:&:environment -> screen:&:screen [
  local-scope
  load-ingredients
  <update-cursor-special-cases>
  cursor-row:num <- get *current-sandbox, cursor-row:offset
  cursor-column:num <- get *current-sandbox, cursor-column:offset
  screen <- move-cursor screen, cursor-row, cursor-column
]

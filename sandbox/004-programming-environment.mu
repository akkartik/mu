## putting the environment together out of editors

def! main [
  local-scope
  open-console
  initial-sandbox:address:array:character <- new []
  hide-screen 0/screen
  env:address:programming-environment-data <- new-programming-environment 0/screen, initial-sandbox
  env <- restore-sandboxes env
  render-sandbox-side 0/screen, env, render
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  update-cursor 0/screen, current-sandbox, env
  show-screen 0/screen
  event-loop 0/screen, 0/console, env
  # never gets here
]

container programming-environment-data [
  current-sandbox:address:editor-data
]

def new-programming-environment screen:address:screen, initial-sandbox-contents:address:array:character -> result:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  width:number <- screen-width screen
  height:number <- screen-height screen
  # top menu
  result <- new programming-environment-data:type
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  print screen, [ run (F4) ], 255/white, 161/reddish
  # sandbox editor
  current-sandbox:address:editor-data <- new-editor initial-sandbox-contents, screen, 0, width/right
  *result <- put *result, current-sandbox:offset, current-sandbox
  <programming-environment-initialization>
]

def event-loop screen:address:screen, console:address:console, env:address:programming-environment-data -> screen:address:screen, console:address:console, env:address:programming-environment-data [
  local-scope
  load-ingredients
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # if we fall behind we'll stop updating the screen, but then we have to
  # render the entire screen when we catch up.
  # todo: test this
  render-all-on-no-more-events?:boolean <- copy 0/false
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, console, found?:boolean, quit?:boolean <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    <handle-event>
    # check for global events that will trigger regardless of which editor has focus
    {
      k:number, is-keycode?:boolean <- maybe-convert e:event, keycode:variant
      break-unless is-keycode?
      <global-keypress>
    }
    {
      c:character, is-unicode?:boolean <- maybe-convert e:event, text:variant
      break-unless is-unicode?
      <global-type>
    }
    # 'touch' event
    {
      t:touch-event, is-touch?:boolean <- maybe-convert e:event, touch:variant
      break-unless is-touch?
      # ignore all but 'left-click' events for now
      # todo: test this
      touch-type:number <- get t, type:offset
      is-left-click?:boolean <- equal touch-type, 65513/mouse-left
      loop-unless is-left-click?, +next-event:label
      click-row:number <- get t, row:offset
      click-column:number <- get t, column:offset
      # later exceptions for non-editor touches will go here
      <global-touch>
      move-cursor-in-editor screen, current-sandbox, t
      screen <- update-cursor screen, current-sandbox, env
      loop +next-event:label
    }
    # 'resize' event - redraw editor
    # todo: test this after supporting resize in assume-console
    {
      r:resize-event, is-resize?:boolean <- maybe-convert e:event, resize:variant
      break-unless is-resize?
      # if more events, we're still resizing; wait until we stop
      more-events?:boolean <- has-more-events? console
      {
        break-unless more-events?
        render-all-on-no-more-events? <- copy 1/true  # no rendering now, full rendering on some future event
      }
      {
        break-if more-events?
        env, screen <- resize screen, env
        screen <- render-all screen, env, render-without-moving-cursor
        render-all-on-no-more-events? <- copy 0/false  # full render done
      }
      loop +next-event:label
    }
    # if it's not global and not a touch event, send to appropriate editor
    {
      hide-screen screen
      screen, current-sandbox, render?:boolean <- handle-keyboard-event screen, current-sandbox, e:event
      # refresh screen only if no more events
      # if there are more events to process, wait for them to clear up, then make sure you render-all afterward.
      more-events?:boolean <- has-more-events? console
      {
        break-unless more-events?
        render-all-on-no-more-events? <- copy 1/true  # no rendering now, full rendering on some future event
        jump +finish-event:label
      }
      {
        break-if more-events?
        {
          break-unless render-all-on-no-more-events?
          # no more events, and we have to force render
          screen <- render-all screen, env, render
          render-all-on-no-more-events? <- copy 0/false
          jump +finish-event:label
        }
        # no more events, no force render
        {
          break-unless render?
          screen <- render-sandbox-side screen, env, render
          jump +finish-event:label
        }
      }
      +finish-event
      screen <- update-cursor screen, current-sandbox, env
      show-screen screen
    }
    loop
  }
]

def resize screen:address:screen, env:address:programming-environment-data -> env:address:programming-environment-data, screen:address:screen [
  local-scope
  load-ingredients
  clear-screen screen  # update screen dimensions
  width:number <- screen-width screen
  # update sandbox editor
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  right:number <- subtract width, 1
  *current-sandbox <- put *current-sandbox right:offset, right
  # reset cursor
  *current-sandbox <- put *current-sandbox, cursor-row:offset, 1
  *current-sandbox <- put *current-sandbox, cursor-column:offset, 0
]

# Variant of 'render' that updates cursor-row and cursor-column based on
# before-cursor (rather than the other way around). If before-cursor moves
# off-screen, it resets cursor-row and cursor-column.
def render-without-moving-cursor screen:address:screen, editor:address:editor-data -> last-row:number, last-column:number, screen:address:screen, editor:address:editor-data [
  local-scope
  load-ingredients
  return-unless editor, 1/top, 0/left, screen/same-as-ingredient:0, editor/same-as-ingredient:1
  left:number <- get *editor, left:offset
  screen-height:number <- screen-height screen
  right:number <- get *editor, right:offset
  curr:address:duplex-list:character <- get *editor, top-of-screen:offset
  prev:address:duplex-list:character <- copy curr  # just in case curr becomes null and we can't compute prev
  curr <- next curr
  +render-loop-initialization
  color:number <- copy 7/white
  row:number <- copy 1/top
  column:number <- copy left
  # save before-cursor
  old-before-cursor:address:duplex-list:character <- get *editor, before-cursor:offset
  # initialze cursor-row/cursor-column/before-cursor to the top of the screen
  # by default
  *editor <- put *editor, cursor-row:offset, row
  *editor <- put *editor, cursor-column:offset, column
  top-of-screen:address:duplex-list:character <- get *editor, top-of-screen:offset
  *editor <- put *editor, before-cursor:offset, top-of-screen
  screen <- move-cursor screen, row, column
  {
    +next-character
    break-unless curr
    off-screen?:boolean <- greater-or-equal row, screen-height
    break-if off-screen?
    # if we find old-before-cursor still on the new resized screen, update
    # editor-data.cursor-row and editor-data.cursor-column based on
    # old-before-cursor
    {
      at-cursor?:boolean <- equal old-before-cursor, prev
      break-unless at-cursor?
      *editor <- put *editor, cursor-row:offset, row
      *editor <- put *editor, cursor-column:offset, column
      *editor <- put *editor, before-cursor:offset, old-before-cursor
    }
    c:character <- get *curr, value:offset
    <character-c-received>
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # clear rest of line in this window
      clear-line-until screen, right
      # skip to next line
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      curr <- next curr
      prev <- next prev
      loop +next-character:label
    }
    {
      # at right? wrap. even if there's only one more letter left; we need
      # room for clicking on the cursor after it.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      wrap-icon:character <- copy 8617/loop-back-to-left
      print screen, wrap-icon, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      # don't increment curr
      loop +next-character:label
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
  return row, column, screen/same-as-ingredient:0, editor/same-as-ingredient:1
]

def render-all screen:address:screen, env:address:programming-environment-data, {render-editor: (recipe (address screen) (address editor-data) -> number number (address screen) (address editor-data))} -> screen:address:screen, env:address:programming-environment-data [
  local-scope
  load-ingredients
  trace 10, [app], [render all]
  hide-screen screen
  # top menu
  trace 11, [app], [render top menu]
  width:number <- screen-width screen
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  print screen, [ run (F4) ], 255/white, 161/reddish
  #
  screen <- render-sandbox-side screen, env, render-editor
  <render-components-end>
  #
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  screen <- update-cursor screen, current-sandbox, env
  #
  show-screen screen
]

# replaced in a later layer
def render-sandbox-side screen:address:screen, env:address:programming-environment-data, {render-editor: (recipe (address screen) (address editor-data) -> number number (address screen) (address editor-data))} -> screen:address:screen, env:address:programming-environment-data [
  local-scope
  load-ingredients
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, column:number, screen, current-sandbox <- call render-editor, screen, current-sandbox
  clear-line-until screen, right
  row <- add row, 1
  # draw solid line after code (you'll see why in later layers)
  draw-horizontal screen, row, left, right, 9473/horizontal
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
]

def update-cursor screen:address:screen, current-sandbox:address:editor-data, env:address:programming-environment-data -> screen:address:screen [
  local-scope
  load-ingredients
  <update-cursor-special-cases>
  cursor-row:number <- get *current-sandbox, cursor-row:offset
  cursor-column:number <- get *current-sandbox, cursor-column:offset
  screen <- move-cursor screen, cursor-row, cursor-column
]

# print a text 's' to 'editor' in 'color' starting at 'row'
# clear rest of last line, move cursor to next line
def render screen:address:screen, s:address:array:character, left:number, right:number, color:number, row:number -> row:number, screen:address:screen [
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

# like 'render' for texts, but with colorization for comments like in the editor
def render-code screen:address:screen, s:address:array:character, left:number, right:number, row:number -> row:number, screen:address:screen [
  local-scope
  load-ingredients
  return-unless s
  color:number <- copy 7/white
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
    <character-c-received>  # only line different from render
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

# ctrl-l - redraw screen (just in case it printed junk somehow)

after <global-type> [
  {
    redraw-screen?:boolean <- equal c, 12/ctrl-l
    break-unless redraw-screen?
    screen <- render-all screen, env:address:programming-environment-data, render
    sync-screen screen
    loop +next-event:label
  }
]

# dummy
def restore-sandboxes env:address:programming-environment-data -> env:address:programming-environment-data [
  # do nothing; redefined later
]

## putting the environment together out of editors
#
# Consists of one editor on the left for recipes and one on the right for the
# sandbox.

recipe main [
  local-scope
  open-console
  initial-recipe:address:array:character <- restore [recipes.mu]
  initial-sandbox:address:array:character <- new []
  hide-screen 0/screen
  env:address:programming-environment-data <- new-programming-environment 0/screen, initial-recipe, initial-sandbox
  env <- restore-sandboxes env
  render-all 0/screen, env
  event-loop 0/screen, 0/console, env
  # never gets here
]

container programming-environment-data [
  recipes:address:editor-data
  recipe-warnings:address:array:character
  current-sandbox:address:editor-data
  sandbox-in-focus?:boolean  # false => cursor in recipes; true => cursor in current-sandbox
]

recipe new-programming-environment [
  local-scope
  screen:address <- next-ingredient
  initial-recipe-contents:address:array:character <- next-ingredient
  initial-sandbox-contents:address:array:character <- next-ingredient
  width:number <- screen-width screen
  height:number <- screen-height screen
  # top menu
  result:address:programming-environment-data <- new programming-environment-data:type
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  run-button:address:array:character <- new [ run (F4) ]
  print-string screen, run-button, 255/white, 161/reddish
  # dotted line down the middle
  divider:number, _ <- divide-with-remainder width, 2
  draw-vertical screen, divider, 1/top, height, 9482/vertical-dotted
  # recipe editor on the left
  recipes:address:address:editor-data <- get-address *result, recipes:offset
  *recipes <- new-editor initial-recipe-contents, screen, 0/left, divider/right
  # sandbox editor on the right
  new-left:number <- add divider, 1
  current-sandbox:address:address:editor-data <- get-address *result, current-sandbox:offset
  *current-sandbox <- new-editor initial-sandbox-contents, screen, new-left, width/right
  +programming-environment-initialization
  reply result
]

recipe event-loop [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  sandbox-in-focus?:address:boolean <- get-address *env, sandbox-in-focus?:offset
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
      k:address:number <- maybe-convert e:event, keycode:variant
      break-unless k
      <global-keypress>
    }
    {
      c:address:character <- maybe-convert e:event, text:variant
      break-unless c
      <global-type>
    }
    # 'touch' event - send to both sides, see what picks it up
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t
      # ignore all but 'left-click' events for now
      # todo: test this
      touch-type:number <- get *t, type:offset
      is-left-click?:boolean <- equal touch-type, 65513/mouse-left
      loop-unless is-left-click?, +next-event:label
      # later exceptions for non-editor touches will go here
      <global-touch>
      # send to both editors
      _ <- move-cursor-in-editor screen, recipes, *t
      *sandbox-in-focus? <- move-cursor-in-editor screen, current-sandbox, *t
      screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
      loop +next-event:label
    }
    # 'resize' event - redraw editor
    # todo: test this after supporting resize in assume-console
    {
      r:address:resize-event <- maybe-convert e:event, resize:variant
      break-unless r
      # if more events, we're still resizing; wait until we stop
      more-events?:boolean <- has-more-events? console
      {
        break-unless more-events?
        render-all-on-no-more-events? <- copy 1/true  # no rendering now, full rendering on some future event
      }
      {
        break-if more-events?
        env <- resize screen, env
        screen <- render-all screen, env
        render-all-on-no-more-events? <- copy 0/false  # full render done
      }
      loop +next-event:label
    }
    # if it's not global and not a touch event, send to appropriate editor
    {
      hide-screen screen
      {
        break-if *sandbox-in-focus?
        screen, recipes, render?:boolean <- handle-keyboard-event screen, recipes, e:event
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
            screen <- render-all screen, env
            render-all-on-no-more-events? <- copy 0/false
            jump +finish-event:label
          }
          # no more events, no force render
          {
            break-unless render?
            screen <- render-recipes screen, env
            jump +finish-event:label
          }
        }
      }
      {
        break-unless *sandbox-in-focus?
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
            screen <- render-all screen, env
            render-all-on-no-more-events? <- copy 0/false
            jump +finish-event:label
          }
          # no more events, no force render
          {
            break-unless render?
            screen <- render-sandbox-side screen, env
            jump +finish-event:label
          }
        }
      }
      +finish-event
      screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
      show-screen screen
    }
    loop
  }
]

recipe resize [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  clear-screen screen  # update screen dimensions
  width:number <- screen-width screen
  divider:number, _ <- divide-with-remainder width, 2
  # update recipe editor
  recipes:address:editor-data <- get *env, recipes:offset
  right:address:number <- get-address *recipes, right:offset
  *right <- subtract divider, 1
  # reset cursor (later we'll try to preserve its position)
  cursor-row:address:number <- get-address *recipes, cursor-row:offset
  *cursor-row <- copy 1
  cursor-column:address:number <- get-address *recipes, cursor-column:offset
  *cursor-column <- copy 0
  # update sandbox editor
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:address:number <- get-address *current-sandbox, left:offset
  right:address:number <- get-address *current-sandbox, right:offset
  *left <- add divider, 1
  *right <- subtract width, 1
  # reset cursor (later we'll try to preserve its position)
  cursor-row:address:number <- get-address *current-sandbox, cursor-row:offset
  *cursor-row <- copy 1
  cursor-column:address:number <- get-address *current-sandbox, cursor-column:offset
  *cursor-column <- copy *left
  reply env/same-as-ingredient:1
]

scenario point-at-multiple-editors [
  $close-trace  # trace too long
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # focus on both sides
  assume-console [
    left-click 1, 1
    left-click 1, 17
  ]
  # check cursor column in each
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    4:address:editor-data <- get *3:address:programming-environment-data, recipes:offset
    5:number <- get *4:address:editor-data, cursor-column:offset
    6:address:editor-data <- get *3:address:programming-environment-data, current-sandbox:offset
    7:number <- get *6:address:editor-data, cursor-column:offset
  ]
  memory-should-contain [
    5 <- 1
    7 <- 17
  ]
]

scenario edit-multiple-editors [
  $close-trace  # trace too long
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  # type one letter in each of them
  assume-console [
    left-click 1, 1
    type [0]
    left-click 1, 17
    type [1]
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    4:address:editor-data <- get *3:address:programming-environment-data, recipes:offset
    5:number <- get *4:address:editor-data, cursor-column:offset
    6:address:editor-data <- get *3:address:programming-environment-data, current-sandbox:offset
    7:number <- get *6:address:editor-data, cursor-column:offset
  ]
  screen-should-contain [
    .           run (F4)           .  # this line has a different background, but we don't test that yet
    .a0bc           ┊d1ef          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  memory-should-contain [
    5 <- 2  # cursor column of recipe editor
    7 <- 18  # cursor column of sandbox editor
  ]
  # show the cursor at the right window
  run [
    print-character screen:address, 9251/␣/cursor
  ]
  screen-should-contain [
    .           run (F4)           .
    .a0bc           ┊d1␣f          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario multiple-editors-cover-only-their-own-areas [
  $close-trace  # trace too long
  assume-screen 60/width, 10/height
  run [
    1:address:array:character <- new [abc]
    2:address:array:character <- new [def]
    3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
    render-all screen, 3:address:programming-environment-data
  ]
  # divider isn't messed up
  screen-should-contain [
    .                                         run (F4)           .
    .abc                           ┊def                          .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                              ┊                             .
    .                              ┊                             .
  ]
]

scenario editor-in-focus-keeps-cursor [
  $close-trace  # trace too long
  assume-screen 30/width, 5/height
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  # initialize programming environment and highlight cursor
  assume-console []
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # is cursor at the right place?
  screen-should-contain [
    .           run (F4)           .
    .␣bc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # now try typing a letter
  assume-console [
    type [z]
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # cursor should still be right
  screen-should-contain [
    .           run (F4)           .
    .z␣bc           ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

scenario backspace-in-sandbox-editor-joins-lines [
  $close-trace  # trace too long
  assume-screen 30/width, 5/height
  # initialize sandbox side with two lines
  1:address:array:character <- new []
  2:address:array:character <- new [abc
def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  render-all screen, 3:address:programming-environment-data
  screen-should-contain [
    .           run (F4)           .
    .               ┊abc           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊def           .
    .               ┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # position cursor at start of second line and hit backspace
  assume-console [
    left-click 2, 16
    press backspace
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
    print-character screen:address, 9251/␣/cursor
  ]
  # cursor moves to end of old line
  screen-should-contain [
    .           run (F4)           .
    .               ┊abc␣ef        .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

recipe render-all [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
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
  run-button:address:array:character <- new [ run (F4) ]
  print-string screen, run-button, 255/white, 161/reddish
  # error message
  trace 11, [app], [render status]
  recipe-warnings:address:array:character <- get *env, recipe-warnings:offset
  {
    break-unless recipe-warnings
    status:address:array:character <- new [errors found]
    update-status screen, status, 1/red
  }
  # dotted line down the middle
  trace 11, [app], [render divider]
  divider:number, _ <- divide-with-remainder width, 2
  height:number <- screen-height screen
  draw-vertical screen, divider, 1/top, height, 9482/vertical-dotted
  #
  screen <- render-recipes screen, env
  screen <- render-sandbox-side screen, env
  #
  recipes:address:editor-data <- get *env, recipes:offset
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  sandbox-in-focus?:boolean <- get *env, sandbox-in-focus?:offset
  screen <- update-cursor screen, recipes, current-sandbox, sandbox-in-focus?
  #
  show-screen screen
  reply screen/same-as-ingredient:0
]

recipe render-recipes [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  trace 11, [app], [render recipes]
  recipes:address:editor-data <- get *env, recipes:offset
  # render recipes
  left:number <- get *recipes, left:offset
  right:number <- get *recipes, right:offset
  row:number, column:number, screen <- render screen, recipes
  clear-line-delimited screen, column, right
  recipe-warnings:address:array:character <- get *env, recipe-warnings:offset
  {
    # print any warnings
    break-unless recipe-warnings
    row, screen <- render-string screen, recipe-warnings, left, right, 1/red, row
  }
  {
    # no warnings? move to next line
    break-if recipe-warnings
    row <- add row, 1
  }
  # draw dotted line after recipes
  draw-horizontal screen, row, left, right, 9480/horizontal-dotted
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
  reply screen/same-as-ingredient:0
]

# replaced in a later layer
recipe render-sandbox-side [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, column:number, screen, current-sandbox <- render screen, current-sandbox
  clear-line-delimited screen, column, right
  row <- add row, 1
  # draw solid line after recipes (you'll see why in later layers)
  draw-horizontal screen, row, left, right, 9473/horizontal
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
  reply screen/same-as-ingredient:0
]

recipe update-cursor [
  local-scope
  screen:address <- next-ingredient
  recipes:address:editor-data <- next-ingredient
  current-sandbox:address:editor-data <- next-ingredient
  sandbox-in-focus?:boolean <- next-ingredient
  {
    break-if sandbox-in-focus?
    cursor-row:number <- get *recipes, cursor-row:offset
    cursor-column:number <- get *recipes, cursor-column:offset
  }
  {
    break-unless sandbox-in-focus?
    cursor-row:number <- get *current-sandbox, cursor-row:offset
    cursor-column:number <- get *current-sandbox, cursor-column:offset
  }
  screen <- move-cursor screen, cursor-row, cursor-column
  reply screen/same-as-ingredient:0
]

# ctrl-l - redraw screen (just in case it printed junk somehow)

after <global-type> [
  {
    redraw-screen?:boolean <- equal *c, 12/ctrl-l
    break-unless redraw-screen?
    screen <- render-all screen, env:address:programming-environment-data
    sync-screen screen
    loop +next-event:label
  }
]

# ctrl-n - switch focus
# todo: test this

after <global-type> [
  {
    switch-side?:boolean <- equal *c, 14/ctrl-n
    break-unless switch-side?
    *sandbox-in-focus? <- not *sandbox-in-focus?
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    loop +next-event:label
  }
]

# ctrl-x - maximize/unmaximize the side with focus

scenario maximize-side [
  $close-trace  # trace too long
  assume-screen 30/width, 5/height
  # initialize both halves of screen
  1:address:array:character <- new [abc]
  2:address:array:character <- new [def]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  screen <- render-all screen, 3:address:programming-environment-data
  screen-should-contain [
    .           run (F4)           .
    .abc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
  # hit ctrl-x
  assume-console [
    press ctrl-x
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # only left side visible
  screen-should-contain [
    .           run (F4)           .
    .abc                           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈.
    .                              .
  ]
  # hit any key to toggle back
  assume-console [
    press ctrl-x
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  screen-should-contain [
    .           run (F4)           .
    .abc            ┊def           .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━.
    .               ┊              .
  ]
]

#? # ctrl-t - browse trace
#? after <global-type> [
#?   {
#?     browse-trace?:boolean <- equal *c, 20/ctrl-t
#?     break-unless browse-trace?
#?     $browse-trace
#?     screen <- render-all screen, env:address:programming-environment-data
#?     loop +next-event:label
#?   }
#? ]

container programming-environment-data [
  maximized?:boolean
]

after <global-type> [
  {
    maximize?:boolean <- equal *c, 24/ctrl-x
    break-unless maximize?
    screen, console <- maximize screen, console, env:address:programming-environment-data
    loop +next-event:label
  }
]

recipe maximize [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  hide-screen screen
  # maximize one of the sides
  maximized?:address:boolean <- get-address *env, maximized?:offset
  *maximized? <- copy 1/true
  #
  sandbox-in-focus?:boolean <- get *env, sandbox-in-focus?:offset
  {
    break-if sandbox-in-focus?
    editor:address:editor-data <- get *env, recipes:offset
    right:address:number <- get-address *editor, right:offset
    *right <- screen-width screen
    *right <- subtract *right, 1
    screen <- render-recipes screen, env
  }
  {
    break-unless sandbox-in-focus?
    editor:address:editor-data <- get *env, current-sandbox:offset
    left:address:number <- get-address *editor, left:offset
    *left <- copy 0
    screen <- render-sandbox-side screen, env
  }
  show-screen screen
  reply screen/same-as-ingredient:0, console/same-as-ingredient:1
]

# when maximized, wait for any event and simply unmaximize
after <handle-event> [
  {
    maximized?:address:boolean <- get-address *env, maximized?:offset
    break-unless *maximized?
    *maximized? <- copy 0/false
    # undo maximize
    {
      break-if *sandbox-in-focus?
      editor:address:editor-data <- get *env, recipes:offset
      right:address:number <- get-address *editor, right:offset
      *right <- screen-width screen
      *right <- divide *right, 2
      *right <- subtract *right, 1
    }
    {
      break-unless *sandbox-in-focus?
      editor:address:editor-data <- get *env, current-sandbox:offset
      left:address:number <- get-address *editor, left:offset
      *left <- screen-width screen
      *left <- divide *left, 2
      *left <- add *left, 1
    }
    render-all screen, env
    show-screen screen
    loop +next-event:label
  }
]

## helpers

recipe draw-vertical [
  local-scope
  screen:address <- next-ingredient
  col:number <- next-ingredient
  y:number <- next-ingredient
  bottom:number <- next-ingredient
  style:character, style-found?:boolean <- next-ingredient
  {
    break-if style-found?
    style <- copy 9474/vertical
  }
  color:number, color-found?:boolean <- next-ingredient
  {
    # default color to white
    break-if color-found?
    color <- copy 245/grey
  }
  {
    continue?:boolean <- lesser-than y, bottom
    break-unless continue?
    screen <- move-cursor screen, y, col
    print-character screen, style, color
    y <- add y, 1
    loop
  }
]

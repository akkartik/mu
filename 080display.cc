//: Take charge of the text-mode display and console.

//:: Display management

:(before "End Globals")
long long int Display_row = 0, Display_column = 0;
bool Autodisplay = true;

:(before "End Primitive Recipe Declarations")
OPEN_CONSOLE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "open-console", OPEN_CONSOLE);
:(before "End Primitive Recipe Checks")
case OPEN_CONSOLE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case OPEN_CONSOLE: {
  tb_init();
  Display_row = Display_column = 0;
  long long int width = tb_width();
  long long int height = tb_height();
  if (width > 222 || height > 222) tb_shutdown();
  if (width > 222)
    raise << "sorry, mu doesn't support windows wider than 222 characters. Please resize your window.\n" << end();
  if (height > 222)
    raise << "sorry, mu doesn't support windows taller than 222 characters. Please resize your window.\n" << end();
  break;
}

:(before "End Primitive Recipe Declarations")
CLOSE_CONSOLE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "close-console", CLOSE_CONSOLE);
:(before "End Primitive Recipe Checks")
case CLOSE_CONSOLE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CLOSE_CONSOLE: {
  tb_shutdown();
  break;
}

:(before "End Teardown")
tb_shutdown();

:(before "End Primitive Recipe Declarations")
CLEAR_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "clear-display", CLEAR_DISPLAY);
:(before "End Primitive Recipe Checks")
case CLEAR_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CLEAR_DISPLAY: {
  tb_clear();
  Display_row = Display_column = 0;
  break;
}

:(before "End Primitive Recipe Declarations")
SYNC_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "sync-display", SYNC_DISPLAY);
:(before "End Primitive Recipe Checks")
case SYNC_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SYNC_DISPLAY: {
  tb_sync();
  break;
}

:(before "End Primitive Recipe Declarations")
CLEAR_LINE_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "clear-line-on-display", CLEAR_LINE_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case CLEAR_LINE_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CLEAR_LINE_ON_DISPLAY: {
  long long int width = tb_width();
  for (long long int x = Display_column; x < width; ++x) {
    tb_change_cell(x, Display_row, ' ', TB_WHITE, TB_BLACK);
  }
  tb_set_cursor(Display_column, Display_row);
  if (Autodisplay) tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
PRINT_CHARACTER_TO_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "print-character-to-display", PRINT_CHARACTER_TO_DISPLAY);
:(before "End Primitive Recipe Checks")
case PRINT_CHARACTER_TO_DISPLAY: {
  if (inst.ingredients.empty()) {
    raise << maybe(get(Recipe, r).name) << "'print-character-to-display' requires at least one ingredient, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'print-character-to-display' should be a character, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (SIZE(inst.ingredients) > 1) {
    if (!is_mu_number(inst.ingredients.at(1))) {
      raise << maybe(get(Recipe, r).name) << "second ingredient of 'print-character-to-display' should be a foreground color number, but got " << inst.ingredients.at(1).original_string << '\n' << end();
      break;
    }
  }
  if (SIZE(inst.ingredients) > 2) {
    if (!is_mu_number(inst.ingredients.at(2))) {
      raise << maybe(get(Recipe, r).name) << "third ingredient of 'print-character-to-display' should be a background color number, but got " << inst.ingredients.at(2).original_string << '\n' << end();
      break;
    }
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case PRINT_CHARACTER_TO_DISPLAY: {
  int h=tb_height(), w=tb_width();
  long long int height = (h >= 0) ? h : 0;
  long long int width = (w >= 0) ? w : 0;
  long long int c = ingredients.at(0).at(0);
  int color = TB_BLACK;
  if (SIZE(ingredients) > 1) {
    color = ingredients.at(1).at(0);
  }
  int bg_color = TB_BLACK;
  if (SIZE(ingredients) > 2) {
    bg_color = ingredients.at(2).at(0);
    if (bg_color == 0) bg_color = TB_BLACK;
  }
  tb_change_cell(Display_column, Display_row, c, color, bg_color);
  if (c == '\n' || c == '\r') {
    if (Display_row < height-1) {
      Display_column = 0;
      ++Display_row;
      tb_set_cursor(Display_column, Display_row);
      if (Autodisplay) tb_present();
    }
    break;
  }
  if (c == '\b') {
    if (Display_column > 0) {
      tb_change_cell(Display_column-1, Display_row, ' ', color, bg_color);
      --Display_column;
      tb_set_cursor(Display_column, Display_row);
      if (Autodisplay) tb_present();
    }
    break;
  }
  if (Display_column < width-1) {
    ++Display_column;
    tb_set_cursor(Display_column, Display_row);
  }
  if (Autodisplay) tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
CURSOR_POSITION_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "cursor-position-on-display", CURSOR_POSITION_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case CURSOR_POSITION_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CURSOR_POSITION_ON_DISPLAY: {
  products.resize(2);
  products.at(0).push_back(Display_row);
  products.at(1).push_back(Display_column);
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "move-cursor-on-display", MOVE_CURSOR_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case MOVE_CURSOR_ON_DISPLAY: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'move-cursor-on-display' requires two ingredients, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'move-cursor-on-display' should be a row number, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'move-cursor-on-display' should be a column number, but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_ON_DISPLAY: {
  Display_row = ingredients.at(0).at(0);
  Display_column = ingredients.at(1).at(0);
  tb_set_cursor(Display_column, Display_row);
  if (Autodisplay) tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_DOWN_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "move-cursor-down-on-display", MOVE_CURSOR_DOWN_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case MOVE_CURSOR_DOWN_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_DOWN_ON_DISPLAY: {
  int h=tb_height();
  long long int height = (h >= 0) ? h : 0;
  if (Display_row < height-1) {
    Display_row++;
    tb_set_cursor(Display_column, Display_row);
    if (Autodisplay) tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_UP_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "move-cursor-up-on-display", MOVE_CURSOR_UP_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case MOVE_CURSOR_UP_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_UP_ON_DISPLAY: {
  if (Display_row > 0) {
    Display_row--;
    tb_set_cursor(Display_column, Display_row);
    if (Autodisplay) tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_RIGHT_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "move-cursor-right-on-display", MOVE_CURSOR_RIGHT_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case MOVE_CURSOR_RIGHT_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_RIGHT_ON_DISPLAY: {
  int w=tb_width();
  long long int width = (w >= 0) ? w : 0;
  if (Display_column < width-1) {
    Display_column++;
    tb_set_cursor(Display_column, Display_row);
    if (Autodisplay) tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_LEFT_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "move-cursor-left-on-display", MOVE_CURSOR_LEFT_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case MOVE_CURSOR_LEFT_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_LEFT_ON_DISPLAY: {
  if (Display_column > 0) {
    Display_column--;
    tb_set_cursor(Display_column, Display_row);
    if (Autodisplay) tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
DISPLAY_WIDTH,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "display-width", DISPLAY_WIDTH);
:(before "End Primitive Recipe Checks")
case DISPLAY_WIDTH: {
  break;
}
:(before "End Primitive Recipe Implementations")
case DISPLAY_WIDTH: {
  products.resize(1);
  products.at(0).push_back(tb_width());
  break;
}

:(before "End Primitive Recipe Declarations")
DISPLAY_HEIGHT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "display-height", DISPLAY_HEIGHT);
:(before "End Primitive Recipe Checks")
case DISPLAY_HEIGHT: {
  break;
}
:(before "End Primitive Recipe Implementations")
case DISPLAY_HEIGHT: {
  products.resize(1);
  products.at(0).push_back(tb_height());
  break;
}

:(before "End Primitive Recipe Declarations")
HIDE_CURSOR_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "hide-cursor-on-display", HIDE_CURSOR_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case HIDE_CURSOR_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case HIDE_CURSOR_ON_DISPLAY: {
  tb_set_cursor(TB_HIDE_CURSOR, TB_HIDE_CURSOR);
  break;
}

:(before "End Primitive Recipe Declarations")
SHOW_CURSOR_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "show-cursor-on-display", SHOW_CURSOR_ON_DISPLAY);
:(before "End Primitive Recipe Checks")
case SHOW_CURSOR_ON_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SHOW_CURSOR_ON_DISPLAY: {
  tb_set_cursor(Display_row, Display_column);
  break;
}

:(before "End Primitive Recipe Declarations")
HIDE_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "hide-display", HIDE_DISPLAY);
:(before "End Primitive Recipe Checks")
case HIDE_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case HIDE_DISPLAY: {
  Autodisplay = false;
  break;
}

:(before "End Primitive Recipe Declarations")
SHOW_DISPLAY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "show-display", SHOW_DISPLAY);
:(before "End Primitive Recipe Checks")
case SHOW_DISPLAY: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SHOW_DISPLAY: {
  Autodisplay = true;
  tb_present();
  break;
}

//:: Keyboard/mouse management

:(before "End Primitive Recipe Declarations")
WAIT_FOR_SOME_INTERACTION,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "wait-for-some-interaction", WAIT_FOR_SOME_INTERACTION);
:(before "End Primitive Recipe Checks")
case WAIT_FOR_SOME_INTERACTION: {
  break;
}
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_SOME_INTERACTION: {
  tb_event event;
  tb_poll_event(&event);
  break;
}

:(before "End Primitive Recipe Declarations")
CHECK_FOR_INTERACTION,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "check-for-interaction", CHECK_FOR_INTERACTION);
:(before "End Primitive Recipe Checks")
case CHECK_FOR_INTERACTION: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CHECK_FOR_INTERACTION: {
  products.resize(2);  // result and status
  tb_event event;
  int event_type = tb_peek_event(&event, 5/*ms*/);
  if (event_type == TB_EVENT_KEY && event.ch) {
    products.at(0).push_back(/*text event*/0);
    products.at(0).push_back(event.ch);
    products.at(0).push_back(0);
    products.at(0).push_back(0);
    products.at(1).push_back(/*found*/true);
    break;
  }
  // treat keys within ascii as unicode characters
  if (event_type == TB_EVENT_KEY && event.key < 0xff) {
    products.at(0).push_back(/*text event*/0);
    if (event.key == TB_KEY_CTRL_C) {
      tb_shutdown();
      exit(1);
    }
    if (event.key == TB_KEY_BACKSPACE2) event.key = TB_KEY_BACKSPACE;
    if (event.key == TB_KEY_CARRIAGE_RETURN) event.key = TB_KEY_NEWLINE;
    products.at(0).push_back(event.key);
    products.at(0).push_back(0);
    products.at(0).push_back(0);
    products.at(1).push_back(/*found*/true);
    break;
  }
  // keys outside ascii aren't unicode characters but arbitrary termbox inventions
  if (event_type == TB_EVENT_KEY) {
    products.at(0).push_back(/*keycode event*/1);
    products.at(0).push_back(event.key);
    products.at(0).push_back(0);
    products.at(0).push_back(0);
    products.at(1).push_back(/*found*/true);
    break;
  }
  if (event_type == TB_EVENT_MOUSE) {
    products.at(0).push_back(/*touch event*/2);
    products.at(0).push_back(event.key);  // which button, etc.
    products.at(0).push_back(event.y);  // row
    products.at(0).push_back(event.x);  // column
    products.at(1).push_back(/*found*/true);
    break;
  }
  if (event_type == TB_EVENT_RESIZE) {
    products.at(0).push_back(/*resize event*/3);
    products.at(0).push_back(event.w);  // width
    products.at(0).push_back(event.h);  // height
    products.at(0).push_back(0);
    products.at(1).push_back(/*found*/true);
    break;
  }
  assert(event_type == 0);
  products.at(0).push_back(0);
  products.at(0).push_back(0);
  products.at(0).push_back(0);
  products.at(0).push_back(0);
  products.at(1).push_back(/*found*/false);
  break;
}

:(before "End Primitive Recipe Declarations")
INTERACTIONS_LEFT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "interactions-left?", INTERACTIONS_LEFT);
:(before "End Primitive Recipe Checks")
case INTERACTIONS_LEFT: {
  break;
}
:(before "End Primitive Recipe Implementations")
case INTERACTIONS_LEFT: {
  products.resize(1);
  products.at(0).push_back(tb_event_ready());
  break;
}

//: a hack to make edit.mu more responsive

:(before "End Primitive Recipe Declarations")
CLEAR_DISPLAY_FROM,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "clear-display-from", CLEAR_DISPLAY_FROM);
:(before "End Primitive Recipe Checks")
case CLEAR_DISPLAY_FROM: {
  break;
}
:(before "End Primitive Recipe Implementations")
case CLEAR_DISPLAY_FROM: {
  // todo: error checking
  int row = ingredients.at(0).at(0);
  int column = ingredients.at(1).at(0);
  int left = ingredients.at(2).at(0);
  int right = ingredients.at(3).at(0);
  int height=tb_height();
  for (; row < height; ++row, column=left) {  // start column from left in every inner loop except first
    for (; column <= right; ++column) {
      tb_change_cell(column, row, ' ', TB_WHITE, TB_BLACK);
    }
  }
  if (Autodisplay) tb_present();
  break;
}

//: Take charge of the text-mode display and keyboard.

// uncomment to debug console programs
:(before "End Globals")
//? ofstream LOG("log.txt");

//:: Display management

:(before "End Globals")
index_t Display_row = 0, Display_column = 0;

:(before "End Primitive Recipe Declarations")
SWITCH_TO_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["switch-to-display"] = SWITCH_TO_DISPLAY;
:(before "End Primitive Recipe Implementations")
case SWITCH_TO_DISPLAY: {
  tb_init();
  Display_row = Display_column = 0;
  break;
}

:(before "End Primitive Recipe Declarations")
RETURN_TO_CONSOLE,
:(before "End Primitive Recipe Numbers")
Recipe_number["return-to-console"] = RETURN_TO_CONSOLE;
:(before "End Primitive Recipe Implementations")
case RETURN_TO_CONSOLE: {
  tb_shutdown();
//?   Trace_stream->dump_layer = "all"; //? 1
  break;
}

:(before "End Teardown")
tb_shutdown();

:(before "End Primitive Recipe Declarations")
CLEAR_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["clear-display"] = CLEAR_DISPLAY;
:(before "End Primitive Recipe Implementations")
case CLEAR_DISPLAY: {
  tb_clear();
  Display_row = Display_column = 0;
  break;
}

:(before "End Primitive Recipe Declarations")
CLEAR_LINE_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["clear-line-on-display"] = CLEAR_LINE_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case CLEAR_LINE_ON_DISPLAY: {
  size_t width = tb_width();
  for (index_t x = Display_column; x < width; ++x) {
    tb_change_cell(x, Display_row, ' ', TB_WHITE, TB_DEFAULT);
  }
  tb_set_cursor(Display_column, Display_row);
  tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
PRINT_CHARACTER_TO_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["print-character-to-display"] = PRINT_CHARACTER_TO_DISPLAY;
:(before "End Primitive Recipe Implementations")
case PRINT_CHARACTER_TO_DISPLAY: {
  int h=tb_height(), w=tb_width();
  size_t height = (h >= 0) ? h : 0;
  size_t width = (w >= 0) ? w : 0;
  assert(ingredients.at(0).size() == 1);  // scalar
  long long int c = value(ingredients.at(0).at(0));  // unicode code-point will probably always be a positive integer
  if (c == '\n' || c == '\r') {
    if (Display_row < height-1) {
      Display_column = 0;
      ++Display_row;
      tb_set_cursor(Display_column, Display_row);
      tb_present();
    }
    break;
  }
  if (c == '\b') {
    if (Display_column > 0) {
      tb_change_cell(Display_column-1, Display_row, ' ', TB_WHITE, TB_DEFAULT);
      --Display_column;
      tb_set_cursor(Display_column, Display_row);
      tb_present();
    }
    break;
  }
  tb_change_cell(Display_column, Display_row, c, TB_WHITE, TB_DEFAULT);
  if (Display_column < width-1) {
    ++Display_column;
    tb_set_cursor(Display_column, Display_row);
  }
  tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
CURSOR_POSITION_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["cursor-position-on-display"] = CURSOR_POSITION_ON_DISPLAY;
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
Recipe_number["move-cursor-on-display"] = MOVE_CURSOR_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_ON_DISPLAY: {
  assert(ingredients.at(0).size() == 1);  // scalar
  Display_row = ingredients.at(0).at(0);  // screen coordinate will always be a non-negative integer
  assert(ingredients.at(1).size() == 1);  // scalar
  Display_column = ingredients.at(1).at(0);  // screen coordinate will always be a non-negative integer
  tb_set_cursor(Display_column, Display_row);
  tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_DOWN_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-down-on-display"] = MOVE_CURSOR_DOWN_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_DOWN_ON_DISPLAY: {
  int h=tb_height();
  size_t height = (h >= 0) ? h : 0;
  if (Display_row < height-1) {
    Display_row++;
    tb_set_cursor(Display_column, Display_row);
    tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_UP_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-up-on-display"] = MOVE_CURSOR_UP_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_UP_ON_DISPLAY: {
  if (Display_row > 0) {
    Display_row--;
    tb_set_cursor(Display_column, Display_row);
    tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_RIGHT_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-right-on-display"] = MOVE_CURSOR_RIGHT_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_RIGHT_ON_DISPLAY: {
  int w=tb_width();
  size_t width = (w >= 0) ? w : 0;
  if (Display_column < width-1) {
    Display_column++;
    tb_set_cursor(Display_column, Display_row);
    tb_present();
  }
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_LEFT_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-left-on-display"] = MOVE_CURSOR_LEFT_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_LEFT_ON_DISPLAY: {
  if (Display_column > 0) {
    Display_column--;
    tb_set_cursor(Display_column, Display_row);
    tb_present();
  }
  break;
}

//:: Keyboard management

:(before "End Primitive Recipe Declarations")
WAIT_FOR_KEY_FROM_KEYBOARD,
:(before "End Primitive Recipe Numbers")
Recipe_number["wait-for-key-from-keyboard"] = WAIT_FOR_KEY_FROM_KEYBOARD;
:(before "End Primitive Recipe Implementations")
case WAIT_FOR_KEY_FROM_KEYBOARD: {
  struct tb_event event;
  do {
    tb_poll_event(&event);
  } while (event.type != TB_EVENT_KEY);
  products.resize(1);
  products.at(0).push_back(event.ch);
  break;
}

:(before "End Primitive Recipe Declarations")
READ_KEY_FROM_KEYBOARD,
:(before "End Primitive Recipe Numbers")
Recipe_number["read-key-from-keyboard"] = READ_KEY_FROM_KEYBOARD;
:(before "End Primitive Recipe Implementations")
case READ_KEY_FROM_KEYBOARD: {
  struct tb_event event;
  int event_type = tb_peek_event(&event, 5/*ms*/);
  long long int result = 0;
  long long int found = false;
//?   cerr << event_type << '\n'; //? 1
  if (event_type == TB_EVENT_KEY) {
    if (event.key == TB_KEY_CTRL_C) tb_shutdown(), exit(1);
    if (event.key == TB_KEY_BACKSPACE2) event.key = TB_KEY_BACKSPACE;
    result = event.key ? event.key : event.ch;
    found = true;
  }
  products.resize(2);
  products.at(0).push_back(result);
  products.at(1).push_back(found);
  break;
}

:(before "End Includes")
#include"termbox/termbox.h"

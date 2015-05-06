//: Take charge of the text-mode display and keyboard.

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
  break;
}

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
  vector<long long int> arg = read_memory(current_instruction().ingredients[0]);
  int h=tb_height(), w=tb_width();
  size_t height = (h >= 0) ? h : 0;
  size_t width = (w >= 0) ? w : 0;
  if (arg[0] == '\n') {
    if (Display_row < height) {
      Display_column = 0;
      ++Display_row;
      tb_set_cursor(Display_column, Display_row);
      tb_present();
    }
    break;
  }
  tb_change_cell(Display_column, Display_row, arg[0], TB_WHITE, TB_DEFAULT);
  if (Display_column < width) {
    Display_column++;
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
  vector<long long int> row;
  row.push_back(Display_row);
  write_memory(current_instruction().products[0], row);
  vector<long long int> column;
  column.push_back(Display_column);
  write_memory(current_instruction().products[1], column);
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-on-display"] = MOVE_CURSOR_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_ON_DISPLAY: {
  vector<long long int> row = read_memory(current_instruction().ingredients[0]);
  vector<long long int> column = read_memory(current_instruction().ingredients[1]);
  Display_row = row[0];
  Display_column = column[0];
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
  Display_row++;
  tb_set_cursor(Display_column, Display_row);
  tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_UP_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-up-on-display"] = MOVE_CURSOR_UP_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_UP_ON_DISPLAY: {
  Display_row--;
  tb_set_cursor(Display_column, Display_row);
  tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_RIGHT_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-right-on-display"] = MOVE_CURSOR_RIGHT_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_RIGHT_ON_DISPLAY: {
  Display_column++;
  tb_set_cursor(Display_column, Display_row);
  tb_present();
  break;
}

:(before "End Primitive Recipe Declarations")
MOVE_CURSOR_LEFT_ON_DISPLAY,
:(before "End Primitive Recipe Numbers")
Recipe_number["move-cursor-left-on-display"] = MOVE_CURSOR_LEFT_ON_DISPLAY;
:(before "End Primitive Recipe Implementations")
case MOVE_CURSOR_LEFT_ON_DISPLAY: {
  Display_column--;
  tb_set_cursor(Display_column, Display_row);
  tb_present();
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
  vector<long long int> result;
  result.push_back(event.ch);
  write_memory(current_instruction().products[0], result);
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
  vector<long long int> result;
  vector<long long int> found;
  if (event_type != TB_EVENT_KEY) {
    result.push_back(0);
    found.push_back(false);
  }
  else {
    result.push_back(event.ch);
    found.push_back(true);
  }
  write_memory(current_instruction().products[0], result);
  write_memory(current_instruction().products[1], found);
  break;
}

:(before "End Includes")
#include"termbox/termbox.h"

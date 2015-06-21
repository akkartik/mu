:(before "End Primitive Recipe Declarations")
READ_KEYBOARD_OR_MOUSE_EVENT,
:(before "End Primitive Recipe Numbers")
Recipe_number["read-keyboard-or-mouse-event"] = READ_KEYBOARD_OR_MOUSE_EVENT;
:(before "End Primitive Recipe Implementations")
case READ_KEYBOARD_OR_MOUSE_EVENT: {
  products.resize(2);  // result and status
  tb_event event;
  int event_type = tb_peek_event(&event, 5/*ms*/);
  if (event_type == TB_EVENT_KEY) {
    products.at(0).push_back(/*keyboard event*/0);
    long long key = event.key ? event.key : event.ch;
    if (key == TB_KEY_CTRL_C) tb_shutdown(), exit(1);
    if (key == TB_KEY_BACKSPACE2) key = TB_KEY_BACKSPACE;
    if (key == TB_KEY_CARRIAGE_RETURN) key = TB_KEY_NEWLINE;
    products.at(0).push_back(key);
    products.at(0).push_back(0);
    products.at(0).push_back(0);
    products.at(1).push_back(/*found*/true);
    break;
  }
  if (event_type == TB_EVENT_MOUSE) {
    products.at(0).push_back(/*mouse event*/1);
//?     tb_shutdown(); //? 1
//?     cerr << event_type << ' ' << event.key << ' ' << event.y << ' ' << event.x << '\n'; //? 1
//?     exit(0); //? 1
    products.at(0).push_back(event.key);  // which button, etc.
    products.at(0).push_back(event.y);  // row
    products.at(0).push_back(event.x);  // column
    products.at(1).push_back(/*found*/true);
    break;
  }
  products.at(0).push_back(0);
  products.at(0).push_back(0);
  products.at(0).push_back(0);
  products.at(0).push_back(0);
  products.at(1).push_back(/*found*/false);
  break;
}

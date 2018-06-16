//: Clean syntax to manipulate and check the console in scenarios.
//: Instruction 'assume-console' implicitly creates a variable called
//: 'console' that is accessible inside other 'run' instructions in the
//: scenario. Like with the fake screen, 'assume-console' transparently
//: supports unicode.

//: first make sure we don't mangle this instruction in other transforms
:(before "End initialize_transform_rewrite_literal_string_to_text()")
recipes_taking_literal_strings.insert("assume-console");

:(scenarios run_mu_scenario)
:(scenario keyboard_in_scenario)
scenario keyboard-in-scenario [
  assume-console [
    type [abc]
  ]
  run [
    1:char, 2:bool <- read-key console
    3:char, 4:bool <- read-key console
    5:char, 6:bool <- read-key console
    7:char, 8:bool, 9:bool <- read-key console
  ]
  memory-should-contain [
    1 <- 97  # 'a'
    2 <- 1
    3 <- 98  # 'b'
    4 <- 1
    5 <- 99  # 'c'
    6 <- 1
    7 <- 0  # unset
    8 <- 1
    9 <- 1  # end of test events
  ]
]

:(before "End Scenario Globals")
extern const int CONSOLE = next_predefined_global_for_scenarios(/*size_of(address:console)*/2);
//: give 'console' a fixed location in scenarios
:(before "End Special Scenario Variable Names(r)")
Name[r]["console"] = CONSOLE;
//: make 'console' always a raw location in scenarios
:(before "End is_special_name Special-cases")
if (s == "console") return true;

:(before "End Primitive Recipe Declarations")
ASSUME_CONSOLE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "assume-console", ASSUME_CONSOLE);
:(before "End Primitive Recipe Checks")
case ASSUME_CONSOLE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case ASSUME_CONSOLE: {
  // create a temporary recipe just for parsing; it won't contain valid instructions
  istringstream in("[" + current_instruction().ingredients.at(0).name + "]");
  recipe r;
  slurp_body(in, r);
  int num_events = count_events(r);
  // initialize the events like in new-fake-console
  int size = /*length*/1 + num_events*size_of_event();
  int event_data_address = allocate(size);
  // store length
  put(Memory, event_data_address+/*skip alloc id*/1, num_events);
  int curr_address = event_data_address + /*skip alloc id*/1 + /*skip length*/1;
  for (int i = 0;  i < SIZE(r.steps);  ++i) {
    const instruction& inst = r.steps.at(i);
    if (inst.name == "left-click") {
      trace("mem") << "storing 'left-click' event starting at " << Current_routine->alloc << end();
      put(Memory, curr_address, /*tag for 'touch-event' variant of 'event' exclusive-container*/2);
      put(Memory, curr_address+/*skip tag*/1+/*offset of 'type' in 'mouse-event'*/0, TB_KEY_MOUSE_LEFT);
      put(Memory, curr_address+/*skip tag*/1+/*offset of 'row' in 'mouse-event'*/1, to_integer(inst.ingredients.at(0).name));
      put(Memory, curr_address+/*skip tag*/1+/*offset of 'column' in 'mouse-event'*/2, to_integer(inst.ingredients.at(1).name));
      curr_address += size_of_event();
    }
    else if (inst.name == "press") {
      trace("mem") << "storing 'press' event starting at " << curr_address << end();
      string key = inst.ingredients.at(0).name;
      if (is_integer(key))
        put(Memory, curr_address+1, to_integer(key));
      else if (contains_key(Key, key))
        put(Memory, curr_address+1, Key[key]);
      else
        raise << "assume-console: can't press '" << key << "'\n" << end();
      if (get_or_insert(Memory, curr_address+1) < 256)
        // these keys are in ascii
        put(Memory, curr_address, /*tag for 'text' variant of 'event' exclusive-container*/0);
      else {
        // distinguish from unicode
        put(Memory, curr_address, /*tag for 'keycode' variant of 'event' exclusive-container*/1);
      }
      curr_address += size_of_event();
    }
    // End Event Handlers
    else {
      // keyboard input
      assert(inst.name == "type");
      trace("mem") << "storing 'type' event starting at " << curr_address << end();
      const string& contents = inst.ingredients.at(0).name;
      const char* raw_contents = contents.c_str();
      int num_keyboard_events = unicode_length(contents);
      int curr = 0;
      for (int i = 0;  i < num_keyboard_events;  ++i) {
        trace("mem") << "storing 'text' tag at " << curr_address << end();
        put(Memory, curr_address, /*tag for 'text' variant of 'event' exclusive-container*/0);
        uint32_t curr_character;
        assert(curr < SIZE(contents));
        tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
        trace("mem") << "storing character " << curr_character << " at " << curr_address+/*skip exclusive container tag*/1 << end();
        put(Memory, curr_address+/*skip exclusive container tag*/1, curr_character);
        curr += tb_utf8_char_length(raw_contents[curr]);
        curr_address += size_of_event();
      }
    }
  }
  assert(curr_address == event_data_address+/*skip alloc id*/1+size);
  // wrap the array of events in a console object
  int console_address = allocate(size_of_console());
  trace("mem") << "storing console in " << console_address << end();
  put(Memory, CONSOLE+/*skip alloc id*/1, console_address);
  trace("mem") << "storing console data in " << console_address+/*offset of 'data' in container 'events'*/1 << end();
  put(Memory, console_address+/*skip alloc id*/1+/*offset of 'data' in container 'events'*/1+/*skip alloc id of 'data'*/1, event_data_address);
  break;
}

:(before "End Globals")
map<string, int> Key;
:(before "End One-time Setup")
initialize_key_names();
:(code)
void initialize_key_names() {
  Key["F1"] = TB_KEY_F1;
  Key["F2"] = TB_KEY_F2;
  Key["F3"] = TB_KEY_F3;
  Key["F4"] = TB_KEY_F4;
  Key["F5"] = TB_KEY_F5;
  Key["F6"] = TB_KEY_F6;
  Key["F7"] = TB_KEY_F7;
  Key["F8"] = TB_KEY_F8;
  Key["F9"] = TB_KEY_F9;
  Key["F10"] = TB_KEY_F10;
  Key["F11"] = TB_KEY_F11;
  Key["F12"] = TB_KEY_F12;
  Key["insert"] = TB_KEY_INSERT;
  Key["delete"] = TB_KEY_DELETE;
  Key["home"] = TB_KEY_HOME;
  Key["end"] = TB_KEY_END;
  Key["page-up"] = TB_KEY_PGUP;
  Key["page-down"] = TB_KEY_PGDN;
  Key["up-arrow"] = TB_KEY_ARROW_UP;
  Key["down-arrow"] = TB_KEY_ARROW_DOWN;
  Key["left-arrow"] = TB_KEY_ARROW_LEFT;
  Key["right-arrow"] = TB_KEY_ARROW_RIGHT;
  Key["ctrl-a"] = TB_KEY_CTRL_A;
  Key["ctrl-b"] = TB_KEY_CTRL_B;
  Key["ctrl-c"] = TB_KEY_CTRL_C;
  Key["ctrl-d"] = TB_KEY_CTRL_D;
  Key["ctrl-e"] = TB_KEY_CTRL_E;
  Key["ctrl-f"] = TB_KEY_CTRL_F;
  Key["ctrl-g"] = TB_KEY_CTRL_G;
  Key["backspace"] = TB_KEY_BACKSPACE;
  Key["ctrl-h"] = TB_KEY_CTRL_H;
  Key["tab"] = TB_KEY_TAB;
  Key["ctrl-i"] = TB_KEY_CTRL_I;
  Key["ctrl-j"] = TB_KEY_CTRL_J;
  Key["enter"] = TB_KEY_NEWLINE;  // ignore CR/LF distinction; there is only 'enter'
  Key["ctrl-k"] = TB_KEY_CTRL_K;
  Key["ctrl-l"] = TB_KEY_CTRL_L;
  Key["ctrl-m"] = TB_KEY_CTRL_M;
  Key["ctrl-n"] = TB_KEY_CTRL_N;
  Key["ctrl-o"] = TB_KEY_CTRL_O;
  Key["ctrl-p"] = TB_KEY_CTRL_P;
  Key["ctrl-q"] = TB_KEY_CTRL_Q;
  Key["ctrl-r"] = TB_KEY_CTRL_R;
  Key["ctrl-s"] = TB_KEY_CTRL_S;
  Key["ctrl-t"] = TB_KEY_CTRL_T;
  Key["ctrl-u"] = TB_KEY_CTRL_U;
  Key["ctrl-v"] = TB_KEY_CTRL_V;
  Key["ctrl-w"] = TB_KEY_CTRL_W;
  Key["ctrl-x"] = TB_KEY_CTRL_X;
  Key["ctrl-y"] = TB_KEY_CTRL_Y;
  Key["ctrl-z"] = TB_KEY_CTRL_Z;
  Key["escape"] = TB_KEY_ESC;
  Key["ctrl-slash"] = TB_KEY_CTRL_SLASH;
}

:(after "Begin check_or_set_invalid_types(r)")
if (is_scenario(caller))
  initialize_special_name(r);
:(code)
bool is_scenario(const recipe& caller) {
  return starts_with(caller.name, "scenario_");
}
void initialize_special_name(reagent& r) {
  if (r.type) return;
  // no need for screen
  if (r.name == "console") r.type = new_type_tree("address:console");
  // End Initialize Type Of Special Name In Scenario(r)
}

:(scenario events_in_scenario)
scenario events-in-scenario [
  assume-console [
    type [abc]
    left-click 0, 1
    press up-arrow
    type [d]
  ]
  run [
    # 3 keyboard events; each event occupies 4 locations
    1:event <- read-event console
    5:event <- read-event console
    9:event <- read-event console
    # mouse click
    13:event <- read-event console
    # non-character keycode
    17:event <- read-event console
    # final keyboard event
    21:event <- read-event console
  ]
  memory-should-contain [
    1 <- 0  # 'text'
    2 <- 97  # 'a'
    3 <- 0  # unused
    4 <- 0  # unused
    5 <- 0  # 'text'
    6 <- 98  # 'b'
    7 <- 0  # unused
    8 <- 0  # unused
    9 <- 0  # 'text'
    10 <- 99  # 'c'
    11 <- 0  # unused
    12 <- 0  # unused
    13 <- 2  # 'mouse'
    14 <- 65513  # mouse click
    15 <- 0  # row
    16 <- 1  # column
    17 <- 1  # 'keycode'
    18 <- 65517  # up arrow
    19 <- 0  # unused
    20 <- 0  # unused
    21 <- 0  # 'text'
    22 <- 100  # 'd'
    23 <- 0  # unused
    24 <- 0  # unused
    25 <- 0
  ]
]

//: Deal with special keys and unmatched brackets by allowing each test to
//: independently choose the unicode symbol to denote them.
:(before "End Primitive Recipe Declarations")
REPLACE_IN_CONSOLE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "replace-in-console", REPLACE_IN_CONSOLE);
:(before "End Primitive Recipe Checks")
case REPLACE_IN_CONSOLE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case REPLACE_IN_CONSOLE: {
  assert(scalar(ingredients.at(0)));
  if (!get_or_insert(Memory, CONSOLE)) {
    raise << "console not initialized\n" << end();
    break;
  }
  int console_address = get_or_insert(Memory, CONSOLE);
  int console_data = get_or_insert(Memory, console_address+1);
  int length = get_or_insert(Memory, console_data);  // array length
  for (int i = 0, curr = console_data+1;  i < length;  ++i, curr+=size_of_event()) {
    if (get_or_insert(Memory, curr) != /*text*/0) continue;
    if (get_or_insert(Memory, curr+1) != ingredients.at(0).at(0)) continue;
    for (int n = 0;  n < size_of_event();  ++n)
      put(Memory, curr+n, ingredients.at(1).at(n));
  }
  break;
}

:(code)
int count_events(const recipe& r) {
  int result = 0;
  for (int i = 0;  i < SIZE(r.steps);  ++i) {
    const instruction& curr = r.steps.at(i);
    if (curr.name == "type")
      result += unicode_length(curr.ingredients.at(0).name);
    else
      ++result;
  }
  return result;
}

int size_of_event() {
  // memoize result if already computed
  static int result = 0;
  if (result) return result;
  type_tree* type = new type_tree("event");
  result = size_of(type);
  delete type;
  return result;
}

int size_of_console() {
  // memoize result if already computed
  static int result = 0;
  if (result) return result;
  assert(get(Type_ordinal, "console"));
  type_tree* type = new type_tree("console");
  result = size_of(type);
  delete type;
  return result;
}

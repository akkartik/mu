//: Clean syntax to manipulate and check the console in scenarios.
//: Instruction 'assume-console' implicitly creates a variable called
//: 'console' that is accessible inside other 'run' instructions in the
//: scenario. Like with the fake screen, 'assume-console' transparently
//: supports unicode.

:(scenarios run_mu_scenario)
:(scenario keyboard_in_scenario)
scenario keyboard-in-scenario [
  assume-console [
    type [abc]
  ]
  run [
    1:character, console:address, 2:boolean <- read-key console:address
    3:character, console:address, 4:boolean <- read-key console:address
    5:character, console:address, 6:boolean <- read-key console:address
    7:character, console:address, 8:boolean, 9:boolean <- read-key console:address
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
const long long int CONSOLE = Next_predefined_global_for_scenarios++;
:(before "End Special Scenario Variable Names(r)")
Name[r]["console"] = CONSOLE;

//: allow naming just for 'console'
:(before "End is_special_name Cases")
if (s == "console") return true;

:(before "End Primitive Recipe Declarations")
ASSUME_CONSOLE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["assume-console"] = ASSUME_CONSOLE;
:(before "End Primitive Recipe Checks")
case ASSUME_CONSOLE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case ASSUME_CONSOLE: {
  // create a temporary recipe just for parsing; it won't contain valid instructions
  istringstream in("[" + current_instruction().ingredients.at(0).name + "]");
  recipe r = slurp_body(in);
  long long int num_events = count_events(r);
  // initialize the events like in new-fake-console
  long long int size = num_events*size_of_event() + /*space for length*/1;
  ensure_space(size);
  long long int event_data_address = Current_routine->alloc;
  Memory[event_data_address] = num_events;
  ++Current_routine->alloc;
  for (long long int i = 0; i < SIZE(r.steps); ++i) {
    const instruction& curr = r.steps.at(i);
    if (curr.name == "left-click") {
      Memory[Current_routine->alloc] = /*tag for 'touch-event' variant of 'event' exclusive-container*/2;
      Memory[Current_routine->alloc+1+/*offset of 'type' in 'mouse-event'*/0] = TB_KEY_MOUSE_LEFT;
      Memory[Current_routine->alloc+1+/*offset of 'row' in 'mouse-event'*/1] = to_integer(curr.ingredients.at(0).name);
      Memory[Current_routine->alloc+1+/*offset of 'column' in 'mouse-event'*/2] = to_integer(curr.ingredients.at(1).name);
      Current_routine->alloc += size_of_event();
    }
    else if (curr.name == "press") {
      string key = curr.ingredients.at(0).name;
      if (is_integer(key))
        Memory[Current_routine->alloc+1] = to_integer(key);
      else if (Key.find(key) != Key.end())
        Memory[Current_routine->alloc+1] = Key[key];
      else
        raise_error << "assume-console: can't press " << key << '\n' << end();
      if (Memory[Current_routine->alloc+1] < 256)
        // these keys are in ascii
        Memory[Current_routine->alloc] = /*tag for 'text' variant of 'event' exclusive-container*/0;
      else {
        // distinguish from unicode
        Memory[Current_routine->alloc] = /*tag for 'keycode' variant of 'event' exclusive-container*/1;
      }
      Current_routine->alloc += size_of_event();
    }
    // End Event Handlers
    else {
      // keyboard input
      assert(curr.name == "type");
      const string& contents = curr.ingredients.at(0).name;
      const char* raw_contents = contents.c_str();
      long long int num_keyboard_events = unicode_length(contents);
      long long int curr = 0;
      for (long long int i = 0; i < num_keyboard_events; ++i) {
        Memory[Current_routine->alloc] = /*tag for 'text' variant of 'event' exclusive-container*/0;
        uint32_t curr_character;
        assert(curr < SIZE(contents));
        tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
        Memory[Current_routine->alloc+/*skip exclusive container tag*/1] = curr_character;
        curr += tb_utf8_char_length(raw_contents[curr]);
        Current_routine->alloc += size_of_event();
      }
    }
  }
  assert(Current_routine->alloc == event_data_address+size);
  // wrap the array of events in an event object
  ensure_space(size_of_events());
  Memory[CONSOLE] = Current_routine->alloc;
  Current_routine->alloc += size_of_events();
  Memory[Memory[CONSOLE]+/*offset of 'data' in container 'events'*/1] = event_data_address;
  break;
}

:(before "End Globals")
map<string, long long int> Key;
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
    1:event <- read-event console:address
    5:event <- read-event console:address
    9:event <- read-event console:address
    # mouse click
    13:event <- read-event console:address
    # non-character keycode
    17:event <- read-event console:address
    # final keyboard event
    21:event <- read-event console:address
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
Recipe_ordinal["replace-in-console"] = REPLACE_IN_CONSOLE;
:(before "End Primitive Recipe Checks")
case REPLACE_IN_CONSOLE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case REPLACE_IN_CONSOLE: {
  assert(scalar(ingredients.at(0)));
  if (!Memory[CONSOLE]) {
    raise_error << "console not initialized\n" << end();
    break;
  }
  long long int console_data = Memory[Memory[CONSOLE]+1];
  long long int size = Memory[console_data];  // array size
  for (long long int i = 0, curr = console_data+1; i < size; ++i, curr+=size_of_event()) {
    if (Memory[curr] != /*text*/0) continue;
    if (Memory[curr+1] != ingredients.at(0).at(0)) continue;
    for (long long int n = 0; n < size_of_event(); ++n)
      Memory[curr+n] = ingredients.at(1).at(n);
  }
  break;
}

:(code)
long long int count_events(const recipe& r) {
  long long int result = 0;
  for (long long int i = 0; i < SIZE(r.steps); ++i) {
    const instruction& curr = r.steps.at(i);
    if (curr.name == "type")
      result += unicode_length(curr.ingredients.at(0).name);
    else
      result++;
  }
  return result;
}

long long int size_of_event() {
  // memoize result if already computed
  static long long int result = 0;
  if (result) return result;
  vector<type_ordinal> type;
  type.push_back(Type_ordinal["event"]);
  result = size_of(type);
  return result;
}

long long int size_of_events() {
  // memoize result if already computed
  static long long int result = 0;
  if (result) return result;
  vector<type_ordinal> type;
  assert(Type_ordinal["console"]);
  type.push_back(Type_ordinal["console"]);
  result = size_of(type);
  return result;
}

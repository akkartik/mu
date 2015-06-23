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
:(before "End Predefined Scenario Locals In Run")
Name[tmp_recipe.at(0)]["console"] = CONSOLE;

//: allow naming just for 'console'
:(before "End is_special_name Cases")
if (s == "console") return true;

//: Unlike assume-keyboard, assume-console is easiest to implement as just a
//: primitive recipe.
:(before "End Primitive Recipe Declarations")
ASSUME_CONSOLE,
:(before "End Primitive Recipe Numbers")
Recipe_number["assume-console"] = ASSUME_CONSOLE;
:(before "End Primitive Recipe Implementations")
case ASSUME_CONSOLE: {
//?   cerr << "aaa: " << current_instruction().ingredients.at(0).name << '\n'; //? 2
  // create a temporary recipe just for parsing; it won't contain valid instructions
  istringstream in("[" + current_instruction().ingredients.at(0).name + "]");
  recipe r = slurp_recipe(in);
  long long int num_events = count_events(r);
//?   cerr << "fff: " << num_events << '\n'; //? 3
  // initialize the events
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
//?       cerr << "AA left click: " << Memory[Current_routine->alloc+2] << ' ' << Memory[Current_routine->alloc+3] << '\n'; //? 1
      Current_routine->alloc += size_of_event();
    }
    else if (curr.name == "press") {
      Memory[Current_routine->alloc] = /*tag for 'keycode' variant of 'event' exclusive-container*/1;
      Memory[Current_routine->alloc+1] = to_integer(curr.ingredients.at(0).name);
//?       cerr << "AA press: " << Memory[Current_routine->alloc+1] << '\n'; //? 3
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
//?       cerr << "AAA: " << num_keyboard_events << '\n'; //? 1
      for (long long int i = 0; i < num_keyboard_events; ++i) {
        Memory[Current_routine->alloc] = /*tag for 'text' variant of 'event' exclusive-container*/0;
        uint32_t curr_character;
        assert(curr < SIZE(contents));
        tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
//?         cerr << "AA keyboard: " << curr_character << '\n'; //? 3
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
//?   cerr << "writing " << event_data_address << " to location " << Memory[CONSOLE]+1 << '\n'; //? 1
  Memory[Memory[CONSOLE]+/*offset of 'data' in container 'events'*/1] = event_data_address;
//?   cerr << Memory[Memory[CONSOLE]+1] << '\n'; //? 1
//?   cerr << "alloc now " << Current_routine->alloc << '\n'; //? 1
  break;
}

:(scenario events_in_scenario)
scenario events-in-scenario [
  assume-console [
    type [abc]
    left-click 0, 1
    press 65515  # up arrow
    type [d]
  ]
  run [
    # 3 keyboard events; each event occupies 4 locations
#?     $start-tracing #? 2
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
    18 <- 65515  # up arrow
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
Recipe_number["replace-in-console"] = REPLACE_IN_CONSOLE;
:(before "End Primitive Recipe Implementations")
case REPLACE_IN_CONSOLE: {
  assert(scalar(ingredients.at(0)));
//?   cerr << "console: " << Memory[CONSOLE] << '\n'; //? 1
  if (!Memory[CONSOLE])
    raise << "console not initialized\n" << die();
  long long int console_data = Memory[Memory[CONSOLE]+1];
//?   cerr << "console data starts at " << console_data << '\n'; //? 1
  long long int size = Memory[console_data];  // array size
//?   cerr << "size of console data is " << size << '\n'; //? 1
  for (long long int i = 0, curr = console_data+1; i < size; ++i, curr+=size_of_event()) {
//?     cerr << curr << '\n'; //? 1
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
//?     cerr << "aa: " << curr.name << '\n'; //? 3
//?     cerr << "bb: " << curr.ingredients.at(0).name << '\n'; //? 1
    if (curr.name == "type")
      result += unicode_length(curr.ingredients.at(0).name);
    else
      result++;
//?     cerr << "cc: " << result << '\n'; //? 1
  }
  return result;
}

long long int size_of_event() {
  // memoize result if already computed
  static long long int result = 0;
  if (result) return result;
  vector<type_number> type;
  type.push_back(Type_number["event"]);
  result = size_of(type);
  return result;
}

long long int size_of_events() {
  // memoize result if already computed
  static long long int result = 0;
  if (result) return result;
  vector<type_number> type;
  assert(Type_number["console"]);
  type.push_back(Type_number["console"]);
  result = size_of(type);
  return result;
}

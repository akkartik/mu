//: For testing both keyboard and mouse, use 'assume-events' rather than
//: 'assume-keyboard'.
//:
//: This layer is tightly coupled with the definition of the 'event' type.

:(scenarios run_mu_scenario)
:(scenario events_in_scenario)
scenario events-in-scenario [
  assume-events [
    type [abc]
    left-click 0, 1
    type [d]
  ]
  run [
    # 3 keyboard events; each event occupies 4 locations
#?     $start-tracing
    1:event <- read-event events:address
    5:event <- read-event events:address
    9:event <- read-event events:address
    # mouse click
    13:event <- read-event events:address
    # final keyboard event
    17:event <- read-event events:address
  ]
  memory-should-contain [
    1 <- 0  # type 'keyboard'
    2 <- 97  # 'a'
    3 <- 0  # unused
    4 <- 0  # unused
    5 <- 0  # type 'keyboard'
    6 <- 98  # 'b'
    7 <- 0  # unused
    8 <- 0  # unused
    9 <- 0  # type 'keyboard'
    10 <- 99  # 'c'
    11 <- 0  # unused
    12 <- 0  # unused
    13 <- 1  # type 'mouse'
    14 <- 65513  # mouse click
    15 <- 0  # row
    16 <- 1  # column
    17 <- 0  # type 'keyboard'
    18 <- 100  # 'd'
    19 <- 0  # unused
    20 <- 0  # unused
    21 <- 0
  ]
]

// 'events' is a special variable like 'keyboard' and 'screen'
:(before "End Scenario Globals")
const long long int EVENTS = Next_predefined_global_for_scenarios++;
:(before "End Predefined Scenario Locals In Run")
Name[tmp_recipe.at(0)]["events"] = EVENTS;
:(before "End is_special_name Cases")
if (s == "events") return true;

//: Unlike assume-keyboard, assume-events is easiest to implement as just a
//: primitive recipe.
:(before "End Primitive Recipe Declarations")
ASSUME_EVENTS,
:(before "End Primitive Recipe Numbers")
Recipe_number["assume-events"] = ASSUME_EVENTS;
:(before "End Primitive Recipe Implementations")
case ASSUME_EVENTS: {
//?   cerr << "aaa: " << current_instruction().ingredients.at(0).name << '\n'; //? 1
  // create a temporary recipe just for parsing; it won't contain valid instructions
  istringstream in("[" + current_instruction().ingredients.at(0).name + "]");
  recipe r = slurp_recipe(in);
  long long int num_events = count_events(r);
//?   cerr << "fff: " << num_events << '\n'; //? 1
  // initialize the events
  long long int size = num_events*size_of_event() + /*space for length*/1;
  ensure_space(size);
  long long int event_data_address = Current_routine->alloc;
  Memory[event_data_address] = num_events;
  ++Current_routine->alloc;
  for (long long int i = 0; i < SIZE(r.steps); ++i) {
    const instruction& curr = r.steps.at(i);
    if (curr.name == "left-click") {
      Memory[Current_routine->alloc] = /*tag for 'mouse-event' variant of 'event' exclusive-container*/1;
      Memory[Current_routine->alloc+1+/*offset of 'type' in 'mouse-event'*/0] = TB_KEY_MOUSE_LEFT;
      Memory[Current_routine->alloc+1+/*offset of 'row' in 'mouse-event'*/1] = to_integer(curr.ingredients.at(0).name);
      Memory[Current_routine->alloc+1+/*offset of 'column' in 'mouse-event'*/2] = to_integer(curr.ingredients.at(1).name);
//?       cerr << "AA left click: " << Memory[Current_routine->alloc+2] << ' ' << Memory[Current_routine->alloc+3] << '\n'; //? 1
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
        Memory[Current_routine->alloc] = /*tag for 'keyboard-event' variant of 'event' exclusive-container*/0;
        uint32_t curr_character;
        assert(curr < SIZE(contents));
        tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
//?         cerr << "AA keyboard: " << curr_character << '\n'; //? 1
        Memory[Current_routine->alloc+/*skip exclusive container tag*/1] = curr_character;
        curr += tb_utf8_char_length(raw_contents[curr]);
        Current_routine->alloc += size_of_event();
      }
    }
  }
  assert(Current_routine->alloc == event_data_address+size);
  // wrap the array of events in an event object
  ensure_space(size_of_events());
  Memory[EVENTS] = Current_routine->alloc;
  Current_routine->alloc += size_of_events();
  Memory[Memory[EVENTS]+/*offset of 'data' in container 'events'*/1] = event_data_address;
  break;
}

:(code)
long long int count_events(const recipe& r) {
  long long int result = 0;
  for (long long int i = 0; i < SIZE(r.steps); ++i) {
    const instruction& curr = r.steps.at(i);
//?     cerr << curr.name << '\n'; //? 1
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
  type.push_back(Type_number["events"]);
  result = size_of(type);
  return result;
}

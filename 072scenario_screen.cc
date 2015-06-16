//: Clean syntax to manipulate and check the screen in scenarios.
//: Instructions 'assume-screen' and 'screen-should-contain' implicitly create
//: a variable called 'screen' that is accessible inside other 'run'
//: instructions in the scenario. 'screen-should-contain' can check unicode
//: characters in the fake screen

:(scenarios run_mu_scenario)
:(scenario screen_in_scenario)
scenario screen-in-scenario [
#?   $start-tracing #? 2
  assume-screen 5:literal/width, 3:literal/height
  run [
    screen:address <- print-character screen:address, 97:literal  # 'a'
  ]
  screen-should-contain [
  #  01234
    .a    .
    .     .
    .     .
  ]
#?   $exit #? 1
]

:(scenario screen_in_scenario_unicode)
scenario screen-in-scenario-unicode-color [
  assume-screen 5:literal/width, 3:literal/height
  run [
    screen:address <- print-character screen:address, 955:literal/greek-small-lambda, 1:literal/red
    screen:address <- print-character screen:address, 97:literal/a
  ]
  screen-should-contain [
  #  01234
    .λa   .
    .     .
    .     .
  ]
#?   $exit
]

:(scenario screen_in_scenario_color)
# screen-should-contain can check unicode characters in the fake screen
scenario screen-in-scenario-color [
  assume-screen 5:literal/width, 3:literal/height
  run [
    screen:address <- print-character screen:address, 955:literal/greek-small-lambda, 1:literal/red
    screen:address <- print-character screen:address, 97:literal/a, 7:literal/white
  ]
  # screen-should-contain shows everything
  screen-should-contain [
  #  01234
    .λa   .
    .     .
    .     .
  ]
  # screen-should-contain-in-color filters out everything except the given
  # color, all you see is the 'a' in white.
  screen-should-contain-in-color 7:literal/white, [
  #  01234
    . a   .
    .     .
    .     .
  ]
  # ..and the λ in red.
  screen-should-contain-in-color 1:literal/red, [
  #  01234
    .λ    .
    .     .
    .     .
  ]
#?   $exit
]

:(scenario screen_in_scenario_error)
% Hide_warnings = true;
scenario screen-in-scenario-error [
  assume-screen 5:literal/width, 3:literal/height
  run [
    screen:address <- print-character screen:address, 97:literal  # 'a'
  ]
  screen-should-contain [
  #  01234
    .b    .
    .     .
    .     .
  ]
]
+warn: expected screen location (0, 0) to contain 98 ('b') instead of 97 ('a')

:(scenario screen_in_scenario_color_error)
% Hide_warnings = true;
# screen-should-contain can check unicode characters in the fake screen
scenario screen-in-scenario-color [
  assume-screen 5:literal/width, 3:literal/height
  run [
    screen:address <- print-character screen:address, 97:literal/a, 1:literal/red
  ]
  screen-should-contain-in-color 2:literal/green, [
  #  01234
    .a    .
    .     .
    .     .
  ]
]
+warn: expected screen location (0, 0) to be in color 2 instead of 1

//: allow naming just for 'screen'
:(before "End is_special_name Cases")
if (s == "screen") return true;

:(before "End Globals")
// Scenarios may not define default-space, so they should fit within the
// initial area of memory reserved for tests. We'll put the predefined
// variables available to them at the end of that region.
const long long int Max_variables_in_scenarios = Reserved_for_tests-100;
long long int Next_predefined_global_for_scenarios = Max_variables_in_scenarios;
:(before "End Setup")
assert(Next_predefined_global_for_scenarios < Reserved_for_tests);
:(after "transform_all()" following "case RUN:")
// There's a restriction on the number of variables 'run' can use, so that
// it can avoid colliding with the dynamic allocator in case it doesn't
// initialize a default-space.
assert(Name[tmp_recipe.at(0)][""] < Max_variables_in_scenarios);

:(before "End Globals")
// Scenario Globals.
const long long int SCREEN = Next_predefined_global_for_scenarios++;
// End Scenario Globals.
:(before "End Predefined Scenario Locals In Run")
Name[tmp_recipe.at(0)]["screen"] = SCREEN;

:(before "End Rewrite Instruction(curr)")
// rewrite `assume-screen width, height` to
// `screen:address <- init-fake-screen width, height`
//? cout << "before: " << curr.to_string() << '\n'; //? 1
if (curr.name == "assume-screen") {
  curr.operation = Recipe_number["init-fake-screen"];
  assert(curr.operation);
  assert(curr.products.empty());
  curr.products.push_back(reagent("screen:address"));
  curr.products.at(0).set_value(SCREEN);
//? cout << "after: " << curr.to_string() << '\n'; //? 1
//? cout << "AAA " << Recipe_number["init-fake-screen"] << '\n'; //? 1
}

//: screen-should-contain is a regular instruction
:(before "End Primitive Recipe Declarations")
SCREEN_SHOULD_CONTAIN,
:(before "End Primitive Recipe Numbers")
Recipe_number["screen-should-contain"] = SCREEN_SHOULD_CONTAIN;
:(before "End Primitive Recipe Implementations")
case SCREEN_SHOULD_CONTAIN: {
  if (!Passed) break;
  check_screen(current_instruction().ingredients.at(0).name, -1);
  break;
}

:(before "End Primitive Recipe Declarations")
SCREEN_SHOULD_CONTAIN_IN_COLOR,
:(before "End Primitive Recipe Numbers")
Recipe_number["screen-should-contain-in-color"] = SCREEN_SHOULD_CONTAIN_IN_COLOR;
:(before "End Primitive Recipe Implementations")
case SCREEN_SHOULD_CONTAIN_IN_COLOR: {
  if (!Passed) break;
  assert(scalar(ingredients.at(0)));
  check_screen(current_instruction().ingredients.at(1).name, ingredients.at(0).at(0));
  break;
}

:(before "End Types")
// scan an array of characters in a unicode-aware, bounds-checked manner
struct raw_string_stream {
  long long int index;
  const long long int max;
  const char* buf;

  raw_string_stream(const string&);
  uint32_t get();  // unicode codepoint
  uint32_t peek();  // unicode codepoint
  bool at_end() const;
  void skip_whitespace_and_comments();
};

:(code)
void check_screen(const string& expected_contents, const int color) {
//?   cerr << "Checking screen for color " << color << "\n"; //? 2
  assert(!Current_routine->calls.front().default_space);  // not supported
  long long int screen_location = Memory[SCREEN];
  int data_offset = find_element_name(Type_number["screen"], "data");
  assert(data_offset >= 0);
  long long int screen_data_location = screen_location+data_offset;  // type: address:array:character
  long long int screen_data_start = Memory[screen_data_location];  // type: array:character
  int width_offset = find_element_name(Type_number["screen"], "num-columns");
  long long int screen_width = Memory[screen_location+width_offset];
  int height_offset = find_element_name(Type_number["screen"], "num-rows");
  long long int screen_height = Memory[screen_location+height_offset];
  raw_string_stream cursor(expected_contents);
  // todo: too-long expected_contents should fail
  long long int addr = screen_data_start+1;  // skip length
  for (long long int row = 0; row < screen_height; ++row) {
    cursor.skip_whitespace_and_comments();
    if (cursor.at_end()) break;
    assert(cursor.get() == '.');
    for (long long int column = 0;  column < screen_width;  ++column, addr+= /*size of screen-cell*/2) {
      const int cell_color_offset = 1;
      uint32_t curr = cursor.get();
      if (Memory[addr] == 0 && isspace(curr)) continue;
//?       cerr << color << " vs " << Memory[addr+1] << '\n'; //? 1
      if (curr == ' ' && color != -1 && color != Memory[addr+cell_color_offset]) {
        // filter out other colors
        continue;
      }
      if (Memory[addr] != 0 && Memory[addr] == curr) {
        if (color == -1 || color == Memory[addr+cell_color_offset]) continue;
        // contents match but color is off
        if (Current_scenario && !Hide_warnings) {
          // genuine test in a mu file
          raise << "\nF - " << Current_scenario->name << ": expected screen location (" << row << ", " << column << ", address " << addr << ", value " << Memory[addr] << ") to be in color " << color << " instead of " << Memory[addr+cell_color_offset] << "\n";
        }
        else {
          // just testing check_screen
          raise << "expected screen location (" << row << ", " << column << ") to be in color " << color << " instead of " << Memory[addr+cell_color_offset] << '\n';
        }
        if (!Hide_warnings) {
          Passed = false;
          ++Num_failures;
        }
        return;
      }

      // really a mismatch
      // can't print multi-byte unicode characters in warnings just yet. not very useful for debugging anyway.
      char expected_pretty[10] = {0};
      if (curr < 256 && !iscntrl(curr)) {
        // " ('<curr>')"
        expected_pretty[0] = ' ', expected_pretty[1] = '(', expected_pretty[2] = '\'', expected_pretty[3] = static_cast<unsigned char>(curr), expected_pretty[4] = '\'', expected_pretty[5] = ')', expected_pretty[6] = '\0';
      }
      char actual_pretty[10] = {0};
      if (Memory[addr] < 256 && !iscntrl(Memory[addr])) {
        // " ('<curr>')"
        actual_pretty[0] = ' ', actual_pretty[1] = '(', actual_pretty[2] = '\'', actual_pretty[3] = static_cast<unsigned char>(Memory[addr]), actual_pretty[4] = '\'', actual_pretty[5] = ')', actual_pretty[6] = '\0';
      }

      if (Current_scenario && !Hide_warnings) {
        // genuine test in a mu file
        raise << "\nF - " << Current_scenario->name << ": expected screen location (" << row << ", " << column << ") to contain " << curr << expected_pretty << " instead of " << Memory[addr] << actual_pretty << '\n';
        dump_screen();
      }
      else {
        // just testing check_screen
        raise << "expected screen location (" << row << ", " << column << ") to contain " << curr << expected_pretty << " instead of " << Memory[addr] << actual_pretty << '\n';
      }
      if (!Hide_warnings) {
        Passed = false;
        ++Num_failures;
      }
      return;
    }
    assert(cursor.get() == '.');
  }
  cursor.skip_whitespace_and_comments();
  assert(cursor.at_end());
}

raw_string_stream::raw_string_stream(const string& backing) :index(0), max(backing.size()), buf(backing.c_str()) {}

bool raw_string_stream::at_end() const {
  if (index >= max) return true;
  if (tb_utf8_char_length(buf[index]) > max-index) {
    raise << "unicode string seems corrupted at index "<< index << " character " << static_cast<int>(buf[index]) << '\n';
    return true;
  }
  return false;
}

uint32_t raw_string_stream::get() {
  assert(index < max);  // caller must check bounds before calling 'get'
  uint32_t result = 0;
  int length = tb_utf8_char_to_unicode(&result, &buf[index]);
  assert(length != TB_EOF);
  index += length;
  return result;
}

uint32_t raw_string_stream::peek() {
  assert(index < max);  // caller must check bounds before calling 'get'
  uint32_t result = 0;
  int length = tb_utf8_char_to_unicode(&result, &buf[index]);
  assert(length != TB_EOF);
  return result;
}

void raw_string_stream::skip_whitespace_and_comments() {
  while (!at_end()) {
    if (isspace(peek())) get();
    else if (peek() == '#') {
      // skip comment
      get();
      while (peek() != '\n') get();  // implicitly also handles CRLF
    }
    else break;
  }
}

:(before "End Primitive Recipe Declarations")
_DUMP_SCREEN,
:(before "End Primitive Recipe Numbers")
Recipe_number["$dump-screen"] = _DUMP_SCREEN;
:(before "End Primitive Recipe Implementations")
case _DUMP_SCREEN: {
  dump_screen();
  break;
}

:(code)
void dump_screen() {
  assert(!Current_routine->calls.front().default_space);  // not supported
  long long int screen_location = Memory[SCREEN];
  int width_offset = find_element_name(Type_number["screen"], "num-columns");
  long long int screen_width = Memory[screen_location+width_offset];
  int height_offset = find_element_name(Type_number["screen"], "num-rows");
  long long int screen_height = Memory[screen_location+height_offset];
  int data_offset = find_element_name(Type_number["screen"], "data");
  assert(data_offset >= 0);
  long long int screen_data_location = screen_location+data_offset;  // type: address:array:character
  long long int screen_data_start = Memory[screen_data_location];  // type: array:character
//?   cerr << "data start: " << screen_data_start << '\n'; //? 1
  assert(Memory[screen_data_start] == screen_width*screen_height);
  long long int curr = screen_data_start+1;  // skip length
  for (long long int row = 0; row < screen_height; ++row) {
//?     cerr << curr << ":\n"; //? 2
    for (long long int col = 0; col < screen_width; ++col) {
      if (Memory[curr])
        cerr << to_unicode(Memory[curr]);
      else
        cerr << ' ';
      curr += /*size of screen-cell*/2;
    }
    cerr << '\n';
  }
}

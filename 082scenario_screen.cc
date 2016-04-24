//: Clean syntax to manipulate and check the screen in scenarios.
//: Instructions 'assume-screen' and 'screen-should-contain' implicitly create
//: a variable called 'screen' that is accessible inside other 'run'
//: instructions in the scenario. 'screen-should-contain' can check unicode
//: characters in the fake screen

:(scenarios run_mu_scenario)
:(scenario screen_in_scenario)
scenario screen-in-scenario [
  assume-screen 5/width, 3/height
  run [
    1:character <- copy 97/a
    screen:address:screen <- print screen:address:screen, 1:character/a
  ]
  screen-should-contain [
  #  01234
    .a    .
    .     .
    .     .
  ]
]

:(scenario screen_in_scenario_unicode)
scenario screen-in-scenario-unicode-color [
  assume-screen 5/width, 3/height
  run [
    1:character <- copy 955/greek-small-lambda
    screen:address:screen <- print screen:address:screen, 1:character/lambda, 1/red
    2:character <- copy 97/a
    screen:address:screen <- print screen:address:screen, 2:character/a
  ]
  screen-should-contain [
  #  01234
    .λa   .
    .     .
    .     .
  ]
]

:(scenario screen_in_scenario_color)
# screen-should-contain can check unicode characters in the fake screen
scenario screen-in-scenario-color [
  assume-screen 5/width, 3/height
  run [
    1:character <- copy 955/greek-small-lambda
    screen:address:screen <- print screen:address:screen, 1:character/lambda, 1/red
    2:character <- copy 97/a
    screen:address:screen <- print screen:address:screen, 2:character/a, 7/white
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
  screen-should-contain-in-color 7/white, [
  #  01234
    . a   .
    .     .
    .     .
  ]
  # ..and the λ in red.
  screen-should-contain-in-color 1/red, [
  #  01234
    .λ    .
    .     .
    .     .
  ]
]

:(scenario screen_in_scenario_error)
% Scenario_testing_scenario = true;
% Hide_errors = true;
scenario screen-in-scenario-error [
  assume-screen 5/width, 3/height
  run [
    1:character <- copy 97/a
    screen:address:screen <- print screen:address:screen, 1:character/a
  ]
  screen-should-contain [
  #  01234
    .b    .
    .     .
    .     .
  ]
]
+error: expected screen location (0, 0) to contain 98 ('b') instead of 97 ('a')

:(scenario screen_in_scenario_color_error)
% Scenario_testing_scenario = true;
% Hide_errors = true;
# screen-should-contain can check unicode characters in the fake screen
scenario screen-in-scenario-color [
  assume-screen 5/width, 3/height
  run [
    1:character <- copy 97/a
    screen:address:screen <- print screen:address:screen, 1:character/a, 1/red
  ]
  screen-should-contain-in-color 2/green, [
  #  01234
    .a    .
    .     .
    .     .
  ]
]
+error: expected screen location (0, 0) to be in color 2 instead of 1

//: allow naming just for 'screen'
:(before "End is_special_name Cases")
if (s == "screen") return true;

:(scenarios run)
:(scenario convert_names_does_not_fail_when_mixing_special_names_and_numeric_locations)
% Scenario_testing_scenario = true;
def main [
  screen:number <- copy 1:number
]
-error: mixing variable names and numeric addresses in main
$error: 0
:(scenarios run_mu_scenario)

:(before "End Globals")
// Scenarios may not define default-space, so they should fit within the
// initial area of memory reserved for tests. We'll put the predefined
// variables available to them at the end of that region.
const int Max_variables_in_scenarios = Reserved_for_tests-100;
int Next_predefined_global_for_scenarios = Max_variables_in_scenarios;
:(before "End Setup")
assert(Next_predefined_global_for_scenarios < Reserved_for_tests);
:(after "transform_all()" following "case RUN:")
// There's a restriction on the number of variables 'run' can use, so that
// it can avoid colliding with the dynamic allocator in case it doesn't
// initialize a default-space.
assert(Name[tmp_recipe.at(0)][""] < Max_variables_in_scenarios);

:(before "End Globals")
// Scenario Globals.
const int SCREEN = Next_predefined_global_for_scenarios++;
// End Scenario Globals.
:(before "End Special Scenario Variable Names(r)")
Name[r]["screen"] = SCREEN;

:(before "End Rewrite Instruction(curr, recipe result)")
// rewrite `assume-screen width, height` to
// `screen:address:screen <- new-fake-screen width, height`
if (curr.name == "assume-screen") {
  curr.name = "new-fake-screen";
  assert(curr.products.empty());
  curr.products.push_back(reagent("screen:address:screen"));
  curr.products.at(0).set_value(SCREEN);
}

//: screen-should-contain is a regular instruction
:(before "End Primitive Recipe Declarations")
SCREEN_SHOULD_CONTAIN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "screen-should-contain", SCREEN_SHOULD_CONTAIN);
:(before "End Primitive Recipe Checks")
case SCREEN_SHOULD_CONTAIN: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SCREEN_SHOULD_CONTAIN: {
  if (!Passed) break;
  assert(scalar(ingredients.at(0)));
  check_screen(current_instruction().ingredients.at(0).name, -1);
  break;
}

:(before "End Primitive Recipe Declarations")
SCREEN_SHOULD_CONTAIN_IN_COLOR,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "screen-should-contain-in-color", SCREEN_SHOULD_CONTAIN_IN_COLOR);
:(before "End Primitive Recipe Checks")
case SCREEN_SHOULD_CONTAIN_IN_COLOR: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SCREEN_SHOULD_CONTAIN_IN_COLOR: {
  if (!Passed) break;
  assert(scalar(ingredients.at(0)));
  assert(scalar(ingredients.at(1)));
  check_screen(current_instruction().ingredients.at(1).name, ingredients.at(0).at(0));
  break;
}

:(before "End Types")
// scan an array of characters in a unicode-aware, bounds-checked manner
struct raw_string_stream {
  int index;
  const int max;
  const char* buf;

  raw_string_stream(const string&);
  uint32_t get();  // unicode codepoint
  uint32_t peek();  // unicode codepoint
  bool at_end() const;
  void skip_whitespace_and_comments();
};

:(code)
void check_screen(const string& expected_contents, const int color) {
  assert(!current_call().default_space);  // not supported
  int screen_location = get_or_insert(Memory, SCREEN)+/*skip refcount*/1;
  int data_offset = find_element_name(get(Type_ordinal, "screen"), "data", "");
  assert(data_offset >= 0);
  int screen_data_location = screen_location+data_offset;  // type: address:array:character
  int screen_data_start = get_or_insert(Memory, screen_data_location) + /*skip refcount*/1;  // type: array:character
  int width_offset = find_element_name(get(Type_ordinal, "screen"), "num-columns", "");
  int screen_width = get_or_insert(Memory, screen_location+width_offset);
  int height_offset = find_element_name(get(Type_ordinal, "screen"), "num-rows", "");
  int screen_height = get_or_insert(Memory, screen_location+height_offset);
  raw_string_stream cursor(expected_contents);
  // todo: too-long expected_contents should fail
  int addr = screen_data_start+/*skip length*/1;
  for (int row = 0; row < screen_height; ++row) {
    cursor.skip_whitespace_and_comments();
    if (cursor.at_end()) break;
    assert(cursor.get() == '.');
    for (int column = 0;  column < screen_width;  ++column, addr+= /*size of screen-cell*/2) {
      const int cell_color_offset = 1;
      uint32_t curr = cursor.get();
      if (get_or_insert(Memory, addr) == 0 && isspace(curr)) continue;
      if (curr == ' ' && color != -1 && color != get_or_insert(Memory, addr+cell_color_offset)) {
        // filter out other colors
        continue;
      }
      if (get_or_insert(Memory, addr) != 0 && get_or_insert(Memory, addr) == curr) {
        if (color == -1 || color == get_or_insert(Memory, addr+cell_color_offset)) continue;
        // contents match but color is off
        if (Current_scenario && !Scenario_testing_scenario) {
          // genuine test in a mu file
          raise << "\nF - " << Current_scenario->name << ": expected screen location (" << row << ", " << column << ", address " << addr << ", value " << no_scientific(get_or_insert(Memory, addr)) << ") to be in color " << color << " instead of " << no_scientific(get_or_insert(Memory, addr+cell_color_offset)) << "\n" << end();
        }
        else {
          // just testing check_screen
          raise << "expected screen location (" << row << ", " << column << ") to be in color " << color << " instead of " << no_scientific(get_or_insert(Memory, addr+cell_color_offset)) << '\n' << end();
        }
        if (!Scenario_testing_scenario) {
          Passed = false;
          ++Num_failures;
        }
        return;
      }

      // really a mismatch
      // can't print multi-byte unicode characters in errors just yet. not very useful for debugging anyway.
      char expected_pretty[10] = {0};
      if (curr < 256 && !iscntrl(curr)) {
        // " ('<curr>')"
        expected_pretty[0] = ' ', expected_pretty[1] = '(', expected_pretty[2] = '\'', expected_pretty[3] = static_cast<unsigned char>(curr), expected_pretty[4] = '\'', expected_pretty[5] = ')', expected_pretty[6] = '\0';
      }
      char actual_pretty[10] = {0};
      if (get_or_insert(Memory, addr) < 256 && !iscntrl(get_or_insert(Memory, addr))) {
        // " ('<curr>')"
        actual_pretty[0] = ' ', actual_pretty[1] = '(', actual_pretty[2] = '\'', actual_pretty[3] = static_cast<unsigned char>(get_or_insert(Memory, addr)), actual_pretty[4] = '\'', actual_pretty[5] = ')', actual_pretty[6] = '\0';
      }

      ostringstream color_phrase;
      if (color != -1) color_phrase << " in color " << color;
      if (Current_scenario && !Scenario_testing_scenario) {
        // genuine test in a mu file
        raise << "\nF - " << Current_scenario->name << ": expected screen location (" << row << ", " << column << ") to contain " << curr << expected_pretty << color_phrase.str() << " instead of " << no_scientific(get_or_insert(Memory, addr)) << actual_pretty << '\n' << end();
        dump_screen();
      }
      else {
        // just testing check_screen
        raise << "expected screen location (" << row << ", " << column << ") to contain " << curr << expected_pretty << color_phrase.str() << " instead of " << no_scientific(get_or_insert(Memory, addr)) << actual_pretty << '\n' << end();
      }
      if (!Scenario_testing_scenario) {
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

raw_string_stream::raw_string_stream(const string& backing) :index(0), max(SIZE(backing)), buf(backing.c_str()) {}

bool raw_string_stream::at_end() const {
  if (index >= max) return true;
  if (tb_utf8_char_length(buf[index]) > max-index) {
    raise << "unicode string seems corrupted at index "<< index << " character " << static_cast<int>(buf[index]) << '\n' << end();
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
put(Recipe_ordinal, "$dump-screen", _DUMP_SCREEN);
:(before "End Primitive Recipe Checks")
case _DUMP_SCREEN: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _DUMP_SCREEN: {
  dump_screen();
  break;
}

:(code)
void dump_screen() {
  assert(!current_call().default_space);  // not supported
  int screen_location = get_or_insert(Memory, SCREEN) + /*skip refcount*/1;
  int width_offset = find_element_name(get(Type_ordinal, "screen"), "num-columns", "");
  int screen_width = get_or_insert(Memory, screen_location+width_offset);
  int height_offset = find_element_name(get(Type_ordinal, "screen"), "num-rows", "");
  int screen_height = get_or_insert(Memory, screen_location+height_offset);
  int data_offset = find_element_name(get(Type_ordinal, "screen"), "data", "");
  assert(data_offset >= 0);
  int screen_data_location = screen_location+data_offset;  // type: address:array:character
  int screen_data_start = get_or_insert(Memory, screen_data_location) + /*skip refcount*/1;  // type: array:character
  assert(get_or_insert(Memory, screen_data_start) == screen_width*screen_height);
  int curr = screen_data_start+1;  // skip length
  for (int row = 0; row < screen_height; ++row) {
    cerr << '.';
    for (int col = 0; col < screen_width; ++col) {
      if (get_or_insert(Memory, curr))
        cerr << to_unicode(static_cast<uint32_t>(get_or_insert(Memory, curr)));
      else
        cerr << ' ';
      curr += /*size of screen-cell*/2;
    }
    cerr << ".\n";
  }
}

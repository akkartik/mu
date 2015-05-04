//: Clean syntax to manipulate and check the screen in scenarios.
//: Instructions 'assume-screen' and 'screen-should-contain' implicitly create
//: a variable called 'screen' that is accessible inside other 'run'
//: instructions in the scenario.

:(scenarios run_mu_scenario)
:(scenario screen_in_scenario)
scenario screen-in-scenario [
#?   $start-tracing
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
#?   $exit
]

:(scenario screen_in_scenario_error)
#? % cerr << "AAA\n";
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
+warn: expected screen location (0, 0) to contain 'b' instead of 'a'

:(before "End Globals")
// Scenarios may not define default-space, so they should fit within the
// initial area of memory reserved for tests. We'll put the predefined
// variables available to them at the end of that region.
const size_t Max_variables_in_scenarios = Reserved_for_tests-100;
size_t Next_predefined_global_for_scenarios = Max_variables_in_scenarios;
:(before "End Setup")
assert(Next_predefined_global_for_scenarios < Reserved_for_tests);

:(before "End Globals")
// Scenario Globals.
const size_t SCREEN = Next_predefined_global_for_scenarios++;
// End Scenario Globals.
:(before "End Predefined Scenario Locals In Run")
Name[tmp_recipe[0]]["screen"] = SCREEN;

:(before "End Rewrite Instruction(curr)")
// rewrite `assume-screen width, height` to
// `screen:address <- init-fake-screen width, height`
//? cout << "before: " << curr.to_string() << '\n'; //? 1
if (curr.name == "assume-screen") {
  curr.operation = Recipe_number["init-fake-screen"];
  assert(curr.products.empty());
  curr.products.push_back(reagent("screen:address"));
  curr.products[0].set_value(SCREEN);
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
//?   cout << "AAA\n"; //? 1
  check_screen(current_instruction().ingredients[0].name);
  break;
}

:(code)
void check_screen(const string& contents) {
  assert(!Current_routine->calls.top().default_space);  // not supported
  index_t screen_location = Memory[SCREEN];
  int data_offset = find_element_name(Type_number["screen"], "data");
  assert(data_offset >= 0);
  index_t screen_data_location = screen_location+data_offset;  // type: address:array:character
  index_t screen_data_start = Memory[screen_data_location];  // type: array:character
  int width_offset = find_element_name(Type_number["screen"], "num-columns");
  size_t screen_width = Memory[screen_location+width_offset];
  int height_offset = find_element_name(Type_number["screen"], "num-rows");
  size_t screen_height = Memory[screen_location+height_offset];
  string expected_contents;
  istringstream in(contents);
  in >> std::noskipws;
  for (index_t row = 0; row < screen_height; ++row) {
    skip_whitespace_and_comments(in);
    assert(!in.eof());
    assert(in.get() == '.');
    for (index_t column = 0; column < screen_width; ++column) {
      assert(!in.eof());
      expected_contents += in.get();
    }
    assert(in.get() == '.');
  }
  skip_whitespace_and_comments(in);
//?   assert(in.get() == ']');
  trace("run") << "checking screen size at " << screen_data_start;
//?   cout << expected_contents.size() << '\n'; //? 1
  if (Memory[screen_data_start] > static_cast<signed>(expected_contents.size()))
    raise << "expected contents are larger than screen size " << Memory[screen_data_start] << '\n';
  ++screen_data_start;  // now skip length
  for (index_t i = 0; i < expected_contents.size(); ++i) {
    trace("run") << "checking location " << screen_data_start+i;
    if ((!Memory[screen_data_start+i] && !isspace(expected_contents[i]))  // uninitialized memory => spaces
        || (Memory[screen_data_start+i] && Memory[screen_data_start+i] != expected_contents[i])) {
//?       cerr << "CCC " << Trace_stream << " " << Hide_warnings << '\n'; //? 1
      raise << "expected screen location (" << i/screen_width << ", " << i%screen_width << ") to contain '" << expected_contents[i] << "' instead of '" << static_cast<char>(Memory[screen_data_start+i]) << "'\n";
      Passed = false;
      return;
    }
  }
}

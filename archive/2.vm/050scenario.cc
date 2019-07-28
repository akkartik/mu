//: Mu scenarios. This will get long, but these are the tests we want to
//: support in this layer.

//: We avoid raw numeric locations in Mu -- except in scenarios, where they're
//: handy to check the values of specific variables

void test_scenario_block() {
  run_mu_scenario(
      "scenario foo [\n"
      "  run [\n"
      "    1:num <- copy 13\n"
      "  ]\n"
      "  memory-should-contain [\n"
      "    1 <- 13\n"
      "  ]\n"
      "]\n"
  );
  // checks are inside scenario
}

void test_scenario_multiple_blocks() {
  run_mu_scenario(
      "scenario foo [\n"
      "  run [\n"
      "    1:num <- copy 13\n"
      "  ]\n"
      "  memory-should-contain [\n"
      "    1 <- 13\n"
      "  ]\n"
      "  run [\n"
      "    2:num <- copy 13\n"
      "  ]\n"
      "  memory-should-contain [\n"
      "    1 <- 13\n"
      "    2 <- 13\n"
      "  ]\n"
      "]\n"
  );
  // checks are inside scenario
}

void test_scenario_check_memory_and_trace() {
  run_mu_scenario(
      "scenario foo [\n"
      "  run [\n"
      "    1:num <- copy 13\n"
      "    trace 1, [a], [a b c]\n"
      "  ]\n"
      "  memory-should-contain [\n"
      "    1 <- 13\n"
      "  ]\n"
      "  trace-should-contain [\n"
      "    a: a b c\n"
      "  ]\n"
      "  trace-should-not-contain [\n"
      "    a: x y z\n"
      "  ]\n"
      "]\n"
  );
  // checks are inside scenario
}

//:: Core data structure

:(before "End Types")
struct scenario {
  string name;
  string to_run;
  void clear() {
    name.clear();
    to_run.clear();
  }
};

:(before "End Globals")
vector<scenario> Scenarios, Scenarios_snapshot;
set<string> Scenario_names, Scenario_names_snapshot;
:(before "End save_snapshots")
Scenarios_snapshot = Scenarios;
Scenario_names_snapshot = Scenario_names;
:(before "End restore_snapshots")
Scenarios = Scenarios_snapshot;
Scenario_names = Scenario_names_snapshot;

//:: Parse the 'scenario' form.
//: Simply store the text of the scenario.

:(before "End Command Handlers")
else if (command == "scenario") {
  scenario result = parse_scenario(in);
  if (!result.name.empty())
    Scenarios.push_back(result);
}
else if (command == "pending-scenario") {
  // for temporary use only
  parse_scenario(in);  // discard
}

:(code)
scenario parse_scenario(istream& in) {
  scenario result;
  result.name = next_word(in);
  if (contains_key(Scenario_names, result.name))
    raise << "duplicate scenario name: '" << result.name << "'\n" << end();
  Scenario_names.insert(result.name);
  if (result.name.empty()) {
    assert(!has_data(in));
    raise << "incomplete scenario at end of file\n" << end();
    return result;
  }
  skip_whitespace_and_comments(in);
  if (in.peek() != '[') {
    raise << "Expected '[' after scenario '" << result.name << "'\n" << end();
    exit(0);
  }
  // scenarios are take special 'code' strings so we need to ignore brackets
  // inside comments
  result.to_run = slurp_quoted(in);
  // delete [] delimiters
  if (!starts_with(result.to_run, "[")) {
    raise << "scenario " << result.name << " should start with '['\n" << end();
    result.clear();
    return result;
  }
  result.to_run.erase(0, 1);
  if (result.to_run.at(SIZE(result.to_run)-1) != ']') {
    raise << "scenario " << result.name << " has an unbalanced '['\n" << end();
    result.clear();
    return result;
  }
  result.to_run.erase(SIZE(result.to_run)-1);
  return result;
}

void test_read_scenario_with_bracket_in_comment() {
  run_mu_scenario(
      "scenario foo [\n"
      "  # ']' in comment\n"
      "  1:num <- copy 0\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: {1: \"number\"} <- copy {0: \"literal\"}\n"
  );
}

void test_read_scenario_with_bracket_in_comment_in_nested_string() {
  run_mu_scenario(
      "scenario foo [\n"
      "  1:text <- new [# not a comment]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: {1: (\"address\" \"array\" \"character\")} <- new {\"# not a comment\": \"literal-string\"}\n"
  );
}

void test_duplicate_scenarios() {
  Hide_errors = true;
  run(
      "scenario foo [\n"
      "  1:num <- copy 0\n"
      "]\n"
      "scenario foo [\n"
      "  2:num <- copy 0\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: duplicate scenario name: 'foo'\n"
  );
}

//:: Run scenarios when we run './mu test'.
//: Treat the text of the scenario as a regular series of instructions.

:(before "End Globals")
int Num_core_mu_scenarios = 0;
:(after "Check For .mu Files")
Num_core_mu_scenarios = SIZE(Scenarios);
:(before "End Tests")
Hide_missing_default_space_errors = false;
if (Num_core_mu_scenarios > 0) {
  time(&t);
  cerr << "Mu tests: " << ctime(&t);
  for (int i = 0;  i < Num_core_mu_scenarios;  ++i) {
//?     cerr << '\n' << i << ": " << Scenarios.at(i).name;
    run_mu_scenario(Scenarios.at(i));
    if (Passed) cerr << ".";
    else ++num_failures;
  }
  cerr << "\n";
}
run_app_scenarios:
if (Num_core_mu_scenarios != SIZE(Scenarios)) {
  time(&t);
  cerr << "App tests: " << ctime(&t);
  for (int i = Num_core_mu_scenarios;  i < SIZE(Scenarios);  ++i) {
//?     cerr << '\n' << i << ": " << Scenarios.at(i).name;
    run_mu_scenario(Scenarios.at(i));
    if (Passed) cerr << ".";
    else ++num_failures;
  }
  cerr << "\n";
}

//: For faster debugging, support running tests for just the Mu app(s) we are
//: loading.
:(before "End Globals")
bool Test_only_app = false;
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--test-only-app")) {
  Test_only_app = true;
}
:(after "End Test Run Initialization")
if (Test_only_app && Num_core_mu_scenarios < SIZE(Scenarios)) {
  goto run_app_scenarios;
}

//: Convenience: run a single named scenario.
:(after "Test Runs")
for (int i = 0;  i < SIZE(Scenarios);  ++i) {
  if (Scenarios.at(i).name == argv[argc-1]) {
    run_mu_scenario(Scenarios.at(i));
    if (Passed) cerr << ".\n";
    return 0;
  }
}

:(before "End Globals")
// this isn't a constant, just a global of type const*
const scenario* Current_scenario = NULL;
:(code)
void run_mu_scenario(const scenario& s) {
  Current_scenario = &s;
  bool not_already_inside_test = !Trace_stream;
//?   cerr << s.name << '\n';
  if (not_already_inside_test) {
    Trace_stream = new trace_stream;
    reset();
  }
  vector<recipe_ordinal> tmp = load("recipe scenario_"+s.name+" [ "+s.to_run+" ]");
  mark_autogenerated(tmp.at(0));
  bind_special_scenario_names(tmp.at(0));
  transform_all();
  if (!trace_contains_errors())
    run(tmp.front());
  // End Mu Test Teardown
  if (!Hide_errors && trace_contains_errors() && !Scenario_testing_scenario)
    Passed = false;
  if (not_already_inside_test && Trace_stream) {
    delete Trace_stream;
    Trace_stream = NULL;
  }
  Current_scenario = NULL;
}

//: Permit numeric locations to be accessed in scenarios.
:(before "End check_default_space Special-cases")
// user code should never create recipes with underscores in their names
if (starts_with(caller.name, "scenario_")) return;  // skip Mu scenarios which will use raw memory locations
if (starts_with(caller.name, "run_")) return;  // skip calls to 'run', which should be in scenarios and will also use raw memory locations

:(before "End maybe(recipe_name) Special-cases")
if (starts_with(recipe_name, "scenario_"))
  return recipe_name.substr(strlen("scenario_")) + ": ";

//: Some variables for fake resources always get special /raw addresses in scenarios.

:(code)
// Should contain everything passed by is_special_name but failed by is_disqualified.
void bind_special_scenario_names(const recipe_ordinal r) {
  // Special Scenario Variable Names(r)
  // End Special Scenario Variable Names(r)
}
:(before "Done Placing Ingredient(ingredient, inst, caller)")
maybe_make_raw(ingredient, caller);
:(before "Done Placing Product(product, inst, caller)")
maybe_make_raw(product, caller);
:(code)
void maybe_make_raw(reagent& r, const recipe& caller) {
  if (!is_special_name(r.name)) return;
  if (starts_with(caller.name, "scenario_"))
    r.properties.push_back(pair<string, string_tree*>("raw", NULL));
  // End maybe_make_raw
}

//: Test with some setup.
:(before "End is_special_name Special-cases")
if (s == "__maybe_make_raw_test__") return true;
:(before "End Special Scenario Variable Names(r)")
//: ugly: we only need this for this one test, but need to define it for all time
Name[r]["__maybe_make_raw_test__"] = Reserved_for_tests-1;
:(code)
void test_maybe_make_raw() {
  // check that scenarios can use local-scope and special variables together
  vector<recipe_ordinal> tmp = load(
      "def scenario_foo [\n"
      "  local-scope\n"
      "  __maybe_make_raw_test__:num <- copy 34\n"
      "]\n");
  mark_autogenerated(tmp.at(0));
  bind_special_scenario_names(tmp.at(0));
  transform_all();
  run(tmp.at(0));
  CHECK_TRACE_DOESNT_CONTAIN_ERRORS();
}

//: Watch out for redefinitions of scenario routines. We should never ever be
//: doing that, regardless of anything else.

void test_forbid_redefining_scenario_even_if_forced() {
  Hide_errors = true;
  Disable_redefine_checks = true;
  run(
      "def scenario-foo [\n"
      "  1:num <- copy 34\n"
      "]\n"
      "def scenario-foo [\n"
      "  1:num <- copy 35\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: redefining recipe scenario-foo\n"
  );
}

void test_scenario_containing_parse_error() {
  Hide_errors = true;
  run(
      "scenario foo [\n"
      "  memory-should-contain [\n"
      "    1 <- 0\n"
         // missing ']'
      "]\n"
  );
  // no crash
}

void test_scenario_containing_transform_error() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  local-scope\n"
      "  add x, 1\n"
      "]\n"
  );
  // no crash
}

:(after "bool should_check_for_redefine(const string& recipe_name)")
  if (recipe_name.find("scenario-") == 0) return true;

//:: The special instructions we want to support inside scenarios.
//: These are easy to support in an interpreter, but will require more work
//: when we eventually build a compiler.

//: 'run' is a purely lexical convenience to separate the code actually being
//: tested from any setup

:(code)
void test_run() {
  run(
      "def main [\n"
      "  run [\n"
      "    1:num <- copy 13\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 13 in location 1\n"
  );
}

:(before "End Rewrite Instruction(curr, recipe result)")
if (curr.name == "run") {
  // Just inline all instructions inside the run block in the containing
  // recipe. 'run' is basically a comment; pretend it doesn't exist.
  istringstream in2("[\n"+curr.ingredients.at(0).name+"\n]\n");
  slurp_body(in2, result);
  curr.clear();
}

:(code)
void test_run_multiple() {
  run(
      "def main [\n"
      "  run [\n"
      "    1:num <- copy 13\n"
      "  ]\n"
      "  run [\n"
      "    2:num <- copy 13\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 13 in location 1\n"
      "mem: storing 13 in location 2\n"
  );
}

//: 'memory-should-contain' raises errors if specific locations aren't as expected
//: Also includes some special support for checking Mu texts.

:(before "End Globals")
bool Scenario_testing_scenario = false;
:(before "End Reset")
Scenario_testing_scenario = false;

:(code)
void test_memory_check() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  memory-should-contain [\n"
      "    1 <- 13\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: checking location 1\n"
      "error: F - main: expected location '1' to contain 13 but saw 0\n"
  );
}

:(before "End Primitive Recipe Declarations")
MEMORY_SHOULD_CONTAIN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "memory-should-contain", MEMORY_SHOULD_CONTAIN);
:(before "End Primitive Recipe Checks")
case MEMORY_SHOULD_CONTAIN: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MEMORY_SHOULD_CONTAIN: {
  if (!Passed) break;
  check_memory(current_instruction().ingredients.at(0).name);
  break;
}

:(code)
void check_memory(const string& s) {
  istringstream in(s);
  in >> std::noskipws;
  set<int> locations_checked;
  while (true) {
    skip_whitespace_and_comments(in);
    if (!has_data(in)) break;
    string lhs = next_word(in);
    if (lhs.empty()) {
      assert(!has_data(in));
      raise << maybe(current_recipe_name()) << "incomplete 'memory-should-contain' block at end of file (0)\n" << end();
      return;
    }
    if (!is_integer(lhs)) {
      check_type(lhs, in);
      continue;
    }
    int address = to_integer(lhs);
    skip_whitespace_and_comments(in);
    string _assign;  in >> _assign;  assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    string rhs = next_word(in);
    if (rhs.empty()) {
      assert(!has_data(in));
      raise << maybe(current_recipe_name()) << "incomplete 'memory-should-contain' block at end of file (1)\n" << end();
      return;
    }
    if (!is_integer(rhs) && !is_noninteger(rhs)) {
      if (!Hide_errors) cerr << '\n';
      raise << "F - " << maybe(current_recipe_name()) << "location '" << address << "' can't contain non-number " << rhs << '\n' << end();
      if (!Scenario_testing_scenario) Passed = false;
      return;
    }
    double value = to_double(rhs);
    if (contains_key(locations_checked, address))
      raise << maybe(current_recipe_name()) << "duplicate expectation for location '" << address << "'\n" << end();
    trace(Callstack_depth+1, "run") << "checking location " << address << end();
    if (get_or_insert(Memory, address) != value) {
      if (!Hide_errors) cerr << '\n';
      raise << "F - " << maybe(current_recipe_name()) << "expected location '" << address << "' to contain " << no_scientific(value) << " but saw " << no_scientific(get_or_insert(Memory, address)) << '\n' << end();
      if (!Scenario_testing_scenario) Passed = false;
      return;
    }
    locations_checked.insert(address);
  }
}

void check_type(const string& lhs, istream& in) {
  reagent x(lhs);
  if (is_mu_array(x.type) && is_mu_character(array_element(x.type))) {
    x.set_value(to_integer(x.name));
    skip_whitespace_and_comments(in);
    string _assign = next_word(in);
    if (_assign.empty()) {
      assert(!has_data(in));
      raise << maybe(current_recipe_name()) << "incomplete 'memory-should-contain' block at end of file (2)\n" << end();
      return;
    }
    assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    string literal = next_word(in);
    if (literal.empty()) {
      assert(!has_data(in));
      raise << maybe(current_recipe_name()) << "incomplete 'memory-should-contain' block at end of file (3)\n" << end();
      return;
    }
    int address = x.value;
    // exclude quoting brackets
    if (*literal.begin() != '[') {
      raise << maybe(current_recipe_name()) << "array:character types inside 'memory-should-contain' can only be compared with text literals surrounded by [], not '" << literal << "'\n" << end();
      return;
    }
    literal.erase(literal.begin());
    assert(*--literal.end() == ']');  literal.erase(--literal.end());
    check_mu_text(address, literal);
    return;
  }
  // End Scenario Type Special-cases
  raise << "don't know how to check memory for '" << lhs << "'\n" << end();
}

void check_mu_text(int start, const string& literal) {
  trace(Callstack_depth+1, "run") << "checking text length at " << start << end();
  int array_length = static_cast<int>(get_or_insert(Memory, start));
  if (array_length != SIZE(literal)) {
    if (!Hide_errors) cerr << '\n';
    raise << "F - " << maybe(current_recipe_name()) << "expected location '" << start << "' to contain length " << SIZE(literal) << " of text [" << literal << "] but saw " << array_length << " (for text [" << read_mu_characters(start+/*skip length*/1, array_length) << "])\n" << end();
    if (!Scenario_testing_scenario) Passed = false;
    return;
  }
  int curr = start+1;  // now skip length
  for (int i = 0;  i < SIZE(literal);  ++i) {
    trace(Callstack_depth+1, "run") << "checking location " << curr+i << end();
    if (get_or_insert(Memory, curr+i) != literal.at(i)) {
      if (!Hide_errors) cerr << '\n';
      raise << "F - " << maybe(current_recipe_name()) << "expected location " << (curr+i) << " to contain " << literal.at(i) << " but saw " << no_scientific(get_or_insert(Memory, curr+i)) << '\n' << end();
      if (!Scenario_testing_scenario) Passed = false;
      return;
    }
  }
}

void test_memory_check_multiple() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  memory-should-contain [\n"
      "    1 <- 0\n"
      "    1 <- 0\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: duplicate expectation for location '1'\n"
  );
}

void test_memory_check_mu_text_length() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:num <- copy 3\n"
      "  2:num <- copy 97  # 'a'\n"
      "  3:num <- copy 98  # 'b'\n"
      "  4:num <- copy 99  # 'c'\n"
      "  memory-should-contain [\n"
      "    1:array:character <- [ab]\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: expected location '1' to contain length 2 of text [ab] but saw 3 (for text [abc])\n"
  );
}

void test_memory_check_mu_text() {
  run(
      "def main [\n"
      "  1:num <- copy 3\n"
      "  2:num <- copy 97\n"  // 'a'
      "  3:num <- copy 98\n"  // 'b'
      "  4:num <- copy 99\n"  // 'c'
      "  memory-should-contain [\n"
      "    1:array:character <- [abc]\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: checking text length at 1\n"
      "run: checking location 2\n"
      "run: checking location 3\n"
      "run: checking location 4\n"
  );
}

void test_memory_invalid_string_check() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  memory-should-contain [\n"
      "    1 <- [abc]\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: location '1' can't contain non-number [abc]\n"
  );
}

void test_memory_invalid_string_check2() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:num <- copy 3\n"
      "  2:num <- copy 97\n"  // 'a'
      "  3:num <- copy 98\n"  // 'b'
      "  4:num <- copy 99\n"  // 'c'
      "  memory-should-contain [\n"
      "    1:array:character <- 0\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: array:character types inside 'memory-should-contain' can only be compared with text literals surrounded by [], not '0'\n"
  );
}

void test_memory_check_with_comment() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  memory-should-contain [\n"
      "    1 <- 34  # comment\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("error: location 1 can't contain non-number 34  # comment");
  // but there'll be an error signalled by memory-should-contain
}

//: 'trace-should-contain' is like the '+' lines in our scenarios so far
//: Like runs of contiguous '+' lines, order is important. The trace checks
//: that the lines are present *and* in the specified sequence. (There can be
//: other lines in between.)

void test_trace_check_fails() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
         // nothing added to the trace
      "  trace-should-contain [\n"
      "    a: b\n"
      "    a: d\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: missing [b] in trace with label 'a'\n"
  );
}

:(before "End Primitive Recipe Declarations")
TRACE_SHOULD_CONTAIN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "trace-should-contain", TRACE_SHOULD_CONTAIN);
:(before "End Primitive Recipe Checks")
case TRACE_SHOULD_CONTAIN: {
  break;
}
:(before "End Primitive Recipe Implementations")
case TRACE_SHOULD_CONTAIN: {
  if (!Passed) break;
  check_trace(current_instruction().ingredients.at(0).name);
  break;
}

:(code)
// simplified version of check_trace_contents() that emits errors rather
// than just printing to stderr
void check_trace(const string& expected) {
  Trace_stream->newline();
  vector<trace_line> expected_lines = parse_trace(expected);
  if (expected_lines.empty()) return;
  int curr_expected_line = 0;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin();  p != Trace_stream->past_lines.end();  ++p) {
    if (expected_lines.at(curr_expected_line).label != p->label) continue;
    if (expected_lines.at(curr_expected_line).contents != trim(p->contents)) continue;
    // match
    ++curr_expected_line;
    if (curr_expected_line == SIZE(expected_lines)) return;
  }
  if (!Hide_errors) cerr << '\n';
  raise << "F - " << maybe(current_recipe_name()) << "missing [" << expected_lines.at(curr_expected_line).contents << "] "
        << "in trace with label '" << expected_lines.at(curr_expected_line).label << "'\n" << end();
  if (!Hide_errors)
    DUMP(expected_lines.at(curr_expected_line).label);
  if (!Scenario_testing_scenario) Passed = false;
}

vector<trace_line> parse_trace(const string& expected) {
  vector<string> buf = split(expected, "\n");
  vector<trace_line> result;
  const string separator = ": ";
  for (int i = 0;  i < SIZE(buf);  ++i) {
    buf.at(i) = trim(buf.at(i));
    if (buf.at(i).empty()) continue;
    int delim = buf.at(i).find(separator);
    if (delim == -1) {
      raise << maybe(current_recipe_name()) << "lines in 'trace-should-contain' should be of the form <label>: <contents>. Both parts are required.\n" << end();
      result.clear();
      return result;
    }
    result.push_back(trace_line(/*contents*/  trim(buf.at(i).substr(delim+SIZE(separator)        )),
                                /*label*/     trim(buf.at(i).substr(0,                      delim))));
  }
  return result;
}

void test_trace_check_fails_in_nonfirst_line() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  run [\n"
      "    trace 1, [a], [b]\n"
      "  ]\n"
      "  trace-should-contain [\n"
      "    a: b\n"
      "    a: d\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: missing [d] in trace with label 'a'\n"
  );
}

void test_trace_check_passes_silently() {
  Scenario_testing_scenario = true;
  run(
      "def main [\n"
      "  run [\n"
      "    trace 1, [a], [b]\n"
      "  ]\n"
      "  trace-should-contain [\n"
      "    a: b\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("error: missing [b] in trace with label 'a'");
  CHECK_TRACE_COUNT("error", 0);
}

//: 'trace-should-not-contain' checks each line in its argument for absence.
//: Order is *not* important, so you can't say things like "B should not exist
//: after A."

void test_trace_negative_check_fails() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  run [\n"
      "    trace 1, [a], [b]\n"
      "  ]\n"
      "  trace-should-not-contain [\n"
      "    a: b\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: unexpected [b] in trace with label 'a'\n"
  );
}

:(before "End Primitive Recipe Declarations")
TRACE_SHOULD_NOT_CONTAIN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "trace-should-not-contain", TRACE_SHOULD_NOT_CONTAIN);
:(before "End Primitive Recipe Checks")
case TRACE_SHOULD_NOT_CONTAIN: {
  break;
}
:(before "End Primitive Recipe Implementations")
case TRACE_SHOULD_NOT_CONTAIN: {
  if (!Passed) break;
  check_trace_missing(current_instruction().ingredients.at(0).name);
  break;
}

:(code)
// simplified version of check_trace_contents() that emits errors rather
// than just printing to stderr
bool check_trace_missing(const string& in) {
  Trace_stream->newline();
  vector<trace_line> lines = parse_trace(in);
  for (int i = 0;  i < SIZE(lines);  ++i) {
    if (trace_count(lines.at(i).label, lines.at(i).contents) != 0) {
      raise << "F - " << maybe(current_recipe_name()) << "unexpected [" << lines.at(i).contents << "] in trace with label '" << lines.at(i).label << "'\n" << end();
      if (!Scenario_testing_scenario) Passed = false;
      return false;
    }
  }
  return true;
}

void test_trace_negative_check_passes_silently() {
  Scenario_testing_scenario = true;
  run(
      "def main [\n"
      "  trace-should-not-contain [\n"
      "    a: b\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("error: unexpected [b] in trace with label 'a'");
  CHECK_TRACE_COUNT("error", 0);
}

void test_trace_negative_check_fails_on_any_unexpected_line() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  run [\n"
      "    trace 1, [a], [d]\n"
      "  ]\n"
      "  trace-should-not-contain [\n"
      "    a: b\n"
      "    a: d\n"
      "  ]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: unexpected [d] in trace with label 'a'\n"
  );
}

void test_trace_count_check() {
  run(
      "def main [\n"
      "  run [\n"
      "    trace 1, [a], [foo]\n"
      "  ]\n"
      "  check-trace-count-for-label 1, [a]\n"
      "]\n"
  );
  // checks are inside scenario
}

:(before "End Primitive Recipe Declarations")
CHECK_TRACE_COUNT_FOR_LABEL,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "check-trace-count-for-label", CHECK_TRACE_COUNT_FOR_LABEL);
:(before "End Primitive Recipe Checks")
case CHECK_TRACE_COUNT_FOR_LABEL: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'check-trace-count-for-label' requires exactly two ingredients, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'check-trace-count-for-label' should be a number (count), but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  if (!is_literal_text(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'check-trace-count-for-label' should be a literal string (label), but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CHECK_TRACE_COUNT_FOR_LABEL: {
  if (!Passed) break;
  int expected_count = ingredients.at(0).at(0);
  string label = current_instruction().ingredients.at(1).name;
  int count = trace_count(label);
  if (count != expected_count) {
    if (!Hide_errors) cerr << '\n';
    raise << "F - " << maybe(current_recipe_name()) << "expected " << expected_count << " lines in trace with label '" << label << "' in trace\n" << end();
    if (!Hide_errors) DUMP(label);
    if (!Scenario_testing_scenario) Passed = false;
  }
  break;
}

:(before "End Primitive Recipe Declarations")
CHECK_TRACE_COUNT_FOR_LABEL_GREATER_THAN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "check-trace-count-for-label-greater-than", CHECK_TRACE_COUNT_FOR_LABEL_GREATER_THAN);
:(before "End Primitive Recipe Checks")
case CHECK_TRACE_COUNT_FOR_LABEL_GREATER_THAN: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'check-trace-count-for-label' requires exactly two ingredients, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'check-trace-count-for-label' should be a number (count), but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  if (!is_literal_text(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'check-trace-count-for-label' should be a literal string (label), but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CHECK_TRACE_COUNT_FOR_LABEL_GREATER_THAN: {
  if (!Passed) break;
  int expected_count = ingredients.at(0).at(0);
  string label = current_instruction().ingredients.at(1).name;
  int count = trace_count(label);
  if (count <= expected_count) {
    if (!Hide_errors) cerr << '\n';
    raise << maybe(current_recipe_name()) << "expected more than " << expected_count << " lines in trace with label '" << label << "' in trace\n" << end();
    if (!Hide_errors) {
      cerr << "trace contents:\n";
      DUMP(label);
    }
    if (!Scenario_testing_scenario) Passed = false;
  }
  break;
}

:(before "End Primitive Recipe Declarations")
CHECK_TRACE_COUNT_FOR_LABEL_LESSER_THAN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "check-trace-count-for-label-lesser-than", CHECK_TRACE_COUNT_FOR_LABEL_LESSER_THAN);
:(before "End Primitive Recipe Checks")
case CHECK_TRACE_COUNT_FOR_LABEL_LESSER_THAN: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'check-trace-count-for-label' requires exactly two ingredients, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'check-trace-count-for-label' should be a number (count), but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  if (!is_literal_text(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'check-trace-count-for-label' should be a literal string (label), but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case CHECK_TRACE_COUNT_FOR_LABEL_LESSER_THAN: {
  if (!Passed) break;
  int expected_count = ingredients.at(0).at(0);
  string label = current_instruction().ingredients.at(1).name;
  int count = trace_count(label);
  if (count >= expected_count) {
    if (!Hide_errors) cerr << '\n';
    raise << "F - " << maybe(current_recipe_name()) << "expected less than " << expected_count << " lines in trace with label '" << label << "' in trace\n" << end();
    if (!Hide_errors) {
      cerr << "trace contents:\n";
      DUMP(label);
    }
    if (!Scenario_testing_scenario) Passed = false;
  }
  break;
}

:(code)
void test_trace_count_check_2() {
  Scenario_testing_scenario = true;
  Hide_errors = true;
  run(
      "def main [\n"
      "  run [\n"
      "    trace 1, [a], [foo]\n"
      "  ]\n"
      "  check-trace-count-for-label 2, [a]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: F - main: expected 2 lines in trace with label 'a' in trace\n"
  );
}

//: Minor detail: ignore 'system' calls in scenarios, since anything we do
//: with them is by definition impossible to test through Mu.
:(after "case _SYSTEM:")
  if (Current_scenario) break;

//:: Warn if people use '_' manually in recipe names. They're reserved for internal use.

:(code)
void test_recipe_name_with_underscore() {
  Hide_errors = true;
  run(
      "def foo_bar [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo_bar: don't create recipes with '_' in the name\n"
  );
}

:(before "End recipe Fields")
bool is_autogenerated;
:(before "End recipe Constructor")
is_autogenerated = false;
:(code)
void mark_autogenerated(recipe_ordinal r) {
  get(Recipe, r).is_autogenerated = true;
}

:(after "void transform_all()")
  for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin();  p != Recipe.end();  ++p) {
    const recipe& r = p->second;
    if (r.name.find('_') == string::npos) continue;
    if (r.is_autogenerated) continue;  // created by previous call to transform_all()
    raise << r.name << ": don't create recipes with '_' in the name\n" << end();
  }

//:: Helpers

:(code)
// just for the scenarios running scenarios in C++ layers
void run_mu_scenario(const string& form) {
  Scenario_names.clear();
  istringstream in(form);
  in >> std::noskipws;
  skip_whitespace_and_comments(in);
  string _scenario = next_word(in);
  if (_scenario.empty()) {
    assert(!has_data(in));
    raise << "no scenario in string passed into run_mu_scenario()\n" << end();
    return;
  }
  assert(_scenario == "scenario");
  scenario s = parse_scenario(in);
  run_mu_scenario(s);
}

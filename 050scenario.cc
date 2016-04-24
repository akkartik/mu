//: Mu scenarios. This will get long, but these are the tests we want to
//: support in this layer.

//: You can use variable names in scenarios, but for the most part we'll use
//: raw location numbers, because that lets us make assertions on memory.
//: Tests should avoid abstraction as far as possible.
:(scenarios run_mu_scenario)
:(scenario scenario_block)
scenario foo [
  run [
    1:number <- copy 13
  ]
  memory-should-contain [
    1 <- 13
  ]
]
# checks are inside scenario

:(scenario scenario_multiple_blocks)
scenario foo [
  run [
    1:number <- copy 13
  ]
  memory-should-contain [
    1 <- 13
  ]
  run [
    2:number <- copy 13
  ]
  memory-should-contain [
    1 <- 13
    2 <- 13
  ]
]

:(scenario scenario_check_memory_and_trace)
scenario foo [
  run [
    1:number <- copy 13
    trace 1, [a], [a b c]
  ]
  memory-should-contain [
    1 <- 13
  ]
  trace-should-contain [
    a: a b c
  ]
  trace-should-not-contain [
    a: x y z
  ]
]

//:: Core data structure

:(before "End Types")
struct scenario {
  string name;
  string to_run;
};

:(before "End Globals")
vector<scenario> Scenarios;
set<string> Scenario_names;

//:: Parse the 'scenario' form.
//: Simply store the text of the scenario.

:(before "End Command Handlers")
else if (command == "scenario") {
  Scenarios.push_back(parse_scenario(in));
}

:(code)
scenario parse_scenario(istream& in) {
  scenario result;
  result.name = next_word(in);
  if (contains_key(Scenario_names, result.name))
    raise << "duplicate scenario name: " << result.name << '\n' << end();
  Scenario_names.insert(result.name);
  skip_whitespace_and_comments(in);
  assert(in.peek() == '[');
  // scenarios are take special 'code' strings so we need to ignore brackets
  // inside comments
  result.to_run = slurp_quoted(in);
  // delete [] delimiters
  assert(result.to_run.at(0) == '[');
  result.to_run.erase(0, 1);
  assert(result.to_run.at(SIZE(result.to_run)-1) == ']');
  result.to_run.erase(SIZE(result.to_run)-1);
  return result;
}

:(scenario read_scenario_with_bracket_in_comment)
scenario foo [
  # ']' in comment
  1:number <- copy 0
]
+run: {1: "number"} <- copy {0: "literal"}

:(scenario read_scenario_with_bracket_in_comment_in_nested_string)
scenario foo [
  1:address:array:character <- new [# not a comment]
]
+run: {1: ("address" "array" "character")} <- new {"# not a comment": "literal-string"}

//:: Run scenarios when we run 'mu test'.
//: Treat the text of the scenario as a regular series of instructions.

:(before "End Globals")
int Num_core_mu_tests = 0;
:(after "Check For .mu Files")
Num_core_mu_tests = SIZE(Scenarios);
:(before "End Tests")
Hide_missing_default_space_errors = false;
time_t mu_time; time(&mu_time);
cerr << "\nMu tests: " << ctime(&mu_time);
for (int i = 0; i < SIZE(Scenarios); ++i) {
//?   cerr << i << ": " << Scenarios.at(i).name << '\n';
  if (i == Num_core_mu_tests) {
    time(&t);
    cerr << "\nApp tests: " << ctime(&t);
  }
  run_mu_scenario(Scenarios.at(i));
  if (Passed) cerr << ".";
}

//: Convenience: run a single named scenario.
:(after "Test Runs")
for (int i = 0; i < SIZE(Scenarios); ++i) {
  if (Scenarios.at(i).name == argv[argc-1]) {
    run_mu_scenario(Scenarios.at(i));
    if (Passed) cerr << ".\n";
    return 0;
  }
}

:(before "End Globals")
const scenario* Current_scenario = NULL;
:(code)
void run_mu_scenario(const scenario& s) {
  Current_scenario = &s;
  bool not_already_inside_test = !Trace_stream;
//?   cerr << s.name << '\n';
  if (not_already_inside_test) {
    Trace_file = s.name;
    Trace_stream = new trace_stream;
    setup();
  }
  vector<recipe_ordinal> tmp = load("recipe scenario_"+s.name+" [ "+s.to_run+" ]");
  bind_special_scenario_names(tmp.at(0));
  transform_all();
  run(tmp.front());
  if (Passed && !Hide_errors && trace_count("error") > 0) {
    Passed = false;
    ++Num_failures;
  }
  // End Mu Test Teardown
  if (not_already_inside_test && Trace_stream) {
    teardown();
    ofstream fout((Trace_dir+Trace_file).c_str());
    fout << Trace_stream->readable_contents("");
    fout.close();
    delete Trace_stream;
    Trace_stream = NULL;
    Trace_file = "";
  }
  Current_scenario = NULL;
}

//: Watch out for redefinitions of scenario routines. We should never ever be
//: doing that, regardless of anything else.
:(scenarios run)
:(scenario forbid_redefining_scenario_even_if_forced)
% Hide_errors = true;
% Disable_redefine_checks = true;
def scenario-foo [
  1:number <- copy 34
]

def scenario-foo [
  1:number <- copy 35
]
+error: redefining recipe scenario-foo

:(after "bool should_check_for_redefine(const string& recipe_name)")
  if (recipe_name.find("scenario-") == 0) return true;

//:: The special instructions we want to support inside scenarios.
//: In a compiler for the mu VM these will require more work.

//: 'run' interprets a string as a set of instructions

:(scenario run)
def main [
  run [
    1:number <- copy 13
  ]
]
+mem: storing 13 in location 1

:(before "End Primitive Recipe Declarations")
RUN,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "run", RUN);
:(before "End Primitive Recipe Checks")
case RUN: {
  break;
}
:(before "End Primitive Recipe Implementations")
case RUN: {
  assert(Name[Next_recipe_ordinal].empty());
  ostringstream tmp;
  tmp << "recipe run_" << Next_recipe_ordinal << " [ " << current_instruction().ingredients.at(0).name << " ]";
  vector<recipe_ordinal> tmp_recipe = load(tmp.str());
  bind_special_scenario_names(tmp_recipe.at(0));
  transform_all();
  if (Trace_stream) {
    ++Trace_stream->callstack_depth;
    trace(9998, "trace") << "run: incrementing callstack depth to " << Trace_stream->callstack_depth << end();
    assert(Trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  Current_routine->calls.push_front(call(tmp_recipe.at(0)));
  continue;  // not done with caller; don't increment current_step_index()
}

// Some variables for fake resources always get special addresses in
// scenarios.
:(code)
void bind_special_scenario_names(recipe_ordinal r) {
  // Special Scenario Variable Names(r)
  // End Special Scenario Variable Names(r)
}

:(scenario run_multiple)
def main [
  run [
    1:number <- copy 13
  ]
  run [
    2:number <- copy 13
  ]
]
+mem: storing 13 in location 1
+mem: storing 13 in location 2

//: 'memory-should-contain' raises errors if specific locations aren't as expected
//: Also includes some special support for checking strings.

:(before "End Globals")
bool Scenario_testing_scenario = false;
:(before "End Setup")
Scenario_testing_scenario = false;

:(scenario memory_check)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  memory-should-contain [
    1 <- 13
  ]
]
+run: checking location 1
+error: expected location 1 to contain 13 but saw 0

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
    if (!is_integer(lhs)) {
      check_type(lhs, in);
      continue;
    }
    int address = to_integer(lhs);
    skip_whitespace_and_comments(in);
    string _assign;  in >> _assign;  assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    string rhs = next_word(in);
    if (!is_integer(rhs) && !is_noninteger(rhs)) {
      if (Current_scenario && !Scenario_testing_scenario)
        // genuine test in a mu file
        raise << "\nF - " << Current_scenario->name << ": location " << address << " can't contain non-number " << rhs << '\n' << end();
      else
        // just testing scenario support
        raise << "location " << address << " can't contain non-number " << rhs << '\n' << end();
      if (!Scenario_testing_scenario) {
        Passed = false;
        ++Num_failures;
      }
      return;
    }
    double value = to_double(rhs);
    if (contains_key(locations_checked, address))
      raise << "duplicate expectation for location " << address << '\n' << end();
    trace(9999, "run") << "checking location " << address << end();
    if (get_or_insert(Memory, address) != value) {
      if (Current_scenario && !Scenario_testing_scenario) {
        // genuine test in a mu file
        raise << "\nF - " << Current_scenario->name << ": expected location " << address << " to contain " << no_scientific(value) << " but saw " << no_scientific(get_or_insert(Memory, address)) << '\n' << end();
      }
      else {
        // just testing scenario support
        raise << "expected location " << address << " to contain " << no_scientific(value) << " but saw " << no_scientific(get_or_insert(Memory, address)) << '\n' << end();
      }
      if (!Scenario_testing_scenario) {
        Passed = false;
        ++Num_failures;
      }
      return;
    }
    locations_checked.insert(address);
  }
}

void check_type(const string& lhs, istream& in) {
  reagent x(lhs);
  if (x.type->name == "array"
      && x.type->right && x.type->right->name == "character"
      && !x.type->right->right) {
    x.set_value(to_integer(x.name));
    skip_whitespace_and_comments(in);
    string _assign = next_word(in);
    assert(_assign == "<-");
    skip_whitespace_and_comments(in);
    string literal = next_word(in);
    int address = x.value;
    // exclude quoting brackets
    assert(*literal.begin() == '[');  literal.erase(literal.begin());
    assert(*--literal.end() == ']');  literal.erase(--literal.end());
    check_string(address, literal);
    return;
  }
  // End Scenario Type Cases
  raise << "don't know how to check memory for " << lhs << '\n' << end();
}

void check_string(int address, const string& literal) {
  trace(9999, "run") << "checking string length at " << address << end();
  if (get_or_insert(Memory, address) != SIZE(literal)) {
    if (Current_scenario && !Scenario_testing_scenario)
      raise << "\nF - " << Current_scenario->name << ": expected location " << address << " to contain length " << SIZE(literal) << " of string [" << literal << "] but saw " << no_scientific(get_or_insert(Memory, address)) << " (" << read_mu_string(address) << ")\n" << end();
    else
      raise << "expected location " << address << " to contain length " << SIZE(literal) << " of string [" << literal << "] but saw " << no_scientific(get_or_insert(Memory, address)) << '\n' << end();
    if (!Scenario_testing_scenario) {
      Passed = false;
      ++Num_failures;
    }
    return;
  }
  ++address;  // now skip length
  for (int i = 0; i < SIZE(literal); ++i) {
    trace(9999, "run") << "checking location " << address+i << end();
    if (get_or_insert(Memory, address+i) != literal.at(i)) {
      if (Current_scenario && !Scenario_testing_scenario) {
        // genuine test in a mu file
        raise << "\nF - " << Current_scenario->name << ": expected location " << (address+i) << " to contain " << literal.at(i) << " but saw " << no_scientific(get_or_insert(Memory, address+i)) << " ('" << static_cast<char>(get_or_insert(Memory, address+i)) << "')\n" << end();
      }
      else {
        // just testing scenario support
        raise << "expected location " << (address+i) << " to contain " << literal.at(i) << " but saw " << no_scientific(get_or_insert(Memory, address+i)) << '\n' << end();
      }
      if (!Scenario_testing_scenario) {
        Passed = false;
        ++Num_failures;
      }
      return;
    }
  }
}

:(scenario memory_check_multiple)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  memory-should-contain [
    1 <- 0
    1 <- 0
  ]
]
+error: duplicate expectation for location 1

:(scenario memory_check_string_length)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  1:number <- copy 3
  2:number <- copy 97  # 'a'
  3:number <- copy 98  # 'b'
  4:number <- copy 99  # 'c'
  memory-should-contain [
    1:array:character <- [ab]
  ]
]
+error: expected location 1 to contain length 2 of string [ab] but saw 3

:(scenario memory_check_string)
def main [
  1:number <- copy 3
  2:number <- copy 97  # 'a'
  3:number <- copy 98  # 'b'
  4:number <- copy 99  # 'c'
  memory-should-contain [
    1:array:character <- [abc]
  ]
]
+run: checking string length at 1
+run: checking location 2
+run: checking location 3
+run: checking location 4

:(scenario memory_invalid_string_check)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  memory-should-contain [
    1 <- [abc]
  ]
]
+error: location 1 can't contain non-number [abc]

:(scenario memory_check_with_comment)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  memory-should-contain [
    1 <- 34  # comment
  ]
]
-error: location 1 can't contain non-number 34  # comment
# but there'll be an error signalled by memory-should-contain

:(code)
//: 'trace-should-contain' is like the '+' lines in our scenarios so far
// Like runs of contiguous '+' lines, order is important. The trace checks
// that the lines are present *and* in the specified sequence. (There can be
// other lines in between.)

:(scenario trace_check_fails)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  trace-should-contain [
    a: b
    a: d
  ]
]
+error: missing [b] in trace with label a

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
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (expected_lines.at(curr_expected_line).label != p->label) continue;
    if (expected_lines.at(curr_expected_line).contents != trim(p->contents)) continue;
    // match
    ++curr_expected_line;
    if (curr_expected_line == SIZE(expected_lines)) return;
  }

  raise << "missing [" << expected_lines.at(curr_expected_line).contents << "] "
              << "in trace with label " << expected_lines.at(curr_expected_line).label << '\n' << end();
  Passed = false;
}

vector<trace_line> parse_trace(const string& expected) {
  vector<string> buf = split(expected, "\n");
  vector<trace_line> result;
  for (int i = 0; i < SIZE(buf); ++i) {
    buf.at(i) = trim(buf.at(i));
    if (buf.at(i).empty()) continue;
    int delim = buf.at(i).find(": ");
    result.push_back(trace_line(trim(buf.at(i).substr(0, delim)),  trim(buf.at(i).substr(delim+2))));
  }
  return result;
}

:(scenario trace_check_fails_in_nonfirst_line)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  run [
    trace 1, [a], [b]
  ]
  trace-should-contain [
    a: b
    a: d
  ]
]
+error: missing [d] in trace with label a

:(scenario trace_check_passes_silently)
% Scenario_testing_scenario = true;
def main [
  run [
    trace 1, [a], [b]
  ]
  trace-should-contain [
    a: b
  ]
]
-error: missing [b] in trace with label a
$error: 0

//: 'trace-should-not-contain' is like the '-' lines in our scenarios so far
//: Each trace line is separately checked for absense. Order is *not*
//: important, so you can't say things like "B should not exist after A."

:(scenario trace_negative_check_fails)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  run [
    trace 1, [a], [b]
  ]
  trace-should-not-contain [
    a: b
  ]
]
+error: unexpected [b] in trace with label a

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
  for (int i = 0; i < SIZE(lines); ++i) {
    if (trace_count(lines.at(i).label, lines.at(i).contents) != 0) {
      raise << "unexpected [" << lines.at(i).contents << "] in trace with label " << lines.at(i).label << '\n' << end();
      Passed = false;
      return false;
    }
  }
  return true;
}

:(scenario trace_negative_check_passes_silently)
% Scenario_testing_scenario = true;
def main [
  trace-should-not-contain [
    a: b
  ]
]
-error: unexpected [b] in trace with label a
$error: 0

:(scenario trace_negative_check_fails_on_any_unexpected_line)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  run [
    trace 1, [a], [d]
  ]
  trace-should-not-contain [
    a: b
    a: d
  ]
]
+error: unexpected [d] in trace with label a

:(scenario trace_count_check)
def main [
  run [
    trace 1, [a], [foo]
  ]
  check-trace-count-for-label 1, [a]
]

:(before "End Primitive Recipe Declarations")
CHECK_TRACE_COUNT_FOR_LABEL,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "check-trace-count-for-label", CHECK_TRACE_COUNT_FOR_LABEL);
:(before "End Primitive Recipe Checks")
case CHECK_TRACE_COUNT_FOR_LABEL: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'check-trace-for-label' requires exactly two ingredients, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'check-trace-for-label' should be a number (count), but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!is_literal_string(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'check-trace-for-label' should be a literal string (label), but got " << inst.ingredients.at(1).original_string << '\n' << end();
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
    if (Current_scenario && !Scenario_testing_scenario) {
      // genuine test in a mu file
      raise << "\nF - " << Current_scenario->name << ": " << maybe(current_recipe_name()) << "expected " << expected_count << " lines in trace with label " << label << " in trace: " << end();
      DUMP(label);
    }
    else {
      // just testing scenario support
      raise << maybe(current_recipe_name()) << "expected " << expected_count << " lines in trace with label " << label << " in trace\n" << end();
    }
    if (!Scenario_testing_scenario) {
      Passed = false;
      ++Num_failures;
    }
  }
  break;
}

:(scenario trace_count_check_2)
% Scenario_testing_scenario = true;
% Hide_errors = true;
def main [
  run [
    trace 1, [a], [foo]
  ]
  check-trace-count-for-label 2, [a]
]
+error: main: expected 2 lines in trace with label a in trace

//: Minor detail: ignore 'system' calls in scenarios, since anything we do
//: with them is by definition impossible to test through mu.
:(after "case _SYSTEM:")
  if (Current_scenario) break;

//:: Helpers

:(code)
// just for the scenarios running scenarios in C++ layers
void run_mu_scenario(const string& form) {
  Scenario_names.clear();
  istringstream in(form);
  in >> std::noskipws;
  skip_whitespace_and_comments(in);
  string _scenario = next_word(in);
  assert(_scenario == "scenario");
  scenario s = parse_scenario(in);
  run_mu_scenario(s);
}

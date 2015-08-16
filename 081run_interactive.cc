//: Helper for various programming environments: run arbitrary mu code and
//: return some result in string form.

:(scenario run_interactive_code)
recipe main [
  1:address:array:character <- new [add 2, 2]
  2:address:array:character <- run-interactive 1:address:array:character
  3:array:character <- copy *2:address:array:character
]
# length of result array is flexible; but first character is '4'
+mem: storing 52 in location 4

:(scenario run_interactive_empty)
recipe main [
  1:address:array:character <- run-interactive 0
]
# result is null
+mem: storing 0 in location 1

//: run code in 'interactive mode', i.e. with warnings off and return:
//:   stringified output in case we want to print it to screen
//:   any warnings encountered
//:   simulated screen any prints went to
//:   any 'app' layer traces generated
:(before "End Primitive Recipe Declarations")
RUN_INTERACTIVE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["run-interactive"] = RUN_INTERACTIVE;
//? cerr << "run-interactive: " << RUN_INTERACTIVE << '\n'; //? 1
:(before "End Primitive Recipe Implementations")
case RUN_INTERACTIVE: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'run-interactive' requires exactly one ingredient, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << current_recipe_name() << ": first ingredient of 'run-interactive' should be a literal string, but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
  bool new_code_pushed_to_stack = run_interactive(ingredients.at(0).at(0));
  if (!new_code_pushed_to_stack) {
    products.resize(4);
    products.at(0).push_back(0);
    products.at(1).push_back(trace_contents("warn"));
    products.at(2).push_back(0);
    products.at(3).push_back(trace_contents("app"));
    clean_up_interactive();
    break;  // done with this instruction
  }
  else {
    continue;  // not done with caller; don't increment current_step_index()
  }
}

:(before "End Globals")
bool Track_most_recent_products = false;
:(before "End Setup")
Track_most_recent_products = false;
:(code)
// reads a string, tries to call it as code (treating it as a test), saving
// all warnings.
// returns true if successfully called (no errors found during load and transform)
bool run_interactive(long long int address) {
  if (Recipe_ordinal.find("interactive") == Recipe_ordinal.end())
    Recipe_ordinal["interactive"] = Next_recipe_ordinal++;
  // try to sandbox the run as best you can
  // todo: test this
  if (!Current_scenario) {
    for (long long int i = 1; i < Reserved_for_tests; ++i)
      Memory.erase(i);
  }
  string command = trim(strip_comments(read_mu_string(address)));
  if (command.empty()) return false;
  Recipe.erase(Recipe_ordinal["interactive"]);
  Name[Recipe_ordinal["interactive"]].clear();
  Hide_warnings = true;
  if (!Trace_stream) {
    Trace_file = "";  // if there wasn't already a stream we don't want to save it
    Trace_stream = new trace_stream;
    Trace_stream->collect_layers.insert("warn");
    Trace_stream->collect_layers.insert("app");
  }
  // call run(string) but without the scheduling
  load(string("recipe interactive [\n") +
          "local-scope\n" +
          "screen:address <- new-fake-screen 30, 5\n" +
          command + "\n" +
          "reply screen\n" +
       "]\n");
  transform_all();
  if (trace_count("warn") > 0) return false;
  Track_most_recent_products = true;
  Current_routine->calls.push_front(call(Recipe_ordinal["interactive"]));
  return true;
}

:(scenario "run_interactive_returns_stringified_result")
recipe main [
  # try to interactively add 2 and 2
  1:address:array:character <- new [add 2, 2]
  2:address:array:character <- run-interactive 1:address:array:character
  10:array:character <- copy 2:address:array:character/lookup
]
# first letter in the output should be '4' in unicode
+mem: storing 52 in location 11

:(scenario "run_interactive_returns_string")
recipe main [
  # try to interactively add 2 and 2
  1:address:array:character <- new [
    100:address:array:character <- new [a]
    101:address:array:character <- new [b]
    102:address:array:character <- string-append 100:address:array:character, 101:address:array:character
  ]
  2:address:array:character <- run-interactive 1:address:array:character
  10:array:character <- copy 2:address:array:character/lookup
]
# output contains "ab"
+mem: storing 97 in location 11
+mem: storing 98 in location 12

:(scenario "run_interactive_returns_warnings")
recipe main [
  # run a command that generates a warning
  1:address:array:character <- new [get 1234:number, foo:offset]
  2:address:array:character, 3:address:array:character <- run-interactive 1:address:array:character
  10:array:character <- copy 3:address:array:character/lookup
]
# warning should be "unknown element foo in container number"
+mem: storing 117 in location 11
+mem: storing 110 in location 12
+mem: storing 107 in location 13
+mem: storing 110 in location 14

:(before "End Globals")
string Most_recent_products;
:(before "End Setup")
Most_recent_products = "";
:(before "End of Instruction")
if (Track_most_recent_products) {
  track_most_recent_products(current_instruction(), products);
}
:(code)
void track_most_recent_products(const instruction& instruction, const vector<vector<double> >& products) {
  ostringstream out;
  for (long long int i = 0; i < SIZE(products); ++i) {
    // string
    if (i < SIZE(instruction.products)) {
      if (is_mu_string(instruction.products.at(i))) {
        if (!scalar(products.at(i))) {
          tb_shutdown();
          cerr << read_mu_string(trace_contents("warn")) << '\n';
          cerr << SIZE(products.at(i)) << ": ";
          for (long long int j = 0; j < SIZE(products.at(i)); ++j)
            cerr << products.at(i).at(j) << ' ';
          cerr << '\n';
        }
        assert(scalar(products.at(i)));
        out << read_mu_string(products.at(i).at(0)) << '\n';
        continue;
      }
      // End Record Product Special-cases
    }
    for (long long int j = 0; j < SIZE(products.at(i)); ++j)
      out << products.at(i).at(j) << ' ';
    out << '\n';
  }
  Most_recent_products = out.str();
}

//: Recipe 'interactive' doesn't return what 'run-interactive seems to return.
//: Massage results from former to latter.

:(after "Starting Reply")
if (Current_routine->calls.front().running_recipe == Recipe_ordinal["interactive"]) {
  products.resize(4);
  products.at(0).push_back(new_mu_string(Most_recent_products));
  products.at(1).push_back(trace_contents("warn"));
  assert(SIZE(ingredients) == 1);
  assert(scalar(ingredients.at(0)));
  products.at(2).push_back(ingredients.at(0).at(0));  // screen
  products.at(3).push_back(trace_contents("app"));
  --Callstack_depth;
  Current_routine->calls.pop_front();
  assert(!Current_routine->calls.empty());
  clean_up_interactive();
  break;
}

//: clean up reply after we've popped it off the call-stack
:(code)
void clean_up_interactive() {
  Hide_warnings = false;
  Track_most_recent_products = false;
  if (Trace_stream->is_narrowly_collecting("warn")) {  // hack
    delete Trace_stream;
    Trace_stream = NULL;
  }
}

:(code)
string strip_comments(string in) {
  ostringstream result;
  for (long long int i = 0; i < SIZE(in); ++i) {
    if (in.at(i) != '#') {
      result << in.at(i);
    }
    else {
      while (i < SIZE(in) && in.at(i) != '\n')
        ++i;
      if (i < SIZE(in) && in.at(i) == '\n') ++i;
    }
  }
  return result.str();
}

long long int stringified_value_of_location(long long int address) {
  // convert to string
  ostringstream out;
  out << Memory[address];
  return new_mu_string(out.str());
}

long long int trace_contents(const string& layer) {
  if (!Trace_stream) return 0;
//?   cerr << "trace stream exists\n"; //? 1
  if (trace_count(layer) <= 0) return 0;
//?   cerr << layer << " has something\n"; //? 1
  ostringstream out;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (p->label != layer) continue;
    out << p->contents;
    if (*--p->contents.end() != '\n') out << '\n';
  }
  assert(!out.str().empty());
//?   cerr << layer << ":\n" << out.str() << "\n--\n"; //? 1
  return new_mu_string(out.str());
}

//: simpler version of run-interactive: doesn't do any running, just loads
//: recipes and reports warnings.
:(before "End Primitive Recipe Declarations")
RELOAD,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["reload"] = RELOAD;
:(before "End Primitive Recipe Implementations")
case RELOAD: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'reload' requires exactly one ingredient, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << current_recipe_name() << ": first ingredient of 'reload' should be a literal string, but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!Trace_stream) {
    Trace_file = "";  // if there wasn't already a stream we don't want to save it
    Trace_stream = new trace_stream;
    Trace_stream->collect_layers.insert("warn");
  }
  Hide_warnings = true;
  Disable_redefine_warnings = true;
  vector<recipe_ordinal> recipes_reloaded = load(read_mu_string(ingredients.at(0).at(0)));
  for (long long int i = 0; i < SIZE(recipes_reloaded); ++i) {
    Name.erase(recipes_reloaded.at(i));
  }
  transform_all();
  Trace_stream->newline();  // flush trace
  Disable_redefine_warnings = false;
  Hide_warnings = false;
  products.resize(1);
  products.at(0).push_back(trace_contents("warn"));
  // hack: assume collect_layers isn't set anywhere else
  if (Trace_stream->is_narrowly_collecting("warn")) {
    delete Trace_stream;
    Trace_stream = NULL;
  }
  break;
}

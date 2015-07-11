//: Helper for various programming environments: run arbitrary mu code and
//: return some result in string form.

:(scenario run_interactive_code)
recipe main [
  2:address:array:character <- new [1:number <- copy 34:literal]
  run-interactive 2:address:array:character
]
+mem: storing 34 in location 1

:(scenario run_interactive_empty)
recipe main [
  1:address:array:character <- run-interactive 0:literal
]
# result is null
+mem: storing 0 in location 1

//: run code in 'interactive mode', i.e. with warnings off, and recording
//: output in case we want to print it to screen
:(before "End Primitive Recipe Declarations")
RUN_INTERACTIVE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["run-interactive"] = RUN_INTERACTIVE;
//? cerr << "run-interactive: " << RUN_INTERACTIVE << '\n'; //? 1
:(before "End Primitive Recipe Implementations")
case RUN_INTERACTIVE: {
  assert(scalar(ingredients.at(0)));
  products.resize(2);
  bool new_code_pushed_to_stack = run_interactive(ingredients.at(0).at(0));
  if (!new_code_pushed_to_stack) {
    products.at(0).push_back(0);
    products.at(1).push_back(warnings_from_trace());
    break;  // done with this instruction
  }
  else {
    continue;  // not done with caller; don't increment current_step_index()
  }
}

:(before "End Globals")
bool Running_interactive = false;
:(before "End Setup")
Running_interactive = false;
:(code)
// reads a string, tries to call it as code, saving all warnings.
// returns true if successfully called (no errors found during load and transform)
bool run_interactive(long long int address) {
  if (Recipe_ordinal.find("interactive") == Recipe_ordinal.end())
    Recipe_ordinal["interactive"] = Next_recipe_ordinal++;
  string command = trim(strip_comments(to_string(address)));
  if (command.empty()) return false;
  Recipe.erase(Recipe_ordinal["interactive"]);
  Hide_warnings = true;
  if (!Trace_stream) {
    Trace_file = "";  // if there wasn't already a stream we don't want to save it
    Trace_stream = new trace_stream;
  }
  // call run(string) but without the scheduling
  load("recipe interactive [\n"+command+"\n]\n");
  transform_all();
  if (trace_count("warn") > 0) {
    Hide_warnings = false;
    return false;
  }
  Running_interactive = true;
  Current_routine->calls.push_front(call(Recipe_ordinal["interactive"]));
  return true;
}

:(after "Starting Reply")
if (current_recipe_name() == "interactive") clean_up_interactive();
:(after "Falling Through End Of Recipe")
if (current_recipe_name() == "interactive") clean_up_interactive();
:(code)
void clean_up_interactive() {
  Hide_warnings = false;
  Running_interactive = false;
}

:(scenario "run_interactive_returns_stringified_result")
recipe main [
  # try to interactively add 2 and 2
  1:address:array:character <- new [add 2:literal, 2:literal]
  2:address:array:character <- run-interactive 1:address:array:character
  10:array:character <- copy 2:address:array:character/deref
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
  10:array:character <- copy 2:address:array:character/deref
]
# output contains "ab"
+mem: storing 97 in location 11
+mem: storing 98 in location 12

:(scenario "run_interactive_returns_warnings")
recipe main [
  # run a command that generates a warning
  1:address:array:character <- new [get 1234:number, foo:offset]
  2:address:array:character, 3:address:array:character <- run-interactive 1:address:array:character
  10:array:character <- copy 3:address:array:character/deref
]
# warning should be "unknown element foo in container number"
+mem: storing 117 in location 11
+mem: storing 110 in location 12
+mem: storing 107 in location 13
+mem: storing 110 in location 14

:(before "End Globals")
string Most_recent_results;
:(before "End Setup")
Most_recent_results = "";
:(before "End of Instruction")
if (Running_interactive) {
  record_products(current_instruction(), products);
}
:(code)
void record_products(const instruction& instruction, const vector<vector<double> >& products) {
  ostringstream out;
//?   cerr << current_instruction().to_string() << '\n'; //? 1
  for (long long int i = 0; i < SIZE(products); ++i) {
    // string
    if (i < SIZE(instruction.products)) {
//?       cerr << "AA\n"; //? 1
//?       cerr << instruction.products.size() << " vs " << i << '\n'; //? 1
      if (is_string(instruction.products.at(i))) {
//?         cerr << "BB\n"; //? 1
        assert(scalar(products.at(i)));
        out << to_string(products.at(i).at(0)) << '\n';
        continue;
      }
      // End Record Product Special-cases
    }
    for (long long int j = 0; j < SIZE(products.at(i)); ++j) {
//?       cerr << "aa: " << i << ", " << j << ": " << products.at(i).at(j) << '\n'; //? 1
        out << products.at(i).at(j) << ' ';
    }
    out << '\n';
  }
//?   cerr << "aa: {\n" << out.str() << "}\n"; //? 2
  Most_recent_results = out.str();
}
:(before "Complete Call Fallthrough")
if (current_instruction().operation == RUN_INTERACTIVE && !current_instruction().products.empty()) {
  assert(SIZE(current_instruction().products) <= 2);
  // Send the results of the most recently executed instruction, regardless of
  // call depth, to be converted to string and potentially printed to string.
  vector<double> result;
  result.push_back(new_string(Most_recent_results));
  write_memory(current_instruction().products.at(0), result);
  if (SIZE(current_instruction().products) == 2) {
    vector<double> warnings;
    warnings.push_back(warnings_from_trace());
    write_memory(current_instruction().products.at(1), warnings);
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

string to_string(long long int address) {
  long long int size = Memory[address];
  if (size == 0) return "";
  ostringstream tmp;
  for (long long int curr = address+1; curr <= address+size; ++curr) {
    // todo: unicode
    tmp << (char)(int)Memory[curr];
  }
  return tmp.str();
}

long long int stringified_value_of_location(long long int address) {
  // convert to string
  ostringstream out;
//?   trace(1, "foo") << "a: " << address; //? 1
  out << Memory[address];
//?   trace(1, "foo") << "b: " << Memory[address]; //? 1
  return new_string(out.str());
}

bool is_string(const reagent& x) {
  return x.types.size() == 3
      && x.types.at(0) == Type_ordinal["address"]
      && x.types.at(1) == Type_ordinal["array"]
      && x.types.at(2) == Type_ordinal["character"];
}

long long int warnings_from_trace() {
  if (!Trace_stream) return 0;
  if (trace_count("warn") <= 0) return 0;
  ostringstream out;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (p->label != "warn") continue;
    out << p->contents;
    if (*--p->contents.end() != '\n') out << '\n';
  }
  assert(!out.str().empty());
  return new_string(out.str());
}

//: simpler version of run-interactive: doesn't do any running, just loads
//: recipes and reports warnings.
:(before "End Globals")
bool Loading_interactive = false;
:(before "End Setup")
Loading_interactive = false;
:(before "End Primitive Recipe Declarations")
RELOAD,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["reload"] = RELOAD;
:(before "End Primitive Recipe Implementations")
case RELOAD: {
  assert(scalar(ingredients.at(0)));
  Loading_interactive = true;
  Hide_warnings = true;
  load(to_string(ingredients.at(0).at(0)));
  transform_all();
  Hide_warnings = false;
  Loading_interactive = false;
  products.resize(1);
  products.at(0).push_back(warnings_from_trace());
  break;
}

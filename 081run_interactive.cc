//: Helper for various programming environments: run arbitrary mu code and
//: return some result in string form.

:(scenario run_interactive_code)
recipe main [
  2:address:array:character <- new [1:number <- copy 34:literal
]
  run-interactive 2:address:array:character  # code won't return a result
]
+mem: storing 34 in location 1

:(scenario run_interactive_empty)
recipe main [
  1:address:array:character <- run-interactive 0:literal
]
# result is null
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
RUN_INTERACTIVE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["run-interactive"] = RUN_INTERACTIVE;
//? cerr << "run-interactive: " << RUN_INTERACTIVE << '\n'; //? 1
:(before "End Primitive Recipe Implementations")
case RUN_INTERACTIVE: {
  assert(scalar(ingredients.at(0)));
  products.resize(1);
  bool new_code_pushed_to_stack = run_interactive(ingredients.at(0).at(0));
  if (!new_code_pushed_to_stack) {
    products.at(0).push_back(0);
    break;  // done with this instruction
  }
  else {
    continue;  // not done with caller; don't increment current_step_index()
  }
}

:(code)
// reads a string, tries to call it as code.
// returns true if successfully called (no errors found during load and transform)
bool run_interactive(long long int address) {
  long long int size = Memory[address];
  if (size == 0) {
    return false;
  }
  ostringstream tmp;
  for (long long int curr = address+1; curr <= address+size; ++curr) {
    // todo: unicode
    tmp << (char)(int)Memory[curr];
  }
  if (Recipe_ordinal.find("interactive") == Recipe_ordinal.end())
    Recipe_ordinal["interactive"] = Next_recipe_ordinal++;
  string command = trim(strip_comments(tmp.str()));
  if (command.empty()) return false;
  Recipe.erase(Recipe_ordinal["interactive"]);
  Hide_warnings = true;
  // call run(string) but without the scheduling
  load("recipe interactive [\n"+command+"\n]\n");
  transform_all();
  if (trace_count("warn") > 0) {
    Hide_warnings = false;
    return false;
  }
  Current_routine->calls.push_front(call(Recipe_ordinal["interactive"]));
  return true;
}

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
//?   trace(1, "foo") << "a: " << address; //? 1
  out << Memory[address];
//?   trace(1, "foo") << "b: " << Memory[address]; //? 1
  return new_string(out.str());
}

//:: debugging tool

:(before "End Primitive Recipe Declarations")
_RUN_DEPTH,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$run-depth"] = _RUN_DEPTH;
:(before "End Primitive Recipe Implementations")
case _RUN_DEPTH: {
  cerr << Current_routine->calls.size();
  break;
}

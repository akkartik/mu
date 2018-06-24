//: Helper for various programming environments: run arbitrary Mu code and
//: return some result in text form.

:(scenario run_interactive_code)
def main [
  1:num <- copy 0  # reserve space for the sandbox
  10:text <- new [1:num/raw <- copy 34]
#?   $print 10:num [|] 11:num [: ] 1000:num [|] *10:text [ (] 10:text [)] 10/newline
  run-sandboxed 10:text
  20:num <- copy 1:num
]
+mem: storing 34 in location 20

:(scenario run_interactive_empty)
def main [
  10:text <- copy null
  20:text <- run-sandboxed 10:text
]
# result is null
+mem: storing 0 in location 20
+mem: storing 0 in location 21

//: As the name suggests, 'run-sandboxed' will prevent certain operations that
//: regular Mu code can perform.
:(before "End Globals")
bool Sandbox_mode = false;
//: for starters, users can't override 'main' when the environment is running
:(before "End Load Recipe Name")
if (Sandbox_mode && result.name == "main") {
  slurp_balanced_bracket(in);
  return -1;
}

//: run code in 'interactive mode', i.e. with errors off and return:
//:   stringified output in case we want to print it to screen
//:   any errors encountered
//:   simulated screen any prints went to
//:   any 'app' layer traces generated
:(before "End Primitive Recipe Declarations")
RUN_SANDBOXED,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "run-sandboxed", RUN_SANDBOXED);
:(before "End Primitive Recipe Checks")
case RUN_SANDBOXED: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'run-sandboxed' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_text(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'run-sandboxed' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case RUN_SANDBOXED: {
  bool new_code_pushed_to_stack = run_interactive(ingredients.at(0).at(/*skip alloc id*/1));
  if (!new_code_pushed_to_stack) {
    products.resize(5);
    products.at(0).push_back(/*alloc id*/0);
    products.at(0).push_back(0);
    products.at(1).push_back(/*alloc id*/0);
    products.at(1).push_back(trace_error_contents());
    products.at(2).push_back(/*alloc id*/0);
    products.at(2).push_back(0);
    products.at(3).push_back(/*alloc id*/0);
    products.at(3).push_back(trace_app_contents());
    products.at(4).push_back(1);  // completed
    run_code_end();
    break;  // done with this instruction
  }
  else {
    continue;  // not done with caller; don't increment current_step_index()
  }
}

//: To show results in the sandbox Mu uses a hack: it saves the products
//: returned by each instruction while Track_most_recent_products is true, and
//: keeps the most recent such result around so that it can be returned as the
//: result of a sandbox.

:(before "End Globals")
bool Track_most_recent_products = false;
int Call_depth_to_track_most_recent_products_at = 0;
string Most_recent_products;
:(before "End Reset")
Track_most_recent_products = false;
Call_depth_to_track_most_recent_products_at = 0;
Most_recent_products = "";

:(before "End Globals")
trace_stream* Save_trace_stream = NULL;
string Save_trace_file;
:(code)
// reads a string, tries to call it as code (treating it as a test), saving
// all errors.
// returns true if successfully called (no errors found during load and transform)
bool run_interactive(int address) {
//?   cerr << "run_interactive: " << address << '\n';
  assert(contains_key(Recipe_ordinal, "interactive") && get(Recipe_ordinal, "interactive") != 0);
  // try to sandbox the run as best you can
  // todo: test this
  if (!Current_scenario) {
    for (int i = 1; i < Reserved_for_tests; ++i)
      Memory.erase(i);
  }
  string command = trim(strip_comments(read_mu_text(address)));
//?   cerr << "command: " << command << '\n';
  Name[get(Recipe_ordinal, "interactive")].clear();
  run_code_begin(/*should_stash_snapshots*/true);
  if (command.empty()) return false;
  // don't kill the current routine on parse errors
  routine* save_current_routine = Current_routine;
  Current_routine = NULL;
  // call run(string) but without the scheduling
  load(string("recipe! interactive [\n") +
          "local-scope\n" +
          "screen:&:screen <- next-ingredient\n" +
          "$start-tracking-products\n" +
          command + "\n" +
          "$stop-tracking-products\n" +
          "return screen\n" +
       "]\n");
  transform_all();
  Current_routine = save_current_routine;
  if (trace_count("error") > 0) return false;
  // now call 'sandbox' which will run 'interactive' in a separate routine,
  // and wait for it
  if (Save_trace_stream) {
    ++Save_trace_stream->callstack_depth;
    trace(9999, "trace") << "run-sandboxed: incrementing callstack depth to " << Save_trace_stream->callstack_depth << end();
    assert(Save_trace_stream->callstack_depth < 9000);  // 9998-101 plus cushion
  }
  Current_routine->calls.push_front(call(get(Recipe_ordinal, "sandbox")));
  return true;
}

//: Carefully update all state to exactly how it was -- including snapshots.

:(before "End Globals")
bool Run_profiler_stash = false;
map<string, recipe_ordinal> Recipe_ordinal_snapshot_stash;
map<recipe_ordinal, recipe> Recipe_snapshot_stash;
map<string, type_ordinal> Type_ordinal_snapshot_stash;
map<type_ordinal, type_info> Type_snapshot_stash;
map<recipe_ordinal, map<string, int> > Name_snapshot_stash;
map<string, vector<recipe_ordinal> > Recipe_variants_snapshot_stash;
map<string, type_tree*> Type_abbreviations_snapshot_stash;
vector<scenario> Scenarios_snapshot_stash;
set<string> Scenario_names_snapshot_stash;

:(code)
void run_code_begin(bool should_stash_snapshots) {
  // stuff to undo later, in run_code_end()
  Hide_errors = true;
  Disable_redefine_checks = true;
  Run_profiler_stash = Run_profiler;
  Run_profiler = false;
  if (should_stash_snapshots)
    stash_snapshots();
  Save_trace_stream = Trace_stream;
  Trace_stream = new trace_stream;
  Trace_stream->collect_depth = App_depth;
}

void run_code_end() {
  Hide_errors = false;
  Disable_redefine_checks = false;
  Run_profiler = Run_profiler_stash;
  Run_profiler_stash = false;
//?   ofstream fout("sandbox.log");
//?   fout << Trace_stream->readable_contents("");
//?   fout.close();
  delete Trace_stream;
  Trace_stream = Save_trace_stream;
  Save_trace_stream = NULL;
  Save_trace_file.clear();
  Recipe.erase(get(Recipe_ordinal, "interactive"));  // keep past sandboxes from inserting errors
  if (!Recipe_snapshot_stash.empty())
    unstash_snapshots();
}

// keep sync'd with save_snapshots and restore_snapshots
void stash_snapshots() {
  assert(Recipe_ordinal_snapshot_stash.empty());
  Recipe_ordinal_snapshot_stash = Recipe_ordinal_snapshot;
  assert(Recipe_snapshot_stash.empty());
  Recipe_snapshot_stash = Recipe_snapshot;
  assert(Type_ordinal_snapshot_stash.empty());
  Type_ordinal_snapshot_stash = Type_ordinal_snapshot;
  assert(Type_snapshot_stash.empty());
  Type_snapshot_stash = Type_snapshot;
  assert(Name_snapshot_stash.empty());
  Name_snapshot_stash = Name_snapshot;
  assert(Recipe_variants_snapshot_stash.empty());
  Recipe_variants_snapshot_stash = Recipe_variants_snapshot;
  assert(Type_abbreviations_snapshot_stash.empty());
  Type_abbreviations_snapshot_stash = Type_abbreviations_snapshot;
  assert(Scenarios_snapshot_stash.empty());
  Scenarios_snapshot_stash = Scenarios_snapshot;
  assert(Scenario_names_snapshot_stash.empty());
  Scenario_names_snapshot_stash = Scenario_names_snapshot;
  save_snapshots();
}
void unstash_snapshots() {
  restore_snapshots();
  Recipe_ordinal_snapshot = Recipe_ordinal_snapshot_stash;  Recipe_ordinal_snapshot_stash.clear();
  Recipe_snapshot = Recipe_snapshot_stash;  Recipe_snapshot_stash.clear();
  Type_ordinal_snapshot = Type_ordinal_snapshot_stash;  Type_ordinal_snapshot_stash.clear();
  Type_snapshot = Type_snapshot_stash;  Type_snapshot_stash.clear();
  Name_snapshot = Name_snapshot_stash;  Name_snapshot_stash.clear();
  Recipe_variants_snapshot = Recipe_variants_snapshot_stash;  Recipe_variants_snapshot_stash.clear();
  Type_abbreviations_snapshot = Type_abbreviations_snapshot_stash;  Type_abbreviations_snapshot_stash.clear();
  Scenarios_snapshot = Scenarios_snapshot_stash;  Scenarios_snapshot_stash.clear();
  Scenario_names_snapshot = Scenario_names_snapshot_stash;  Scenario_names_snapshot_stash.clear();
}

:(before "End Load Recipes")
load(string(
"recipe interactive [\n") +  // just a dummy version to initialize the Recipe_ordinal and so on
"]\n" +
"recipe sandbox [\n" +
  "local-scope\n" +
//?   "$print [aaa] 10/newline\n" +
  "screen:&:screen <- new-fake-screen 30, 5\n" +
  "routine-id:num <- start-running interactive, screen\n" +
  "limit-time routine-id, 100000/instructions\n" +
  "wait-for-routine routine-id\n" +
//?   "$print [bbb] 10/newline\n" +
  "instructions-run:num <- number-of-instructions routine-id\n" +
  "stash instructions-run [instructions run]\n" +
  "sandbox-state:num <- routine-state routine-id\n" +
  "completed?:bool <- equal sandbox-state, 1/completed\n" +
//?   "$print [completed: ] completed? 10/newline\n" +
  "output:text <- $most-recent-products\n" +
//?   "$print [zzz] 10/newline\n" +
//?   "$print output\n" +
  "errors:text <- save-errors\n" +
  "stashes:text <- save-app-trace\n" +
  "$cleanup-run-sandboxed\n" +
  "return output, errors, screen, stashes, completed?\n" +
"]\n");

//: adjust errors in the sandbox
:(before "End maybe(recipe_name) Special-cases")
if (recipe_name == "interactive") return "";

:(scenario run_interactive_comments)
def main [
  1:text <- new [# ab
add 2, 2]
  2:text <- run-sandboxed 1:text
  3:@:char <- copy *2:text
]
+mem: storing 52 in location 4

:(before "End Primitive Recipe Declarations")
_START_TRACKING_PRODUCTS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$start-tracking-products", _START_TRACKING_PRODUCTS);
:(before "End Primitive Recipe Checks")
case _START_TRACKING_PRODUCTS: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _START_TRACKING_PRODUCTS: {
  Track_most_recent_products = true;
  Call_depth_to_track_most_recent_products_at = SIZE(Current_routine->calls);
  break;
}

:(before "End Primitive Recipe Declarations")
_STOP_TRACKING_PRODUCTS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$stop-tracking-products", _STOP_TRACKING_PRODUCTS);
:(before "End Primitive Recipe Checks")
case _STOP_TRACKING_PRODUCTS: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _STOP_TRACKING_PRODUCTS: {
  Track_most_recent_products = false;
  break;
}

:(before "End Primitive Recipe Declarations")
_MOST_RECENT_PRODUCTS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$most-recent-products", _MOST_RECENT_PRODUCTS);
:(before "End Primitive Recipe Checks")
case _MOST_RECENT_PRODUCTS: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _MOST_RECENT_PRODUCTS: {
  products.resize(1);
  products.at(0).push_back(/*alloc id*/0);
  products.at(0).push_back(new_mu_text(Most_recent_products));
  break;
}

:(before "End Primitive Recipe Declarations")
SAVE_ERRORS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "save-errors", SAVE_ERRORS);
:(before "End Primitive Recipe Checks")
case SAVE_ERRORS: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SAVE_ERRORS: {
  products.resize(1);
  products.at(0).push_back(/*alloc id*/0);
  products.at(0).push_back(trace_error_contents());
  break;
}

:(before "End Primitive Recipe Declarations")
SAVE_APP_TRACE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "save-app-trace", SAVE_APP_TRACE);
:(before "End Primitive Recipe Checks")
case SAVE_APP_TRACE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case SAVE_APP_TRACE: {
  products.resize(1);
  products.at(0).push_back(/*alloc id*/0);
  products.at(0).push_back(trace_app_contents());
  break;
}

:(before "End Primitive Recipe Declarations")
_CLEANUP_RUN_SANDBOXED,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$cleanup-run-sandboxed", _CLEANUP_RUN_SANDBOXED);
:(before "End Primitive Recipe Checks")
case _CLEANUP_RUN_SANDBOXED: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _CLEANUP_RUN_SANDBOXED: {
  run_code_end();
  break;
}

:(scenario "run_interactive_converts_result_to_text")
def main [
  # try to interactively add 2 and 2
  10:text <- new [add 2, 2]
  20:text <- run-sandboxed 10:text
  30:@:char <- copy *20:text
]
# first letter in the output should be '4' in unicode
+mem: storing 52 in location 31

:(scenario "run_interactive_ignores_products_in_nested_functions")
def main [
  10:text <- new [foo]
  20:text <- run-sandboxed 10:text
  30:@:char <- copy *20:text
]
def foo [
  40:num <- copy 1234
  {
    break
    reply 5678
  }
]
# no product should have been tracked
+mem: storing 0 in location 30

:(scenario "run_interactive_ignores_products_in_previous_instructions")
def main [
  10:text <- new [
    add 1, 1  # generates a product
    foo]  # no products
  20:text <- run-sandboxed 10:text
  30:@:char <- copy *20:text
]
def foo [
  40:num <- copy 1234
  {
    break
    reply 5678
  }
]
# no product should have been tracked
+mem: storing 0 in location 30

:(scenario "run_interactive_remembers_products_before_final_label")
def main [
  10:text <- new [
    add 1, 1  # generates a product
    +foo]  # no products
  20:text <- run-sandboxed 10:text
  30:@:char <- copy *20:text
]
def foo [
  40:num <- copy 1234
  {
    break
    reply 5678
  }
]
# product tracked
+mem: storing 50 in location 31

:(scenario "run_interactive_returns_text")
def main [
  # try to interactively add 2 and 2
  1:text <- new [
    x:text <- new [a]
    y:text <- new [b]
    z:text <- append x:text, y:text
  ]
  10:text <- run-sandboxed 1:text
#?   $print 10:text 10/newline
  20:@:char <- copy *10:text
]
# output contains "ab"
+mem: storing 97 in location 21
+mem: storing 98 in location 22

:(scenario "run_interactive_returns_errors")
def main [
  # run a command that generates an error
  10:text <- new [x:num <- copy 34
get x:num, foo:offset]
  20:text, 30:text <- run-sandboxed 10:text
  40:@:char <- copy *30:text
]
# error should be "unknown element foo in container number"
+mem: storing 117 in location 41
+mem: storing 110 in location 42
+mem: storing 107 in location 43
+mem: storing 110 in location 44
# ...

:(scenario run_interactive_with_comment)
def main [
  # 2 instructions, with a comment after the first
  10:text <- new [a:num <- copy 0  # abc
b:num <- copy 0
]
  20:text, 30:text <- run-sandboxed 10:text
]
# no errors
# skip alloc id
+mem: storing 0 in location 30
+mem: storing 0 in location 31

:(after "Running One Instruction")
if (Track_most_recent_products && SIZE(Current_routine->calls) == Call_depth_to_track_most_recent_products_at
    && !current_instruction().is_label
    && current_instruction().name != "$stop-tracking-products") {
  Most_recent_products = "";
}
:(before "End Running One Instruction")
if (Track_most_recent_products && SIZE(Current_routine->calls) == Call_depth_to_track_most_recent_products_at) {
  Most_recent_products = track_most_recent_products(current_instruction(), products);
//?   cerr << "most recent products: " << Most_recent_products << '\n';
}
:(code)
string track_most_recent_products(const instruction& instruction, const vector<vector<double> >& products) {
  ostringstream out;
  for (int i = 0; i < SIZE(products); ++i) {
    // A sandbox can print a string result, but only if it is actually saved
    // to a variable in the sandbox, because otherwise the results are
    // reclaimed before the sandbox sees them. So you get these interactions
    // in the sandbox:
    //
    //    new [abc]
    //    => <address>
    //
    //    x:text <- new [abc]
    //    => abc
    if (i < SIZE(instruction.products)) {
      if (is_mu_text(instruction.products.at(i))) {
        if (SIZE(products.at(i)) != 2) continue;  // weak silent check for address
        out << read_mu_text(products.at(i).at(/*skip alloc id*/1)) << '\n';
        continue;
      }
    }
    for (int j = 0; j < SIZE(products.at(i)); ++j)
      out << no_scientific(products.at(i).at(j)) << ' ';
    out << '\n';
  }
  return out.str();
}

:(code)
string strip_comments(string in) {
  ostringstream result;
  for (int i = 0; i < SIZE(in); ++i) {
    if (in.at(i) != '#') {
      result << in.at(i);
    }
    else {
      while (i+1 < SIZE(in) && in.at(i+1) != '\n')
        ++i;
    }
  }
  return result.str();
}

int stringified_value_of_location(int address) {
  // convert to string
  ostringstream out;
  out << no_scientific(get_or_insert(Memory, address));
  return new_mu_text(out.str());
}

int trace_error_contents() {
  if (!Trace_stream) return 0;
  ostringstream out;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (p->label != "error") continue;
    out << p->contents;
    if (*--p->contents.end() != '\n') out << '\n';
  }
  string result = out.str();
  truncate(result);
  if (result.empty()) return 0;
  return new_mu_text(result);
}

int trace_app_contents() {
  if (!Trace_stream) return 0;
  ostringstream out;
  for (vector<trace_line>::iterator p = Trace_stream->past_lines.begin(); p != Trace_stream->past_lines.end(); ++p) {
    if (p->depth != App_depth) continue;
    out << p->contents;
    if (*--p->contents.end() != '\n') out << '\n';
  }
  string result = out.str();
  if (result.empty()) return 0;
  truncate(result);
  return new_mu_text(result);
}

void truncate(string& x) {
  if (SIZE(x) > 1024) {
    x.erase(1024);
    *x.rbegin() = '\n';
    *++x.rbegin() = '.';
    *++++x.rbegin() = '.';
  }
}

//: simpler version of run-sandboxed: doesn't do any running, just loads
//: recipes and reports errors.

:(before "End Primitive Recipe Declarations")
RELOAD,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "reload", RELOAD);
:(before "End Primitive Recipe Checks")
case RELOAD: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'reload' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_text(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'reload' should be a string, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case RELOAD: {
  restore_non_recipe_snapshots();
  string code = read_mu_text(ingredients.at(0).at(/*skip alloc id*/1));
  run_code_begin(/*should_stash_snapshots*/false);
  routine* save_current_routine = Current_routine;
  Current_routine = NULL;
  Sandbox_mode = true;
  vector<recipe_ordinal> recipes_reloaded = load(code);
  transform_all();
  Trace_stream->newline();  // flush trace
  Sandbox_mode = false;
  Current_routine = save_current_routine;
  products.resize(1);
  products.at(0).push_back(/*alloc id*/0);
  products.at(0).push_back(trace_error_contents());
  run_code_end();  // wait until we're done with the trace contents
  break;
}

:(scenario reload_loads_function_definitions)
def main [
  local-scope
  x:text <- new [recipe foo [
    1:num/raw <- copy 34
  ]]
  reload x
  run-sandboxed [foo]
  2:num/raw <- copy 1:num/raw
]
+mem: storing 34 in location 2

:(scenario reload_continues_past_error)
def main [
  local-scope
  x:text <- new [recipe foo [
    get 1234:num, foo:offset
  ]]
  reload x
  1:num/raw <- copy 34
]
+mem: storing 34 in location 1

:(scenario reload_can_repeatedly_load_container_definitions)
# define a container and try to create it (merge requires knowing container size)
def main [
  local-scope
  x:text <- new [
    container foo [
      x:num
      y:num
    ]
    recipe bar [
      local-scope
      x:foo <- merge 34, 35
    ]
  ]
  # save warning addresses in locations of type 'number' to avoid spurious changes to them due to 'abandon'
  10:text/raw <- reload x
  20:text/raw <- reload x
]
# no errors on either load
+mem: storing 0 in location 10
+mem: storing 0 in location 11
+mem: storing 0 in location 20
+mem: storing 0 in location 21

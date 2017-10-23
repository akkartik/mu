//: Phase 3: Start running a loaded and transformed recipe.
//:
//:   The process of running Mu code:
//:     load -> transform -> run
//:
//: So far we've seen recipes as lists of instructions, and instructions point
//: at other recipes. To kick things off Mu needs to know how to run certain
//: 'primitive' recipes. That will then give the ability to run recipes
//: containing these primitives.
//:
//: This layer defines a skeleton with just two primitive recipes: IDLE which
//: does nothing, and COPY, which can copy numbers from one memory location to
//: another. Later layers will add more primitives.

:(scenario copy_literal)
def main [
  1:num <- copy 23
]
+run: {1: "number"} <- copy {23: "literal"}
+mem: storing 23 in location 1

:(scenario copy)
def main [
  1:num <- copy 23
  2:num <- copy 1:num
]
+run: {2: "number"} <- copy {1: "number"}
+mem: location 1 is 23
+mem: storing 23 in location 2

:(scenario copy_multiple)
def main [
  1:num, 2:num <- copy 23, 24
]
+mem: storing 23 in location 1
+mem: storing 24 in location 2

:(before "End Types")
// Book-keeping while running a recipe.
//: Later layers will replace this to support running multiple routines at once.
struct routine {
  recipe_ordinal running_recipe;
  int running_step_index;
  routine(recipe_ordinal r) :running_recipe(r), running_step_index(0) {}
  bool completed() const;
  const vector<instruction>& steps() const;
};

:(before "End Globals")
routine* Current_routine = NULL;
:(before "End Reset")
Current_routine = NULL;

:(code)
void run(const recipe_ordinal r) {
  routine rr(r);
  Current_routine = &rr;
  run_current_routine();
  Current_routine = NULL;
}

void run_current_routine() {
  while (should_continue_running(Current_routine)) {  // beware: may modify Current_routine
    // Running One Instruction
    if (current_instruction().is_label) { ++current_step_index();  continue; }
    trace(Initial_callstack_depth + Trace_stream->callstack_depth, "run") << to_string(current_instruction()) << end();
    if (get_or_insert(Memory, 0) != 0) {
      raise << "something wrote to location 0; this should never happen\n" << end();
      put(Memory, 0, 0);
    }
    // read all ingredients from memory, each potentially spanning multiple locations
    vector<vector<double> > ingredients;
    if (should_copy_ingredients()) {
      for (int i = 0;  i < SIZE(current_instruction().ingredients);  ++i)
        ingredients.push_back(read_memory(current_instruction().ingredients.at(i)));
    }
    // instructions below will write to 'products'
    vector<vector<double> > products;
    //: This will be a large switch that later layers will often insert cases
    //: into. Never call 'continue' within it. Instead, we'll explicitly
    //: control which of the following stages after the switch we run for each
    //: instruction.
    bool write_products = true;
    bool fall_through_to_next_instruction = true;
    switch (current_instruction().operation) {
      // Primitive Recipe Implementations
      case COPY: {
        copy(ingredients.begin(), ingredients.end(), inserter(products, products.begin()));
        break;
      }
      // End Primitive Recipe Implementations
      default: {
        cout << "not a primitive op: " << current_instruction().operation << '\n';
      }
    }
    //: used by a later layer
    if (write_products) {
      if (SIZE(products) < SIZE(current_instruction().products)) {
        raise << SIZE(products) << " vs " << SIZE(current_instruction().products) << ": failed to write to all products in '" << to_original_string(current_instruction()) << "'\n" << end();
      }
      else {
        for (int i = 0;  i < SIZE(current_instruction().products);  ++i) {
          // Writing Instruction Product(i)
          write_memory(current_instruction().products.at(i), products.at(i));
        }
      }
    }
    // End Running One Instruction
    if (fall_through_to_next_instruction)
      ++current_step_index();
  }
  stop_running_current_routine:;
}

:(code)
//: hook replaced in a later layer
bool should_continue_running(const routine* current_routine) {
  assert(current_routine == Current_routine);  // argument passed in just to make caller readable above
  return !Current_routine->completed();
}

bool should_copy_ingredients() {
  // End should_copy_ingredients Special-cases
  return true;
}

//: Some helpers.
//: Important that they return references into the current routine.

//: hook replaced in a later layer
int& current_step_index() {
  return Current_routine->running_step_index;
}

//: hook replaced in a later layer
recipe_ordinal currently_running_recipe() {
  return Current_routine->running_recipe;
}

//: hook replaced in a later layer
const string& current_recipe_name() {
  return get(Recipe, Current_routine->running_recipe).name;
}

//: hook replaced in a later layer
const recipe& current_recipe() {
  return get(Recipe, Current_routine->running_recipe);
}

//: hook replaced in a later layer
const instruction& current_instruction() {
  return get(Recipe, Current_routine->running_recipe).steps.at(Current_routine->running_step_index);
}

//: hook replaced in a later layer
bool routine::completed() const {
  return running_step_index >= SIZE(get(Recipe, running_recipe).steps);
}

//: hook replaced in a later layer
const vector<instruction>& routine::steps() const {
  return get(Recipe, running_recipe).steps;
}

//:: Startup flow

//: Step 1: load all .mu files with numeric prefixes (in order)
:(before "End Load Recipes")
// Load Mu Prelude
//? Save_trace = true;
//? START_TRACING_UNTIL_END_OF_SCOPE;
load_file_or_directory("core.mu");
//? DUMP("");
//? exit(0);

//: Step 2: load any .mu files provided at the commandline
:(before "End Commandline Parsing")
// Check For .mu Files
//? START_TRACING_UNTIL_END_OF_SCOPE
//? Dump_trace = true;
if (argc > 1) {
  // skip argv[0]
  ++argv;
  --argc;
  while (argc > 0) {
    // ignore argv past '--'; that's commandline args for 'main'
    if (string(*argv) == "--") break;
    if (starts_with(*argv, "--"))
      cerr << "treating " << *argv << " as a file rather than an option\n";
    load_file_or_directory(*argv);
    --argc;
    ++argv;
  }
  if (Run_tests) Recipe.erase(get(Recipe_ordinal, "main"));
}
transform_all();
//? cerr << to_original_string(get(Type_ordinal, "editor")) << '\n';
//? cerr << to_original_string(get(Recipe, get(Recipe_ordinal, "event-loop"))) << '\n';
//? DUMP("");
//? exit(0);
if (trace_contains_errors()) return 1;
save_snapshots();

//: Step 3: if we aren't running tests, locate a recipe called 'main' and
//: start running it.
:(before "End Main")
if (!Run_tests && contains_key(Recipe_ordinal, "main") && contains_key(Recipe, get(Recipe_ordinal, "main"))) {
  // Running Main
  reset();
  if (Start_tracing) {
    Trace_stream = new trace_stream;
    Save_trace = true;
  }
  trace(2, "run") << "=== Starting to run" << end();
  assert(Num_calls_to_transform_all == 1);
  run_main(argc, argv);
}
:(code)
void run_main(int argc, char* argv[]) {
  recipe_ordinal r = get(Recipe_ordinal, "main");
  if (r) run(r);
}

//: By default we don't maintain the trace while running main because its
//: overheads can grow rapidly. However, it's useful when debugging.
:(before "End Globals")
bool Start_tracing = false;
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--trace")) {
  Start_tracing = true;
}

:(code)
void cleanup_main() {
  if (Save_trace && Trace_stream) {
    cerr << "writing trace to 'last_run'\n";
    ofstream fout("last_run");
    fout << Trace_stream->readable_contents("");
    fout.close();
  }
  if (Trace_stream) delete Trace_stream, Trace_stream = NULL;
}
:(before "End One-time Setup")
atexit(cleanup_main);

:(code)
void load_file_or_directory(string filename) {
  if (is_directory(filename)) {
    load_all(filename);
    return;
  }
  ifstream fin(filename.c_str());
  if (!fin) {
    cerr << "no such file '" << filename << "'\n" << end();  // don't raise, just warn. just in case it's just a name for a scenario to run.
    return;
  }
  trace(9990, "load") << "=== " << filename << end();
  load(fin);
  fin.close();
}

bool is_directory(string path) {
  struct stat info;
  if (stat(path.c_str(), &info)) return false;  // error
  return info.st_mode & S_IFDIR;
}

void load_all(string dir) {
  dirent** files;
  int num_files = scandir(dir.c_str(), &files, NULL, alphasort);
  for (int i = 0;  i < num_files;  ++i) {
    string curr_file = files[i]->d_name;
    if (isdigit(curr_file.at(0)))
      load_file_or_directory(dir+'/'+curr_file);
    free(files[i]);
    files[i] = NULL;
  }
  free(files);
}
:(before "End Includes")
#include <dirent.h>
#include <sys/stat.h>

//:: Reading from memory, writing to memory.

:(code)
vector<double> read_memory(reagent/*copy*/ x) {
  // Begin Preprocess read_memory(x)
  vector<double> result;
  if (is_literal(x)) {
    result.push_back(x.value);
    return result;
  }
  // End Preprocess read_memory(x)
  int size = size_of(x);
  for (int offset = 0;  offset < size;  ++offset) {
    double val = get_or_insert(Memory, x.value+offset);
    trace(9999, "mem") << "location " << x.value+offset << " is " << no_scientific(val) << end();
    result.push_back(val);
  }
  return result;
}

void write_memory(reagent/*copy*/ x, const vector<double>& data) {
  assert(Current_routine);  // run-time only
  // Begin Preprocess write_memory(x, data)
  if (!x.type) {
    raise << "can't write to '" << to_string(x) << "'; no type\n" << end();
    return;
  }
  if (is_dummy(x)) return;
  if (is_literal(x)) return;
  // End Preprocess write_memory(x, data)
  if (x.value == 0) {
    raise << "can't write to location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    return;
  }
  if (size_mismatch(x, data)) {
    raise << maybe(current_recipe_name()) << "size mismatch in storing to '" << x.original_string << "' (" << size_of(x) << " vs " << SIZE(data) << ") at '" << to_original_string(current_instruction()) << "'\n" << end();
    return;
  }
  // End write_memory(x) Special-cases
  for (int offset = 0;  offset < SIZE(data);  ++offset) {
    assert(x.value+offset > 0);
    trace(9999, "mem") << "storing " << no_scientific(data.at(offset)) << " in location " << x.value+offset << end();
    put(Memory, x.value+offset, data.at(offset));
  }
}

:(code)
int size_of(const reagent& r) {
  if (!r.type) return 0;
  // End size_of(reagent r) Special-cases
  return size_of(r.type);
}
int size_of(const type_tree* type) {
  if (!type) return 0;
  if (type->atom) {
    if (type->value == -1) return 1;  // error value, but we'll raise it elsewhere
    if (type->value == 0) return 1;
    // End size_of(type) Atom Special-cases
  }
  else {
    if (!type->left->atom) {
      raise << "invalid type " << to_string(type) << '\n' << end();
      return 0;
    }
    if (type->left->value == get(Type_ordinal, "address")) return 1;
    // End size_of(type) Non-atom Special-cases
  }
  // End size_of(type) Special-cases
  return 1;
}

bool size_mismatch(const reagent& x, const vector<double>& data) {
  if (!x.type) return true;
  // End size_mismatch(x) Special-cases
//?   if (size_of(x) != SIZE(data)) cerr << size_of(x) << " vs " << SIZE(data) << '\n';
  return size_of(x) != SIZE(data);
}

bool is_literal(const reagent& r) {
  return is_literal(r.type);
}
bool is_literal(const type_tree* type) {
  if (!type) return false;
  if (!type->atom) return false;
  return type->value == 0;
}

bool scalar(const vector<int>& x) {
  return SIZE(x) == 1;
}
bool scalar(const vector<double>& x) {
  return SIZE(x) == 1;
}

// helper for tests
void run(const string& form) {
  vector<recipe_ordinal> tmp = load(form);
  transform_all();
  if (tmp.empty()) return;
  if (trace_contains_errors()) return;
  // if a test defines main, it probably wants to start there regardless of
  // definition order
  if (contains_key(Recipe, get(Recipe_ordinal, "main")))
    run(get(Recipe_ordinal, "main"));
  else
    run(tmp.front());
}

:(scenario run_label)
def main [
  +foo
  1:num <- copy 23
  2:num <- copy 1:num
]
+run: {1: "number"} <- copy {23: "literal"}
+run: {2: "number"} <- copy {1: "number"}
-run: +foo

:(scenario run_dummy)
def main [
  _ <- copy 0
]
+run: _ <- copy {0: "literal"}

:(scenario write_to_0_disallowed)
% Hide_errors = true;
def main [
  0:num <- copy 34
]
-mem: storing 34 in location 0

//: Mu is robust to various combinations of commas and spaces. You just have
//: to put spaces around the '<-'.

:(scenario comma_without_space)
def main [
  1:num, 2:num <- copy 2,2
]
+mem: storing 2 in location 1

:(scenario space_without_comma)
def main [
  1:num, 2:num <- copy 2 2
]
+mem: storing 2 in location 1

:(scenario comma_before_space)
def main [
  1:num, 2:num <- copy 2, 2
]
+mem: storing 2 in location 1

:(scenario comma_after_space)
def main [
  1:num, 2:num <- copy 2 ,2
]
+mem: storing 2 in location 1

//:: Counters for trying to understand where Mu programs are spending their
//:: time.

:(before "End Globals")
bool Run_profiler = false;
// We'll key profile information by recipe_ordinal rather than name because
// it's more efficient, and because later layers will show more than just the
// name of a recipe.
//
// One drawback: if you're clearing recipes your profile will be inaccurate.
// So far that happens in tests, and in 'run-sandboxed' in a later layer.
map<recipe_ordinal, int> Instructions_running;
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--profile")) {
  Run_profiler = true;
}
:(after "Running One Instruction")
if (Run_profiler) Instructions_running[currently_running_recipe()]++;
:(before "End One-time Setup")
atexit(dump_profile);
:(code)
void dump_profile() {
  if (!Run_profiler) return;
  if (Run_tests) {
    cerr << "It's not a good idea to profile a run with tests, since tests can create conflicting recipes and mislead you. To try it anyway, comment out this check in the code.\n";
    return;
  }
  ofstream fout;
  fout.open("profile.instructions");
  if (fout) {
    for (map<recipe_ordinal, int>::iterator p = Instructions_running.begin();  p != Instructions_running.end();  ++p) {
      fout << std::setw(9) << p->second << ' ' << header_label(p->first) << '\n';
    }
  }
  fout.close();
  // End dump_profile
}

// overridden in a later layer
string header_label(const recipe_ordinal r) {
  return get(Recipe, r).name;
}

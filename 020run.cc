//: Phase 3: Start running a loaded and transformed recipe.
//:
//: So far we've seen recipes as lists of instructions, and instructions point
//: at other recipes. To kick things off mu needs to know how to run certain
//: 'primitive' recipes. That will then give the ability to run recipes
//: containing these primitives.
//:
//: This layer defines a skeleton with just two primitive recipes: IDLE which
//: does nothing, and COPY, which can copy numbers from one memory location to
//: another. Later layers will add more primitives.

:(scenario copy_literal)
def main [
  1:number <- copy 23
]
+run: 1:number <- copy 23
+mem: storing 23 in location 1

:(scenario copy)
def main [
  1:number <- copy 23
  2:number <- copy 1:number
]
+run: 2:number <- copy 1:number
+mem: location 1 is 23
+mem: storing 23 in location 2

:(scenario copy_multiple)
def main [
  1:number, 2:number <- copy 23, 24
]
+mem: storing 23 in location 1
+mem: storing 24 in location 2

:(before "End Types")
// Book-keeping while running a recipe.
//: Later layers will change this.
struct routine {
  recipe_ordinal running_recipe;
  long long int running_step_index;
  routine(recipe_ordinal r) :running_recipe(r), running_step_index(0) {}
  bool completed() const;
};

:(before "End Globals")
routine* Current_routine = NULL;
map<string, long long int> Instructions_running;
map<string, long long int> Locations_read;
map<string, long long int> Locations_read_by_instruction;

:(code)
void run(recipe_ordinal r) {
  routine rr(r);
  Current_routine = &rr;
  run_current_routine();
}

void run_current_routine()
{  // curly on a separate line, because later layers will modify header
  while (!Current_routine->completed())  // later layers will modify condition
  {
    // Running One Instruction
    if (current_instruction().is_label) { ++current_step_index(); continue; }
    trace(Initial_callstack_depth + Trace_stream->callstack_depth, "run") << to_string(current_instruction()) << end();
    if (get_or_insert(Memory, 0) != 0) {
      raise << "something wrote to location 0; this should never happen\n" << end();
      put(Memory, 0, 0);
    }
    // read all ingredients from memory, each potentially spanning multiple locations
    vector<vector<double> > ingredients;
    if (should_copy_ingredients()) {
      for (long long int i = 0; i < SIZE(current_instruction().ingredients); ++i)
        ingredients.push_back(read_memory(current_instruction().ingredients.at(i)));
    }
    // instructions below will write to 'products'
    vector<vector<double> > products;
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
    if (SIZE(products) < SIZE(current_instruction().products)) {
      raise << SIZE(products) << " vs " << SIZE(current_instruction().products) << ": failed to write to all products! " << to_string(current_instruction()) << '\n' << end();
    }
    else {
      for (long long int i = 0; i < SIZE(current_instruction().products); ++i) {
        write_memory(current_instruction().products.at(i), products.at(i));
      }
    }
    // End of Instruction
    ++current_step_index();
  }
  stop_running_current_routine:;
}

bool should_copy_ingredients() {
  // End should_copy_ingredients Special-cases
  return true;
}

//: Some helpers.
//: We'll need to override these later as we change the definition of routine.
//: Important that they return referrences into the routine.

inline long long int& current_step_index() {
  return Current_routine->running_step_index;
}

inline const string& current_recipe_name() {
  return get(Recipe, Current_routine->running_recipe).name;
}

inline const instruction& current_instruction() {
  return get(Recipe, Current_routine->running_recipe).steps.at(Current_routine->running_step_index);
}

inline bool routine::completed() const {
  return running_step_index >= SIZE(get(Recipe, running_recipe).steps);
}

//:: Startup flow

//: Step 1: load all .mu files with numeric prefixes (in order)
:(before "End Load Recipes")
// Load .mu Core
//? Trace_file = "interactive";
//? START_TRACING_UNTIL_END_OF_SCOPE;
load_permanently("core.mu");
transform_all();
//? DUMP("");
//? exit(0);

//: Step 2: load any .mu files provided at the commandline
:(before "End Commandline Parsing")
// Check For .mu Files
if (argc > 1) {
  // skip argv[0]
  argv++;
  argc--;
  // ignore argv past '--'; that's commandline args for 'main'
  while (argc > 0) {
    if (string(*argv) == "--") break;
    load_permanently(*argv);
    argv++;
    argc--;
  }
  transform_all();
  if (Run_tests) Recipe.erase(get(Recipe_ordinal, "main"));
  // End Loading .mu Files
}

//: Step 3: if we aren't running tests, locate a recipe called 'main' and
//: start running it.
:(before "End Main")
if (!Run_tests && contains_key(Recipe_ordinal, "main") && contains_key(Recipe, get(Recipe_ordinal, "main"))) {
  // Running Main
  setup();
//?   Trace_file = "interactive";
//?   START_TRACING_UNTIL_END_OF_SCOPE;
  trace(9990, "run") << "=== Starting to run" << end();
  run_main(argc, argv);
  teardown();
}

:(code)
void run_main(int argc, char* argv[]) {
  recipe_ordinal r = get(Recipe_ordinal, "main");
  if (r) run(r);
}

:(code)
void dump_profile() {
  for (map<string, long long int>::iterator p = Instructions_running.begin(); p != Instructions_running.end(); ++p) {
    cerr << p->first << ": " << p->second << '\n';
  }
  cerr << "== locations read\n";
  for (map<string, long long int>::iterator p = Locations_read.begin(); p != Locations_read.end(); ++p) {
    cerr << p->first << ": " << p->second << '\n';
  }
  cerr << "== locations read by instruction\n";
  for (map<string, long long int>::iterator p = Locations_read_by_instruction.begin(); p != Locations_read_by_instruction.end(); ++p) {
    cerr << p->first << ": " << p->second << '\n';
  }
}
:(before "End One-time Setup")
//? atexit(dump_profile);

:(code)
void cleanup_main() {
  if (!Trace_file.empty() && Trace_stream) {
    ofstream fout((Trace_dir+Trace_file).c_str());
    fout << Trace_stream->readable_contents("");
    fout.close();
  }
}
:(before "End One-time Setup")
atexit(cleanup_main);

:(code)
void load_permanently(string filename) {
  if (is_directory(filename)) {
    load_all_permanently(filename);
    return;
  }
  ifstream fin(filename.c_str());
  if (!fin) {
    raise << "no such file " << filename << '\n' << end();
    return;
  }
  trace(9990, "load") << "=== " << filename << end();
  load(fin);
  fin.close();
  // freeze everything so it doesn't get cleared by tests
  Recently_added_recipes.clear();
  // End load_permanently.
}

bool is_directory(string path) {
  struct stat info;
  if (stat(path.c_str(), &info)) return false;  // error
  return info.st_mode & S_IFDIR;
}

void load_all_permanently(string dir) {
  dirent** files;
  int num_files = scandir(dir.c_str(), &files, NULL, alphasort);
  for (int i = 0; i < num_files; ++i) {
    string curr_file = files[i]->d_name;
    if (isdigit(curr_file.at(0)))
      load_permanently(dir+'/'+curr_file);
    free(files[i]);
    files[i] = NULL;
  }
  free(files);
}
:(before "End Includes")
#include<dirent.h>
#include<sys/stat.h>

//:: Reading from memory, writing to memory.

:(code)
vector<double> read_memory(reagent x) {
  vector<double> result;
  if (is_literal(x)) {
    result.push_back(x.value);
    return result;
  }
  // End Preprocess read_memory(x)
  long long int size = size_of(x);
  for (long long int offset = 0; offset < size; ++offset) {
    double val = get_or_insert(Memory, x.value+offset);
    trace(9999, "mem") << "location " << x.value+offset << " is " << no_scientific(val) << end();
    result.push_back(val);
  }
  return result;
}

void write_memory(reagent x, const vector<double>& data) {
  if (!x.type) {
    raise << "can't write to " << to_string(x) << "; no type\n" << end();
    return;
  }
  if (is_dummy(x)) return;
  if (is_literal(x)) return;
  // End Preprocess write_memory(x)
  if (x.value == 0) return;
  if (size_mismatch(x, data)) {
    raise << maybe(current_recipe_name()) << "size mismatch in storing to " << x.original_string << " (" << size_of(x.type) << " vs " << SIZE(data) << ") at '" << to_string(current_instruction()) << "'\n" << end();
    return;
  }
  // End write_memory(reagent x) Special-cases
  for (long long int offset = 0; offset < SIZE(data); ++offset) {
    assert(x.value+offset > 0);
    trace(9999, "mem") << "storing " << no_scientific(data.at(offset)) << " in location " << x.value+offset << end();
    put(Memory, x.value+offset, data.at(offset));
  }
}

:(code)
long long int size_of(const reagent& r) {
  if (r.type == NULL) return 0;
  // End size_of(reagent) Cases
  return size_of(r.type);
}
long long int size_of(const type_tree* type) {
  if (type == NULL) return 0;
  // End size_of(type) Cases
  return 1;
}

bool size_mismatch(const reagent& x, const vector<double>& data) {
  if (x.type == NULL) return true;
  // End size_mismatch(x) Cases
//?   if (size_of(x) != SIZE(data)) cerr << size_of(x) << " vs " << SIZE(data) << '\n';
  return size_of(x) != SIZE(data);
}

inline bool is_dummy(const reagent& x) {
  return x.name == "_";
}

inline bool is_literal(const reagent& r) {
  if (!r.type) return false;
  if (r.type->value == 0)
    assert(!r.type->left && !r.type->right);
  return r.type->value == 0;
}

inline bool scalar(const vector<long long int>& x) {
  return SIZE(x) == 1;
}
inline bool scalar(const vector<double>& x) {
  return SIZE(x) == 1;
}

// helper for tests
void run(string form) {
  vector<recipe_ordinal> tmp = load(form);
  transform_all();
  if (tmp.empty()) return;
  if (trace_count("error") > 0) return;
  run(tmp.front());
}

:(scenario run_label)
def main [
  +foo
  1:number <- copy 23
  2:number <- copy 1:number
]
+run: 1:number <- copy 23
+run: 2:number <- copy 1:number
-run: +foo

:(scenario run_dummy)
def main [
  _ <- copy 0
]
+run: _ <- copy 0

:(scenario write_to_0_disallowed)
% Hide_errors = true;
def main [
  0:number <- copy 34
]
-mem: storing 34 in location 0

//: mu is robust to various combinations of commas and spaces. You just have
//: to put spaces around the '<-'.

:(scenario comma_without_space)
def main [
  1:number, 2:number <- copy 2,2
]
+mem: storing 2 in location 1

:(scenario space_without_comma)
def main [
  1:number, 2:number <- copy 2 2
]
+mem: storing 2 in location 1

:(scenario comma_before_space)
def main [
  1:number, 2:number <- copy 2, 2
]
+mem: storing 2 in location 1

:(scenario comma_after_space)
def main [
  1:number, 2:number <- copy 2 ,2
]
+mem: storing 2 in location 1

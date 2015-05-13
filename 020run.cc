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
recipe main [
  1:integer <- copy 23:literal
]
+run: instruction main/0
+run: ingredient 0 is 23
+mem: storing 23 in location 1

:(scenario copy)
recipe main [
  1:integer <- copy 23:literal
  2:integer <- copy 1:integer
]
+run: instruction main/1
+run: ingredient 0 is 1
+mem: location 1 is 23
+mem: storing 23 in location 2

:(scenario copy_multiple)
recipe main [
  1:integer, 2:integer <- copy 23:literal, 24:literal
]
+run: ingredient 0 is 23
+run: ingredient 1 is 24
+mem: storing 23 in location 1
+mem: storing 24 in location 2

:(before "End Types")
// Book-keeping while running a recipe.
//: Later layers will change this.
struct routine {
  recipe_number running_recipe;
  index_t running_step_index;
  routine(recipe_number r) :running_recipe(r), running_step_index(0) {}
  bool completed() const;
};

:(before "End Globals")
routine* Current_routine = NULL;

:(code)
void run(recipe_number r) {
  routine rr(r);
  Current_routine = &rr;
  run_current_routine();
}

void run_current_routine()
{  // curly on a separate line, because later layers will modify header
  while (!Current_routine->completed())  // later layers will modify condition
  {
    // Running One Instruction.
    if (current_instruction().is_label) { ++current_step_index(); continue; }
    trace("run") << "instruction " << current_recipe_name() << '/' << current_step_index();
    trace("run") << current_instruction().to_string();
    assert(Memory[0] == 0);
    // Read all ingredients from memory.
    // Each ingredient loads a vector of values rather than a single value; mu
    // permits operating on reagents spanning multiple locations.
    vector<vector<double> > ingredients;
    for (index_t i = 0; i < current_instruction().ingredients.size(); ++i) {
      trace("run") << "ingredient " << i << " is " << current_instruction().ingredients.at(i).name;
      ingredients.push_back(read_memory(current_instruction().ingredients.at(i)));
    }
    // Instructions below will write to 'products' or to 'instruction_counter'.
    vector<vector<double> > products;
    index_t instruction_counter = current_step_index();
//?     cout << "AAA: " << current_instruction().to_string() << '\n'; //? 1
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
//?     cout << "BBB: " << current_instruction().to_string() << '\n'; //? 1
    if (products.size() < current_instruction().products.size())
      raise << "failed to write to all products! " << current_instruction().to_string();
//?     cout << "CCC: " << current_instruction().to_string() << '\n'; //? 1
    for (index_t i = 0; i < current_instruction().products.size(); ++i) {
      trace("run") << "product " << i << " is " << current_instruction().products.at(i).name;
      write_memory(current_instruction().products.at(i), products.at(i));
    }
//?     cout << "DDD: " << current_instruction().to_string() << '\n'; //? 1
    current_step_index() = instruction_counter+1;
  }
  stop_running_current_routine:;
}

//: Some helpers.
//: We'll need to override these later as we change the definition of routine.
//: Important that they return referrences into the routine.

inline index_t& current_step_index() {
  return Current_routine->running_step_index;
}

inline const string& current_recipe_name() {
  return Recipe[Current_routine->running_recipe].name;
}

inline const instruction& current_instruction() {
  return Recipe[Current_routine->running_recipe].steps.at(Current_routine->running_step_index);
}

inline bool routine::completed() const {
  return running_step_index >= Recipe[running_recipe].steps.size();
}

:(before "End Commandline Parsing")
// Loading Commandline Files
if (argc > 1) {
  for (int i = 1; i < argc; ++i) {
    load_permanently(argv[i]);
  }
}

:(before "End Main")
if (!Run_tests) {
  setup();
//?   Trace_file = "interactive"; //? 1
  START_TRACING_UNTIL_END_OF_SCOPE;
//?   Trace_stream->dump_layer = "all"; //? 2
  transform_all();
  recipe_number r = Recipe_number[string("main")];
//?   Trace_stream->dump_layer = "all"; //? 1
  if (r) run(r);
//?   dump_memory(); //? 1
  teardown();
}

:(code)
void load_permanently(string filename) {
  ifstream fin(filename.c_str());
  fin.peek();
//?   cerr << "AAA: " << filename << ' ' << static_cast<bool>(fin) << ' ' << fin.fail() << '\n'; //? 1
//?   return; //? 1
  if (!fin) {
    raise << "no such file " << filename << '\n';
    return;
  }
  fin >> std::noskipws;
  load(fin);
  transform_all();
  fin.close();
  // freeze everything so it doesn't get cleared by tests
  recently_added_recipes.clear();
  recently_added_types.clear();
}

//:: On startup, load everything in core.mu
:(before "End Load Recipes")
load_permanently("core.mu");

:(code)
// helper for tests
void run(string form) {
  vector<recipe_number> tmp = load(form);
  if (tmp.empty()) return;
  transform_all();
  run(tmp.front());
}

//:: Reading from memory, writing to memory.

vector<double> read_memory(reagent x) {
//?   cout << "read_memory: " << x.to_string() << '\n'; //? 2
  vector<double> result;
  if (isa_literal(x)) {
    result.push_back(x.value);
    return result;
  }
  index_t base = x.value;
  size_t size = size_of(x);
  for (index_t offset = 0; offset < size; ++offset) {
    double val = Memory[base+offset];
    trace("mem") << "location " << base+offset << " is " << val;
    result.push_back(val);
  }
  return result;
}

void write_memory(reagent x, vector<double> data) {
  if (is_dummy(x)) return;
  index_t base = x.value;
  if (size_of(x) != data.size())
    raise << "size mismatch in storing to " << x.to_string() << '\n';
  for (index_t offset = 0; offset < data.size(); ++offset) {
    trace("mem") << "storing " << data.at(offset) << " in location " << base+offset;
    Memory[base+offset] = data.at(offset);
  }
}

:(code)
size_t size_of(const reagent& r) {
  return size_of(r.types);
}
size_t size_of(const vector<type_number>& types) {
  // End size_of(types) Cases
  return 1;
}

bool is_dummy(const reagent& x) {
  return x.name == "_";
}

bool isa_literal(const reagent& r) {
  return r.types.size() == 1 && r.types.at(0) == 0;
}

:(scenario run_label)
recipe main [
  +foo
  1:integer <- copy 23:literal
  2:integer <- copy 1:integer
]
+run: instruction main/1
+run: instruction main/2
-run: instruction main/0

:(scenario run_dummy)
recipe main [
  _ <- copy 0:literal
]
+run: instruction main/0

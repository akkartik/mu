//: Spaces help isolate recipes from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)
//:
//: Spaces are often called 'scopes' in other languages. Stack frames are a
//: limited form of space that can't outlive callers.
//:
//: Warning: messing with 'default-space' can corrupt memory. Don't share
//: default-space between recipes. Later we'll see how to chain spaces safely.
//:
//: Tests in this layer can write to a location as part of one type, and read
//: it as part of another. This is unsafe and insecure, and we'll stop doing
//: this once we switch to variable names.

//: Under the hood, a space is an array of locations in memory.
:(before "End Mu Types Initialization")
put(Type_abbreviations, "space", new_type_tree("address:array:location"));

:(code)
void test_set_default_space() {
  run(
      "def main [\n"
         // prepare default-space address
      "  10:num/alloc-id, 11:num <- copy 0, 1000\n"
         // prepare default-space payload
      "  1000:num <- copy 0\n"  // alloc id of payload
      "  1001:num <- copy 5\n"  // length
         // actual start of this recipe
      "  default-space:space <- copy 10:&:@:location\n"
         // if default-space is 1000, then:
         //   1000: alloc id
         //   1001: array size
         //   1002: location 0 (space for the chaining slot; described later; often unused)
         //   1003: location 1 (space for the chaining slot; described later; often unused)
         //   1004: local 2 (assuming it is a scalar)
      "  2:num <- copy 93\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 93 in location 1004\n"
  );
}

void test_lookup_sidesteps_default_space() {
  run(
      "def main [\n"
         // prepare default-space address
      "  10:num/alloc-id, 11:num <- copy 0, 1000\n"
         // prepare default-space payload
      "  1000:num <- copy 0\n"  // alloc id of payload
      "  1001:num <- copy 5\n"  // length
         // prepare payload outside the local scope
      "  2000:num/alloc-id, 2001:num <- copy 0, 34\n"
         // actual start of this recipe
      "  default-space:space <- copy 10:&:@:location\n"
         // a local address
      "  2:num, 3:num <- copy 0, 2000\n"
      "  20:num/raw <- copy *2:&:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 2000 in location 1005\n"
      "mem: storing 34 in location 20\n"
  );
}

//: precondition: disable name conversion for 'default-space'

void test_convert_names_passes_default_space() {
  Hide_errors = true;
  transform(
      "def main [\n"
      "  default-space:num <- copy 0\n"
      "  x:num <- copy 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "name: assign x 2\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("name: assign default-space 1");
  CHECK_TRACE_DOESNT_CONTAIN("name: assign default-space 2");
}

:(before "End is_disqualified Special-cases")
if (x.name == "default-space")
  x.initialized = true;
:(before "End is_special_name Special-cases")
if (s == "default-space") return true;

//: core implementation

:(before "End call Fields")
int default_space;
:(before "End call Constructor")
default_space = 0;

:(before "Begin canonize(x) Lookups")
absolutize(x);
:(code)
void absolutize(reagent& x) {
  if (is_raw(x) || is_dummy(x)) return;
  if (x.name == "default-space") return;
  if (!x.initialized)
    raise << to_original_string(current_instruction()) << ": reagent not initialized: '" << x.original_string << "'\n" << end();
  x.set_value(address(x.value, space_base(x)));
  x.properties.push_back(pair<string, string_tree*>("raw", NULL));
  assert(is_raw(x));
}

//: hook replaced in a later layer
int space_base(const reagent& x) {
  return current_call().default_space ? (current_call().default_space + /*skip alloc id*/1) : 0;
}

int address(int offset, int base) {
  assert(offset >= 0);
  if (base == 0) return offset;  // raw
  int size = get_or_insert(Memory, base);
  if (offset >= size) {
    // todo: test
    raise << current_recipe_name() << ": location " << offset << " is out of bounds " << size << " at " << base << '\n' << end();
    DUMP("");
    exit(1);
    return 0;
  }
  return base + /*skip length*/1 + offset;
}

//: reads and writes to the 'default-space' variable have special behavior

:(after "Begin Preprocess write_memory(x, data)")
if (x.name == "default-space") {
  if (!is_mu_space(x))
    raise << maybe(current_recipe_name()) << "'default-space' should be of type address:array:location, but is " << to_string(x.type) << '\n' << end();
  if (SIZE(data) != 2)
    raise << maybe(current_recipe_name()) << "'default-space' getting data from non-address\n" << end();
  current_call().default_space = data.at(/*skip alloc id*/1);
  return;
}
:(code)
bool is_mu_space(reagent/*copy*/ x) {
  canonize_type(x);
  if (!is_compound_type_starting_with(x.type, "address")) return false;
  drop_from_type(x, "address");
  if (!is_compound_type_starting_with(x.type, "array")) return false;
  drop_from_type(x, "array");
  return x.type && x.type->atom && x.type->name == "location";
}

void test_get_default_space() {
  run(
      "def main [\n"
         // prepare default-space address
      "  10:num/alloc-id, 11:num <- copy 0, 1000\n"
         // prepare default-space payload
      "  1000:num <- copy 0\n"  // alloc id of payload
      "  1001:num <- copy 5\n"  // length
         // actual start of this recipe
      "  default-space:space <- copy 10:space\n"
      "  2:space/raw <- copy default-space:space\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1000 in location 3\n"
  );
}

:(after "Begin Preprocess read_memory(x)")
if (x.name == "default-space") {
  vector<double> result;
  result.push_back(/*alloc id*/0);
  result.push_back(current_call().default_space);
  return result;
}

//:: fix 'get'

:(code)
void test_lookup_sidesteps_default_space_in_get() {
  run(
      "def main [\n"
         // prepare default-space address
      "  10:num/alloc-id, 11:num <- copy 0, 1000\n"
         // prepare default-space payload
      "  1000:num <- copy 0\n"  // alloc id of payload
      "  1001:num <- copy 5\n"  // length
         // prepare payload outside the local scope
      "  2000:num/alloc-id, 2001:num/x, 2002:num/y <- copy 0, 34, 35\n"
         // actual start of this recipe
      "  default-space:space <- copy 10:space\n"
         // a local address
      "  2:num, 3:num <- copy 0, 2000\n"
      "  3000:num/raw <- get *2:&:point, 1:offset\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 35 in location 3000\n"
  );
}

:(before "Read element" following "case GET:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: fix 'index'

:(code)
void test_lookup_sidesteps_default_space_in_index() {
  run(
      "def main [\n"
         // prepare default-space address
      "  10:num/alloc-id, 11:num <- copy 0, 1000\n"
         // prepare default-space payload
      "  1000:num <- copy 0\n"  // alloc id of payload
      "  1001:num <- copy 5\n"  // length
         // prepare an array address
      "  20:num/alloc-id, 21:num <- copy 0, 2000\n"
         // prepare an array payload
      "  2000:num/alloc-id, 2001:num/length, 2002:num/index:0, 2003:num/index:1 <- copy 0, 2, 34, 35\n"
         // actual start of this recipe
      "  default-space:space <- copy 10:&:@:location\n"
      "  1:&:@:num <- copy 20:&:@:num/raw\n"
      "  3000:num/raw <- index *1:&:@:num, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 35 in location 3000\n"
  );
}

:(before "Read element" following "case INDEX:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: 'local-scope' is a convenience operation to automatically deduce
//:: the amount of space to allocate in a default space with names

:(code)
void test_local_scope() {
  run(
      "def main [\n"
      "  local-scope\n"
      "  x:num <- copy 0\n"
      "  y:num <- copy 3\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // allocate space for x and y, as well as the chaining slot at indices 0 and 1
      "mem: array length is 4\n"
  );
}

:(before "End is_disqualified Special-cases")
if (x.name == "number-of-locals")
  x.initialized = true;
:(before "End is_special_name Special-cases")
if (s == "number-of-locals") return true;

:(before "End Rewrite Instruction(curr, recipe result)")
// rewrite 'local-scope' to
//   ```
//   default-space:space <- new location:type, number-of-locals:literal
//   ```
// where number-of-locals is Name[recipe][""]
if (curr.name == "local-scope") {
  rewrite_default_space_instruction(curr);
}
:(code)
void rewrite_default_space_instruction(instruction& curr) {
  if (!curr.ingredients.empty())
    raise << "'" << to_original_string(curr) << "' can't take any ingredients\n" << end();
  curr.name = "new";
  curr.ingredients.push_back(reagent("location:type"));
  curr.ingredients.push_back(reagent("number-of-locals:literal"));
  if (!curr.products.empty())
    raise << "local-scope can't take any results\n" << end();
  curr.products.push_back(reagent("default-space:space"));
}
:(after "Begin Preprocess read_memory(x)")
if (x.name == "number-of-locals") {
  vector<double> result;
  result.push_back(Name[get(Recipe_ordinal, current_recipe_name())][""]);
  if (result.back() == 0)
    raise << "no space allocated for default-space in recipe " << current_recipe_name() << "; are you using names?\n" << end();
  return result;
}
:(after "Begin Preprocess write_memory(x, data)")
if (x.name == "number-of-locals") {
  raise << maybe(current_recipe_name()) << "can't write to special name 'number-of-locals'\n" << end();
  return;
}

//:: all recipes must set default-space one way or another

:(before "End Globals")
bool Hide_missing_default_space_errors = true;
:(before "End Checks")
Transform.push_back(check_default_space);  // idempotent
:(code)
void check_default_space(const recipe_ordinal r) {
  if (Hide_missing_default_space_errors) return;  // skip previous core tests; this is only for Mu code
  const recipe& caller = get(Recipe, r);
  // End check_default_space Special-cases
  // assume recipes with only numeric addresses know what they're doing (usually tests)
  if (!contains_non_special_name(r)) return;
  trace(101, "transform") << "--- check that recipe " << caller.name << " sets default-space" << end();
  if (caller.steps.empty()) return;
  if (!starts_by_setting_default_space(caller))
    raise << caller.name << " does not seem to start with 'local-scope' or 'default-space'\n" << end();
}
bool starts_by_setting_default_space(const recipe& r) {
  return !r.steps.empty()
      && !r.steps.at(0).products.empty()
      && r.steps.at(0).products.at(0).name == "default-space";
}

:(after "Load Mu Prelude")
Hide_missing_default_space_errors = false;
:(after "Test Runs")
Hide_missing_default_space_errors = true;
:(after "Running Main")
Hide_missing_default_space_errors = false;

:(code)
bool contains_non_special_name(const recipe_ordinal r) {
  for (map<string, int>::iterator p = Name[r].begin();  p != Name[r].end();  ++p) {
    if (p->first.empty()) continue;
    if (p->first.find("stash_") == 0) continue;  // generated by rewrite_stashes_to_text (cross-layer)
    if (!is_special_name(p->first))
      return true;
  }
  return false;
}

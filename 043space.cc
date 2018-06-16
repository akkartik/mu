//: Spaces help isolate recipes from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)
//:
//: Spaces are often called 'scopes' in other languages. Stack frames are a
//: limited form of space that can't outlive callers.
//:
//: Warning: messing with 'default-space' can corrupt memory. Don't share
//: default-space between recipes. Later we'll see how to chain spaces safely.

//: Under the hood, a space is an array of locations in memory.
:(before "End Mu Types Initialization")
put(Type_abbreviations, "space", new_type_tree("address:array:location"));

:(scenario set_default_space)
# if default-space is 10, then:
#   10: alloc id
#   11: array size
#   12: local 0 (space for the chaining slot; described later; often unused)
#   13: local 0 (space for the chaining slot; described later; often unused)
#   14: local 2 (assuming it is a scalar)
#   15: local 3
#   ..and so on
def main [
  # pretend address:array:location; in practice we'll use 'new'
  11:num <- copy 5  # length
  default-space:space <- copy 10/unsafe/skip-alloc-id
  2:num <- copy 23
]
+mem: storing 23 in location 14

:(scenario lookup_sidesteps_default_space)
def main [
  # pretend pointer from outside
  2001:num <- copy 34
  # pretend address:array:location; in practice we'll use 'new'
  1001:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 1000/unsafe/skip-alloc-id
  1:&:num <- copy 2000/unsafe/skip-alloc-id  # even local variables always contain raw addresses
  8:num/raw <- copy *1:&:num
]
+mem: storing 34 in location 8

//: precondition: disable name conversion for 'default-space'

:(scenario convert_names_passes_default_space)
% Hide_errors = true;
def main [
  default-space:num, x:num <- copy 0, 1
]
+name: assign x 2
-name: assign default-space 1
-name: assign default-space 2

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
  if (!is_mu_space(x)) {
    raise << maybe(current_recipe_name()) << "'default-space' should be of type address:array:location, but is " << to_string(x.type) << '\n' << end();
    return;
  }
  double space_location = data.at(/*skip alloc id*/1);
  trace("mem") << "storing " << no_scientific(space_location) << " to default_space" << end();
  current_call().default_space = space_location;
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

:(scenario get_default_space)
def main [
  default-space:space <- copy 10/unsafe
  1:space/raw <- copy default-space:space
]
# skip alloc id
+mem: storing 10 in location 2

:(after "Begin Preprocess read_memory(x)")
if (x.name == "default-space") {
  vector<double> result;
  result.push_back(/*alloc id*/0);
  result.push_back(current_call().default_space);
  return result;
}

//:: fix 'get'

:(scenario lookup_sidesteps_default_space_in_get)
def main [
  # pretend pointer to container from outside
  2001:num <- copy 34
  2002:num <- copy 35
  # pretend address:array:location; in practice we'll use 'new'
  1001:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 1000/unsafe/skip-alloc-id
  1:&:point <- copy 2000/unsafe/skip-alloc-id
  9:num/raw <- get *1:&:point, 1:offset
]
+mem: storing 35 in location 9

:(before "Read element" following "case GET:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: fix 'index'

:(scenario lookup_sidesteps_default_space_in_index)
def main [
  # pretend pointer to array from outside
  2001:num <- copy 2  # length
  2002:num <- copy 34
  2003:num <- copy 35
  # pretend address:array:location; in practice we'll use 'new'
  1001:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 1000/unsafe/skip-alloc-id
  1:&:@:num <- copy 2000/unsafe/skip-alloc-id
  9:num/raw <- index *1:&:@:num, 1
]
+mem: storing 35 in location 9

:(before "Read element" following "case INDEX:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: 'local-scope' is a convenience operation to automatically deduce
//:: the amount of space to allocate in a default space with names

:(scenario local_scope)
def main [
  local-scope
  x:num <- copy 0
  y:num <- copy 3
]
# allocate space for x and y, as well as the chaining slot at indices 0 and 1
+mem: array length is 4

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
  trace(9991, "transform") << "--- check that recipe " << caller.name << " sets default-space" << end();
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

// reagent comparison -- only between reagents in a single recipe
bool operator==(const reagent& a, const reagent& b) {
  if (a.name != b.name) return false;
  if (property(a, "space") != property(b, "space")) return false;
  return true;
}

bool operator<(const reagent& a, const reagent& b) {
  int aspace = 0, bspace = 0;
  if (has_property(a, "space")) aspace = to_integer(property(a, "space")->value);
  if (has_property(b, "space")) bspace = to_integer(property(b, "space")->value);
  if (aspace != bspace) return aspace < bspace;
  return a.name < b.name;
}

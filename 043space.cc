//: Spaces help isolate recipes from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)

:(scenario set_default_space)
# if default-space is 10, and if an array of 5 locals lies from location 12 to 16 (inclusive),
# then local 0 is really location 12, local 1 is really location 13, and so on.
recipe main [
  # pretend shared:array:location; in practice we'll use new
  10:number <- copy 0  # refcount
  11:number <- copy 5  # length
  default-space:address:shared:array:location <- copy 10/unsafe
  1:number <- copy 23
]
+mem: storing 23 in location 13

:(scenario lookup_sidesteps_default_space)
recipe main [
  # pretend pointer from outside
  3:number <- copy 34
  # pretend shared:array:location; in practice we'll use new
  1000:number <- copy 0  # refcount
  1001:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:shared:array:location <- copy 1000/unsafe
  1:address:number <- copy 3/unsafe
  8:number/raw <- copy *1:address:number
]
+mem: storing 34 in location 8

//:: first disable name conversion for 'default-space'
:(scenario convert_names_passes_default_space)
% Hide_errors = true;
recipe main [
  default-space:number, x:number <- copy 0, 1
]
+name: assign x 1
-name: assign default-space 1

:(before "End is_disqualified Cases")
if (x.name == "default-space")
  x.initialized = true;
:(before "End is_special_name Cases")
if (s == "default-space") return true;

//:: now implement space support
:(before "End call Fields")
long long int default_space;
:(before "End call Constructor")
default_space = 0;

:(before "End canonize(x) Special-cases")
  absolutize(x);
:(code)
void absolutize(reagent& x) {
  if (is_raw(x) || is_dummy(x)) return;
  if (x.name == "default-space") return;
  if (!x.initialized) {
    raise_error << current_instruction().to_string() << ": reagent not initialized: " << x.original_string << '\n' << end();
  }
  x.set_value(address(x.value, space_base(x)));
  x.properties.push_back(pair<string, string_tree*>("raw", NULL));
  assert(is_raw(x));
}

long long int space_base(const reagent& x) {
  // temporary stub; will be replaced in a later layer
  return current_call().default_space ? (current_call().default_space+/*skip refcount*/1) : 0;
}

long long int address(long long int offset, long long int base) {
  if (base == 0) return offset;  // raw
  long long int size = get_or_insert(Memory, base);
  if (offset >= size) {
    // todo: test
    raise_error << "location " << offset << " is out of bounds " << size << " at " << base << '\n' << end();
    return 0;
  }
  return base + /*skip length*/1 + offset;
}

//:: reads and writes to the 'default-space' variable have special behavior

:(after "void write_memory(reagent x, vector<double> data)")
  if (x.name == "default-space") {
    if (!scalar(data)
        || !x.type
        || x.type->value != get(Type_ordinal, "address")
        || !x.type->right
        || x.type->right->value != get(Type_ordinal, "shared")
        || !x.type->right->right
        || x.type->right->right->value != get(Type_ordinal, "array")
        || !x.type->right->right->right
        || x.type->right->right->right->value != get(Type_ordinal, "location")
        || x.type->right->right->right->right) {
      raise_error << maybe(current_recipe_name()) << "'default-space' should be of type address:shared:array:location, but tried to write " << to_string(data) << '\n' << end();
    }
    current_call().default_space = data.at(0);
    return;
  }

:(scenario get_default_space)
recipe main [
  default-space:address:shared:array:location <- copy 10/unsafe
  1:address:shared:array:location/raw <- copy default-space:address:shared:array:location
]
+mem: storing 10 in location 1

:(after "vector<double> read_memory(reagent x)")
  if (x.name == "default-space") {
    vector<double> result;
    result.push_back(current_call().default_space);
    return result;
  }

//:: fix 'get'

:(scenario lookup_sidesteps_default_space_in_get)
recipe main [
  # pretend pointer to container from outside
  12:number <- copy 34
  13:number <- copy 35
  # pretend shared:array:location; in practice we'll use new
  1000:number <- copy 0  # refcount
  1001:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:shared:array:location <- copy 1000/unsafe
  1:address:point <- copy 12/unsafe
  9:number/raw <- get *1:address:point, 1:offset
]
+mem: storing 35 in location 9

:(after "reagent tmp" following "case GET:")
tmp.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: fix 'index'

:(scenario lookup_sidesteps_default_space_in_index)
recipe main [
  # pretend pointer to array from outside
  12:number <- copy 2
  13:number <- copy 34
  14:number <- copy 35
  # pretend shared:array:location; in practice we'll use new
  1000:number <- copy 0  # refcount
  1001:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:shared:array:location <- copy 1000/unsafe
  1:address:array:number <- copy 12/unsafe
  9:number/raw <- index *1:address:array:number, 1
]
+mem: storing 35 in location 9

:(after "reagent tmp" following "case INDEX:")
tmp.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: convenience operation to automatically deduce the amount of space to
//:: allocate in a default space with names

:(scenario new_default_space)
recipe main [
  new-default-space
  x:number <- copy 0
  y:number <- copy 3
]
# allocate space for x and y, as well as the chaining slot at 0
+mem: array size is 3

:(before "End is_disqualified Cases")
if (x.name == "number-of-locals")
  x.initialized = true;
:(before "End is_special_name Cases")
if (s == "number-of-locals") return true;

:(before "End Rewrite Instruction(curr, recipe result)")
// rewrite `new-default-space` to
//   `default-space:address:shared:array:location <- new location:type, number-of-locals:literal`
// where N is Name[recipe][""]
if (curr.name == "new-default-space") {
  rewrite_default_space_instruction(curr);
}
:(after "vector<double> read_memory(reagent x)")
  if (x.name == "number-of-locals") {
    vector<double> result;
    result.push_back(Name[get(Recipe_ordinal, current_recipe_name())][""]);
    if (result.back() == 0)
      raise_error << "no space allocated for default-space in recipe " << current_recipe_name() << "; are you using names?\n" << end();
    return result;
  }
:(after "void write_memory(reagent x, vector<double> data)")
  if (x.name == "number-of-locals") {
    raise_error << maybe(current_recipe_name()) << "can't write to special name 'number-of-locals'\n" << end();
    return;
  }

//:: a little hook to automatically reclaim the default-space when returning
//:: from a recipe

:(scenario local_scope)
recipe main [
  1:address <- foo
  2:address <- foo
  3:boolean <- equal 1:address, 2:address
]
recipe foo [
  local-scope
  x:number <- copy 34
  reply default-space:address:shared:array:location
]
# both calls to foo should have received the same default-space
+mem: storing 1 in location 3

:(after "Falling Through End Of Recipe")
try_reclaim_locals();
:(after "Starting Reply")
try_reclaim_locals();

//: now 'local-scope' is identical to 'new-default-space' except that we'll
//: reclaim the default-space when the routine exits
:(before "End Rewrite Instruction(curr, recipe result)")
if (curr.name == "local-scope") {
  rewrite_default_space_instruction(curr);
}

:(code)
void try_reclaim_locals() {
  // only reclaim routines starting with 'local-scope'
  const recipe_ordinal r = get(Recipe_ordinal, current_recipe_name());
  if (get(Recipe, r).steps.empty()) return;
  const instruction& inst = get(Recipe, r).steps.at(0);
  if (inst.old_name != "local-scope") return;
  abandon(current_call().default_space,
          /*refcount*/1 + /*array length*/1 + /*number-of-locals*/Name[r][""]);
}

void rewrite_default_space_instruction(instruction& curr) {
  if (!curr.ingredients.empty())
    raise_error << curr.to_string() << " can't take any ingredients\n" << end();
  curr.name = "new";
  curr.ingredients.push_back(reagent("location:type"));
  curr.ingredients.push_back(reagent("number-of-locals:literal"));
  if (!curr.products.empty())
    raise_error << "new-default-space can't take any results\n" << end();
  curr.products.push_back(reagent("default-space:address:shared:array:location"));
}

//:: all recipes must set default-space one way or another

:(before "End Globals")
bool Warn_on_missing_default_space = false;
:(before "End Checks")
Transform.push_back(check_default_space);  // idempotent
:(code)
void check_default_space(const recipe_ordinal r) {
  if (!Warn_on_missing_default_space) return;  // skip previous core tests; this is only for mu code
  const recipe& caller = get(Recipe, r);
  // skip scenarios (later layer)
  // user code should never create recipes with underscores in their names
  if (caller.name.find("scenario_") == 0) return;  // skip mu scenarios which will use raw memory locations
  if (caller.name.find("run_") == 0) return;  // skip calls to 'run', which should be in scenarios and will also use raw memory locations
  // assume recipes with only numeric addresses know what they're doing (usually tests)
  if (!contains_non_special_name(r)) return;
  trace(9991, "transform") << "--- check that recipe " << caller.name << " sets default-space" << end();
  if (caller.steps.empty()) return;
  if (caller.steps.at(0).products.empty()
      || caller.steps.at(0).products.at(0).name != "default-space") {
    raise << maybe(caller.name) << " does not seem to start with default-space or local-scope\n" << end();
//?     cerr << maybe(caller.name) << " does not seem to start with default-space or local-scope\n" << '\n';
  }
}
:(after "Load .mu Core")
Warn_on_missing_default_space = true;
:(after "Test Runs")
Warn_on_missing_default_space = false;
:(after "Running Main")
Warn_on_missing_default_space = true;

:(code)
bool contains_non_special_name(const recipe_ordinal r) {
  for (map<string, long long int>::iterator p = Name[r].begin(); p != Name[r].end(); ++p) {
    if (p->first.empty()) continue;
    if (p->first.find("stash_") == 0) continue;  // generated by rewrite_stashes_to_text (cross-layer)
    if (!is_special_name(p->first)) {
//?       cerr << "  " << Recipe[r].name << ": " << p->first << '\n';
      return true;
    }
  }
  return false;
}

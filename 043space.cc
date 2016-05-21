//: Spaces help isolate recipes from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)

:(scenario set_default_space)
# if default-space is 10, and if an array of 5 locals lies from location 12 to 16 (inclusive),
# then local 0 is really location 12, local 1 is really location 13, and so on.
def main [
  # pretend address:array:location; in practice we'll use new
  10:number <- copy 0  # refcount
  11:number <- copy 5  # length
  default-space:address:array:location <- copy 10/unsafe
  1:number <- copy 23
]
+mem: storing 23 in location 13

:(scenario lookup_sidesteps_default_space)
def main [
  # pretend pointer from outside (2000 reserved for refcount)
  2001:number <- copy 34
  # pretend address:array:location; in practice we'll use new
  1000:number <- copy 0  # refcount
  1001:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:array:location <- copy 1000/unsafe
  1:address:number <- copy 2000/unsafe  # even local variables always contain raw addresses
  8:number/raw <- copy *1:address:number
]
+mem: storing 34 in location 8

//:: first disable name conversion for 'default-space'
:(scenario convert_names_passes_default_space)
% Hide_errors = true;
def main [
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
int default_space;
:(before "End call Constructor")
default_space = 0;

:(before "End canonize(x) Special-cases")
absolutize(x);
:(code)
void absolutize(reagent& x) {
  if (is_raw(x) || is_dummy(x)) return;
  if (x.name == "default-space") return;
  if (!x.initialized) {
    raise << to_original_string(current_instruction()) << ": reagent not initialized: '" << x.original_string << "'\n" << end();
  }
  x.set_value(address(x.value, space_base(x)));
  x.properties.push_back(pair<string, string_tree*>("raw", NULL));
  assert(is_raw(x));
}

int space_base(const reagent& x) {
  // temporary stub; will be replaced in a later layer
  return current_call().default_space ? (current_call().default_space+/*skip refcount*/1) : 0;
}

int address(int offset, int base) {
  assert(offset >= 0);
  if (base == 0) return offset;  // raw
  int size = get_or_insert(Memory, base);
  if (offset >= size) {
    // todo: test
    raise << "location " << offset << " is out of bounds " << size << " at " << base << '\n' << end();
    return 0;
  }
  return base + /*skip length*/1 + offset;
}

//:: reads and writes to the 'default-space' variable have special behavior

:(after "Begin Preprocess write_memory(x, data)")
if (x.name == "default-space") {
  if (!scalar(data)
      || !x.type
      || x.type->value != get(Type_ordinal, "address")
      || !x.type->right
      || x.type->right->value != get(Type_ordinal, "array")
      || !x.type->right->right
      || x.type->right->right->value != get(Type_ordinal, "location")
      || x.type->right->right->right) {
    raise << maybe(current_recipe_name()) << "'default-space' should be of type address:array:location, but is " << to_string(x.type) << '\n' << end();
  }
  current_call().default_space = data.at(0);
  return;
}

:(scenario get_default_space)
def main [
  default-space:address:array:location <- copy 10/unsafe
  1:address:array:location/raw <- copy default-space:address:array:location
]
+mem: storing 10 in location 1

:(after "Begin Preprocess read_memory(x)")
if (x.name == "default-space") {
  vector<double> result;
  result.push_back(current_call().default_space);
  return result;
}

//:: fix 'get'

:(scenario lookup_sidesteps_default_space_in_get)
def main [
  # pretend pointer to container from outside (2000 reserved for refcount)
  2001:number <- copy 34
  2002:number <- copy 35
  # pretend address:array:location; in practice we'll use new
  1000:number <- copy 0  # refcount
  1001:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:array:location <- copy 1000/unsafe
  1:address:point <- copy 2000/unsafe
  9:number/raw <- get *1:address:point, 1:offset
]
+mem: storing 35 in location 9

:(before "Read element" following "case GET:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: fix 'index'

:(scenario lookup_sidesteps_default_space_in_index)
def main [
  # pretend pointer to array from outside (2000 reserved for refcount)
  2001:number <- copy 2  # length
  2002:number <- copy 34
  2003:number <- copy 35
  # pretend address:array:location; in practice we'll use new
  1000:number <- copy 0  # refcount
  1001:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:array:location <- copy 1000/unsafe
  1:address:array:number <- copy 2000/unsafe
  9:number/raw <- index *1:address:array:number, 1
]
+mem: storing 35 in location 9

:(before "Read element" following "case INDEX:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: convenience operation to automatically deduce the amount of space to
//:: allocate in a default space with names

:(scenario new_default_space)
def main [
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
//   `default-space:address:array:location <- new location:type, number-of-locals:literal`
// where N is Name[recipe][""]
if (curr.name == "new-default-space") {
  rewrite_default_space_instruction(curr);
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

//:: 'local-scope' is like 'new-default-space' except that we'll reclaim the
//:: default-space when the routine exits

:(scenario local_scope)
def main [
  1:address <- foo
  2:address <- foo
  3:boolean <- equal 1:address, 2:address
]
def foo [
  local-scope
  x:number <- copy 34
  return default-space:address:array:location
]
# both calls to foo should have received the same default-space
+mem: storing 1 in location 3

:(scenario local_scope_frees_up_addresses)
def main [
  local-scope
  x:address:array:character <- new [abc]
]
+mem: clearing x:address:array:character

:(before "End Rewrite Instruction(curr, recipe result)")
if (curr.name == "local-scope") {
  rewrite_default_space_instruction(curr);
}

//: todo: do this in a transform, rather than magically in the reply instruction
:(after "Falling Through End Of Recipe")
try_reclaim_locals();
:(after "Starting Reply")
try_reclaim_locals();

:(code)
void try_reclaim_locals() {
  // only reclaim routines starting with 'local-scope'
  const recipe_ordinal r = get(Recipe_ordinal, current_recipe_name());
  const recipe& exiting_recipe = get(Recipe, r);
  if (exiting_recipe.steps.empty()) return;
  const instruction& inst = exiting_recipe.steps.at(0);
  if (inst.old_name != "local-scope") return;
  // reclaim any local variables unless they're being returned
  vector<double> zeros;
  for (int i = /*leave default space for last*/1; i < SIZE(exiting_recipe.steps); ++i) {
    const instruction& inst = exiting_recipe.steps.at(i);
    for (int i = 0; i < SIZE(inst.products); ++i) {
      // local variables only
      if (has_property(inst.products.at(i), "space")) continue;
      if (has_property(inst.products.at(i), "lookup")) continue;
      if (has_property(inst.products.at(i), "raw")) continue;  // tests often want to check such locations after they run
      if (escaping(inst.products.at(i))) continue;
      trace(9999, "mem") << "clearing " << inst.products.at(i).original_string << end();
      zeros.resize(size_of(inst.products.at(i)));
      write_memory(inst.products.at(i), zeros, /*always update refcounts*/-1);
    }
  }
  trace(9999, "mem") << "automatically abandoning " << current_call().default_space << end();
  abandon(current_call().default_space,
          inst.products.at(0).type->right,
          /*refcount*/1 + /*array length*/1 + /*number-of-locals*/Name[r][""]);
}

//: since we don't decrement refcounts for escaping values above, make sure we
//: don't increment them when the caller saves them either

:(replace{} "bool should_update_refcounts_in_write_memory(int product_index)")
bool should_update_refcounts_in_write_memory(int product_index) {
  assert(Current_routine);  // run-time only
  if (product_index == -1) return true;
  assert(product_index >= 0);
  const instruction& inst = current_instruction();
  if (inst.operation < MAX_PRIMITIVE_RECIPES) return true;
  if (!contains_key(Recipe, inst.operation)) return true;
  const recipe& caller = get(Recipe, inst.operation);
  if (caller.steps.empty()) return true;
  // if the recipe deosn't begin with 'local-scope', always update refcounts
  return caller.steps.at(0).old_name != "local-scope";
}

:(code)
// is this reagent one of the values returned by the current (reply) instruction?
// is the corresponding ingredient saved in the caller?
bool escaping(const reagent& r) {
  assert(Current_routine);  // run-time only
  // nothing escapes when you fall through past end of recipe
  if (current_step_index() >= SIZE(Current_routine->steps())) return false;
  for (long long i = 0; i < SIZE(current_instruction().ingredients); ++i) {
    if (r == current_instruction().ingredients.at(i)) {
    if (caller_uses_product(i))
      return true;
    }
  }
  return false;
}

bool caller_uses_product(int product_index) {
  assert(Current_routine);  // run-time only
  assert(!Current_routine->calls.empty());
  if (Current_routine->calls.size() == 1) return false;
  const call& caller = *++Current_routine->calls.begin();
  const instruction& caller_inst = to_instruction(caller);
  if (product_index >= SIZE(caller_inst.products)) return false;
  return !is_dummy(caller_inst.products.at(product_index));
}

void rewrite_default_space_instruction(instruction& curr) {
  if (!curr.ingredients.empty())
    raise << to_original_string(curr) << " can't take any ingredients\n" << end();
  curr.name = "new";
  curr.ingredients.push_back(reagent("location:type"));
  curr.ingredients.push_back(reagent("number-of-locals:literal"));
  if (!curr.products.empty())
    raise << "new-default-space can't take any results\n" << end();
  curr.products.push_back(reagent("default-space:address:array:location"));
}

:(scenario local_scope_frees_up_addresses_inside_containers)
container foo [
  x:number
  y:address:number
]
def main [
  local-scope
  x:address:number <- new number:type
  y:foo <- merge 34, x:address:number
  # x and y are both cleared when main returns
]
+mem: clearing x:address:number
+mem: decrementing refcount of 1006: 2 -> 1
+mem: clearing y:foo
+mem: decrementing refcount of 1006: 1 -> 0
+mem: automatically abandoning 1006

:(scenario local_scope_returns_addresses_inside_containers)
container foo [
  x:number
  y:address:number
]
def f [
  local-scope
  x:address:number <- new number:type
  *x:address:number <- copy 12
  y:foo <- merge 34, x:address:number
  # since y is 'escaping' f, it should not be cleared
  return y:foo
]
def main [
  1:foo <- f
  3:number <- get 1:foo, x:offset
  4:address:number <- get 1:foo, y:offset
  5:number <- copy *4:address:number
  1:foo <- put 1:foo, y:offset, 0
  4:address:number <- copy 0
]
+mem: storing 34 in location 1
+mem: storing 1006 in location 2
+mem: storing 34 in location 3
# refcount of 1:foo shouldn't include any stray ones from f
+run: {4: ("address" "number")} <- get {1: "foo"}, {y: "offset"}
+mem: incrementing refcount of 1006: 1 -> 2
# 1:foo wasn't abandoned/cleared
+run: {5: "number"} <- copy {4: ("address" "number"), "lookup": ()}
+mem: storing 12 in location 5
+run: {1: "foo"} <- put {1: "foo"}, {y: "offset"}, {0: "literal"}
+mem: decrementing refcount of 1006: 2 -> 1
+run: {4: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1006: 1 -> 0
+mem: automatically abandoning 1006

:(scenario local_scope_claims_return_values_when_not_saved)
def f [
  local-scope
  x:address:number <- new number:type
  reply x:address:number
]
def main [
  f  # doesn't save result
]
# x reclaimed
+mem: automatically abandoning 1004
# f's local scope reclaimed
+mem: automatically abandoning 1000

//:: all recipes must set default-space one way or another

:(before "End Globals")
bool Hide_missing_default_space_errors = true;
:(before "End Checks")
Transform.push_back(check_default_space);  // idempotent
:(code)
void check_default_space(const recipe_ordinal r) {
  if (Hide_missing_default_space_errors) return;  // skip previous core tests; this is only for mu code
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
    raise << caller.name << " does not seem to start with default-space or local-scope\n" << end();
  }
}
:(after "Load .mu Core")
Hide_missing_default_space_errors = false;
:(after "Test Runs")
Hide_missing_default_space_errors = true;
:(after "Running Main")
Hide_missing_default_space_errors = false;

:(code)
bool contains_non_special_name(const recipe_ordinal r) {
  for (map<string, int>::iterator p = Name[r].begin(); p != Name[r].end(); ++p) {
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

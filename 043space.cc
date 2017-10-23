//: Spaces help isolate recipes from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)
//:
//: Spaces are often called 'scopes' in other languages. Stack frames are a
//: limited form of space that can't outlive callers.
//:
//: Warning: messing with 'default-space' can corrupt memory. Don't do things
//: like initialize default-space with some other function's default-space.
//: Later we'll see how to chain spaces safely.

//: Under the hood, a space is an array of locations in memory.
:(before "End Mu Types Initialization")
put(Type_abbreviations, "space", new_type_tree("address:array:location"));

:(scenario set_default_space)
# if default-space is 10, and if an array of 5 locals lies from location 12 to 16 (inclusive),
# then local 0 is really location 12, local 1 is really location 13, and so on.
def main [
  # pretend address:array:location; in practice we'll use 'new'
  10:num <- copy 0  # refcount
  11:num <- copy 5  # length
  default-space:space <- copy 10/unsafe
  1:num <- copy 23
]
+mem: storing 23 in location 13

:(scenario lookup_sidesteps_default_space)
def main [
  # pretend pointer from outside (2000 reserved for refcount)
  2001:num <- copy 34
  # pretend address:array:location; in practice we'll use 'new"
  1000:num <- copy 0  # refcount
  1001:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 1000/unsafe
  1:&:num <- copy 2000/unsafe  # even local variables always contain raw addresses
  8:num/raw <- copy *1:&:num
]
+mem: storing 34 in location 8

//: precondition: disable name conversion for 'default-space'

:(scenario convert_names_passes_default_space)
% Hide_errors = true;
def main [
  default-space:num, x:num <- copy 0, 1
]
+name: assign x 1
-name: assign default-space 1

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

//: reads and writes to the 'default-space' variable have special behavior

:(after "Begin Preprocess write_memory(x, data)")
if (x.name == "default-space") {
  if (!scalar(data) || !is_space(x))
    raise << maybe(current_recipe_name()) << "'default-space' should be of type address:array:location, but is " << to_string(x.type) << '\n' << end();
  current_call().default_space = data.at(0);
  return;
}
:(code)
bool is_space(const reagent& r) {
  return is_address_of_array_of_numbers(r);
}

:(scenario get_default_space)
def main [
  default-space:space <- copy 10/unsafe
  1:space/raw <- copy default-space:space
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
  2001:num <- copy 34
  2002:num <- copy 35
  # pretend address:array:location; in practice we'll use 'new'
  1000:num <- copy 0  # refcount
  1001:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 1000/unsafe
  1:&:point <- copy 2000/unsafe
  9:num/raw <- get *1:&:point, 1:offset
]
+mem: storing 35 in location 9

:(before "Read element" following "case GET:")
element.properties.push_back(pair<string, string_tree*>("raw", NULL));

//:: fix 'index'

:(scenario lookup_sidesteps_default_space_in_index)
def main [
  # pretend pointer to array from outside (2000 reserved for refcount)
  2001:num <- copy 2  # length
  2002:num <- copy 34
  2003:num <- copy 35
  # pretend address:array:location; in practice we'll use 'new'
  1000:num <- copy 0  # refcount
  1001:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 1000/unsafe
  1:&:@:num <- copy 2000/unsafe
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
# allocate space for x and y, as well as the chaining slot at 0
+mem: array length is 3

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
    raise << "new-default-space can't take any results\n" << end();
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

//:: try to reclaim the default-space when a recipe returns

:(scenario local_scope_reclaimed_on_return)
def main [
  1:num <- foo
  2:num <- foo
  3:bool <- equal 1:num, 2:num
]
def foo [
  local-scope
  result:num <- copy default-space:space
  return result:num
]
# both calls to foo should have received the same default-space
+mem: storing 1 in location 3

//: todo: do this in a transform, rather than magically in the 'return' instruction
:(after "Falling Through End Of Recipe")
reclaim_default_space();
:(after "Begin Return")
reclaim_default_space();
:(code)
void reclaim_default_space() {
  if (!Reclaim_memory) return;
  const recipe_ordinal r = get(Recipe_ordinal, current_recipe_name());
  const recipe& exiting_recipe = get(Recipe, r);
  if (!starts_by_setting_default_space(exiting_recipe)) return;
  // Reclaim default-space
  decrement_refcount(current_call().default_space,
      exiting_recipe.steps.at(0).products.at(0).type->right,
      /*refcount*/1 + /*array length*/1 + /*number-of-locals*/Name[r][""]);
}
bool starts_by_setting_default_space(const recipe& r) {
  return !r.steps.empty()
      && !r.steps.at(0).products.empty()
      && r.steps.at(0).products.at(0).name == "default-space";
}

//:

:(scenario local_scope_reclaims_locals)
def main [
  local-scope
  x:text <- new [abc]
]
# x
+mem: automatically abandoning 1004
# local-scope
+mem: automatically abandoning 1000

:(before "Reclaim default-space")
if (get_or_insert(Memory, current_call().default_space) <= 1) {
  set<string> reclaimed_locals;
  trace(9999, "mem") << "trying to reclaim locals" << end();
  for (int i = /*leave default space for last*/1;  i < SIZE(exiting_recipe.steps);  ++i) {
    const instruction& inst = exiting_recipe.steps.at(i);
    for (int i = 0;  i < SIZE(inst.products);  ++i) {
      reagent/*copy*/ product = inst.products.at(i);
      if (reclaimed_locals.find(product.name) != reclaimed_locals.end()) continue;
      reclaimed_locals.insert(product.name);
      // local variables only
      if (has_property(product, "lookup")) continue;
      if (has_property(product, "raw")) continue;  // tests often want to check such locations after they run
      // End Checks For Reclaiming Locals
      trace(9999, "mem") << "trying to reclaim local " << product.original_string << end();
      canonize(product);
      decrement_any_refcounts(product);
    }
  }
}

:(scenario local_variables_can_outlive_call)
def main [
  local-scope
  x:&:num <- new num:type
  y:space <- copy default-space:space
]
-mem: automatically abandoning 1005

//:

:(scenario local_scope_does_not_reclaim_escaping_locals)
def main [
  1:text <- foo
]
def foo [
  local-scope
  x:text <- new [abc]
  return x:text
]
# local-scope
+mem: automatically abandoning 1000
# x
-mem: automatically abandoning 1004

:(after "Begin Return")  // before reclaiming default-space
increment_refcounts_of_return_ingredients(ingredients);
:(code)
void increment_refcounts_of_return_ingredients(const vector<vector<double> >& ingredients) {
  assert(current_instruction().operation == RETURN);
  if (SIZE(Current_routine->calls) == 1)  // no caller to receive result
    return;
  const instruction& caller_instruction = to_instruction(*++Current_routine->calls.begin());
  for (int i = 0;  i < min(SIZE(current_instruction().ingredients), SIZE(caller_instruction.products));  ++i) {
    if (!is_dummy(caller_instruction.products.at(i))) {
      // no need to canonize ingredient because we ignore its value
      increment_any_refcounts(current_instruction().ingredients.at(i), ingredients.at(i));
    }
  }
}

//:

:(scenario local_scope_frees_up_addresses_inside_containers)
container foo [
  x:num
  y:&:num
]
def main [
  local-scope
  x:&:num <- new number:type
  y:foo <- merge 34, x:&:num
  # x and y are both cleared when main returns
]
+mem: automatically abandoning 1006

:(scenario local_scope_returns_addresses_inside_containers)
container foo [
  x:num
  y:&:num
]
def f [
  local-scope
  x:&:num <- new number:type
  *x:&:num <- copy 12
  y:foo <- merge 34, x:&:num
  # since y is 'escaping' f, it should not be cleared
  return y:foo
]
def main [
  1:foo <- f
  3:num <- get 1:foo, x:offset
  4:&:num <- get 1:foo, y:offset
  5:num <- copy *4:&:num
  1:foo <- put 1:foo, y:offset, 0
  4:&:num <- copy 0
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
  x:&:num <- new number:type
  return x:&:num
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

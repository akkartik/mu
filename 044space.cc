//: Spaces help isolate recipes from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)

:(scenario set_default_space)
# if default-space is 10, and if an array of 5 locals lies from location 11 to 15 (inclusive),
# then location 0 is really location 11, location 1 is really location 12, and so on.
recipe main [
  10:number <- copy 5  # pretend array; in practice we'll use new
  default-space:address:array:location <- copy 10/raw
  1:number <- copy 23
]
+mem: storing 23 in location 12

:(scenario lookup_sidesteps_default_space)
recipe main [
  # pretend pointer from outside
  3:number <- copy 34
  # pretend array
  1000:number <- copy 5
  # actual start of this recipe
  default-space:address:array:location <- copy 1000/raw
  1:address:number <- copy 3/raw
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

:(before "End Disqualified Reagents")
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

//:: fix 'get'

:(scenario lookup_sidesteps_default_space_in_get)
recipe main [
  # pretend pointer to container from outside
  12:number <- copy 34
  13:number <- copy 35
  # pretend array
  1000:number <- copy 5
  # actual start of this recipe
  default-space:address:array:location <- copy 1000/raw
  1:address:point <- copy 12/raw
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
  # pretend array
  1000:number <- copy 5
  # actual start of this recipe
  default-space:address:array:location <- copy 1000/raw
  1:address:array:number <- copy 12/raw
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

:(before "End Disqualified Reagents")
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
:(after "vector<double> read_memory(reagent x)")
  if (x.name == "number-of-locals") {
    vector<double> result;
    result.push_back(Name[Recipe_ordinal[current_recipe_name()]][""]);
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
  reply default-space:address:array:location
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
  const recipe_ordinal r = Recipe_ordinal[current_recipe_name()];
  if (Recipe[r].steps.empty()) return;
  const instruction& inst = Recipe[r].steps.at(0);
  if (inst.name != "local-scope") return;
  abandon(current_call().default_space,
          /*array length*/1+/*number-of-locals*/Name[r][""]);
}

void rewrite_default_space_instruction(instruction& curr) {
  curr.operation = Recipe_ordinal["new"];
  if (!curr.ingredients.empty())
    raise_error << "new-default-space can't take any ingredients\n" << end();
  curr.ingredients.push_back(reagent("location:type"));
  curr.ingredients.push_back(reagent("number-of-locals:literal"));
  if (!curr.products.empty())
    raise_error << "new-default-space can't take any results\n" << end();
  curr.products.push_back(reagent("default-space:address:array:location"));
}

//:: helpers

:(code)
long long int space_base(const reagent& x) {
  // temporary stub; will be replaced in a later layer
  return current_call().default_space;
}

long long int address(long long int offset, long long int base) {
  if (base == 0) return offset;  // raw
  if (offset >= static_cast<long long int>(Memory[base])) {
    // todo: test
    raise_error << "location " << offset << " is out of bounds " << no_scientific(Memory[base]) << " at " << base << '\n' << end();
  }
  return base+1 + offset;
}

:(after "void write_memory(reagent x, vector<double> data)")
  if (x.name == "default-space") {
    if (!scalar(data)
        || !x.type
        || x.type->value != Type_ordinal["address"]
        || !x.type->right
        || x.type->right->value != Type_ordinal["array"]
        || !x.type->right->right
        || x.type->right->right->value != Type_ordinal["location"]
        || x.type->right->right->right) {
      raise_error << maybe(current_recipe_name()) << "'default-space' should be of type address:array:location, but tried to write " << to_string(data) << '\n' << end();
    }
    current_call().default_space = data.at(0);
    return;
  }

:(scenario get_default_space)
recipe main [
  default-space:address:array:location <- copy 10/raw
  1:address:array:location/raw <- copy default-space:address:array:location
]
+mem: storing 10 in location 1

:(after "vector<double> read_memory(reagent x)")
  if (x.name == "default-space") {
    vector<double> result;
    result.push_back(current_call().default_space);
    return result;
  }

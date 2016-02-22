// So far we have local variables, and we can nest local variables of short
// lifetimes inside longer ones. Now let's support 'global' variables that
// last for the life of a routine. If we create multiple routines they won't
// have access to each other's globals.

:(scenario global_space)
recipe main [
  # pretend shared:array:location; in practice we'll use new
  10:number <- copy 0  # refcount
  11:number <- copy 5  # length
  # pretend shared:array:location; in practice we'll use new
  20:number <- copy 0  # refcount
  21:number <- copy 5  # length
  # actual start of this recipe
  global-space:address:shared:array:location <- copy 20/unsafe
  default-space:address:shared:array:location <- copy 10/unsafe
  1:number <- copy 23
  1:number/space:global <- copy 24
]
# store to default space: 10 + /*skip refcount*/1 + /*skip length*/1 + /*index*/1
+mem: storing 23 in location 13
# store to chained space: /*contents of location 12*/20 + /*skip refcount*/1 + /*skip length*/1 + /*index*/1
+mem: storing 24 in location 23

//: to support it, create another special variable called global space
:(before "End is_disqualified Cases")
if (x.name == "global-space")
  x.initialized = true;
:(before "End is_special_name Cases")
if (s == "global-space") return true;

//: writes to this variable go to a field in the current routine
:(before "End routine Fields")
long long int global_space;
:(before "End routine Constructor")
global_space = 0;
:(after "void write_memory(reagent x, vector<double> data)")
  if (x.name == "global-space") {
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
      raise_error << maybe(current_recipe_name()) << "'global-space' should be of type address:shared:array:location, but tried to write " << to_string(data) << '\n' << end();
    }
    if (Current_routine->global_space)
      raise_error << "routine already has a global-space; you can't over-write your globals" << end();
    Current_routine->global_space = data.at(0);
    return;
  }

//: now marking variables as /space:global looks them up inside this field
:(after "long long int space_base(const reagent& x)")
  if (is_global(x)) {
    if (!Current_routine->global_space)
      raise_error << "routine has no global space\n" << end();
    return Current_routine->global_space + /*skip refcount*/1;
  }

//: for now let's not bother giving global variables names.
//: don't want to make them too comfortable to use.

:(scenario global_space_with_names)
% Hide_errors = true;
recipe main [
  global-space:address:shared:array:location <- new location:type, 10
  x:number <- copy 23
  1:number/space:global <- copy 24
]
# don't complain about mixing numeric addresses and names
$error: 0

:(after "bool is_numeric_location(const reagent& x)")
  if (is_global(x)) return false;

//: helpers

:(code)
bool is_global(const reagent& x) {
  for (long long int i = 0; i < SIZE(x.properties); ++i) {
    if (x.properties.at(i).first == "space")
      return x.properties.at(i).second && x.properties.at(i).second->value == "global";
  }
  return false;
}

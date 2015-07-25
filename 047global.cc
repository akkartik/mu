// So far we have local variables, and we can nest local variables of short
// lifetimes inside longer ones. Now let's support 'global' variables that
// last for the life of a routine. If we create multiple routines they won't
// have access to each other's globals.

:(scenario global_space)
recipe main [
  # pretend arrays; in practice we'll use new
  10:number <- copy 5:literal
  20:number <- copy 5:literal
  # actual start of this recipe
  global-space:address:array:location <- copy 20:literal
  default-space:address:array:location <- copy 10:literal
  1:number <- copy 23:literal
  1:number/space:global <- copy 24:literal
]
+mem: storing 23 in location 12
+mem: storing 24 in location 22

//: to support it, create another special variable called global space
:(before "End Disqualified Reagents")
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
    assert(scalar(data));
    if (Current_routine->global_space)
      raise << "routine already has a global-space; you can't over-write your globals" << end();
    Current_routine->global_space = data.at(0);
    return;
  }

//: now marking variables as /space:global looks them up inside this field
:(after "long long int space_base(const reagent& x)")
  if (is_global(x)) {
    if (!Current_routine->global_space)
      raise << "routine has no global space\n" << end();
    return Current_routine->global_space;
  }

//: for now let's not bother giving global variables names.
//: don't want to make them too comfortable to use.

:(scenario global_space_with_names)
% Hide_warnings = true;
recipe main [
  global-space:address:array:location <- new location:type, 10:literal
  x:number <- copy 23:literal
  1:number/space:global <- copy 24:literal
]
# don't warn that we're mixing numeric addresses and names
$warn: 0

:(after "bool is_numeric_location(const reagent& x)")
  if (is_global(x)) return false;

//: helpers

:(code)
bool is_global(const reagent& x) {
//?   cerr << x.to_string() << '\n'; //? 1
  for (long long int i = /*skip name:type*/1; i < SIZE(x.properties); ++i) {
    if (x.properties.at(i).first == "space")
      return !x.properties.at(i).second.empty() && x.properties.at(i).second.at(0) == "global";
  }
  return false;
}

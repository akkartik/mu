//: Spaces help isolate functions from each other. You can create them at will,
//: and all addresses in arguments are implicitly based on the 'default-space'
//: (unless they have the /raw property)

:(scenario set_default_space)
# if default-space is 10, and if an array of 5 locals lies from location 11 to 15 (inclusive),
# then location 0 is really location 11, location 1 is really location 12, and so on.
recipe main [
  10:number <- copy 5:literal  # pretend array; in practice we'll use new
  default-space:address:array:location <- copy 10:literal
  1:number <- copy 23:literal
]
+mem: storing 23 in location 12

:(scenario deref_sidesteps_default_space)
recipe main [
  # pretend pointer from outside
  3:number <- copy 34:literal
  # pretend array
  1000:number <- copy 5:literal
  # actual start of this function
  default-space:address:array:location <- copy 1000:literal
  1:address:number <- copy 3:literal
  8:number/raw <- copy 1:address:number/deref
]
+mem: storing 34 in location 8

:(before "End call Fields")
long long int default_space;
:(replace "call(recipe_number r) :running_recipe(r)")
call(recipe_number r) :running_recipe(r), running_step_index(0), next_ingredient_to_process(0), default_space(0) {}

:(replace "reagent r = x" following "reagent canonize(reagent x)")
reagent r = absolutize(x);
:(code)
reagent absolutize(reagent x) {
//?   if (Recipe_number.find("increment-counter") != Recipe_number.end()) //? 1
//?     cout << "AAA " << "increment-counter/2: " << Recipe[Recipe_number["increment-counter"]].steps.at(2).products.at(0).to_string() << '\n'; //? 1
//?   cout << "absolutize " << x.to_string() << '\n'; //? 4
//?   cout << is_raw(x) << '\n'; //? 1
  if (is_raw(x) || is_dummy(x)) return x;
//?   cout << "not raw: " << x.to_string() << '\n'; //? 1
  assert(x.initialized);
  reagent r = x;
  r.set_value(address(r.value, space_base(r)));
//?   cout << "after absolutize: " << r.value << '\n'; //? 1
  r.properties.push_back(pair<string, vector<string> >("raw", vector<string>()));
  assert(is_raw(r));
  return r;
}
:(before "return result" following "reagent deref(reagent x)")
result.properties.push_back(pair<string, vector<string> >("raw", vector<string>()));

//:: fix 'get'

:(scenario deref_sidesteps_default_space_in_get)
recipe main [
  # pretend pointer to container from outside
  12:number <- copy 34:literal
  13:number <- copy 35:literal
  # pretend array
  1000:number <- copy 5:literal
  # actual start of this function
  default-space:address:array:location <- copy 1000:literal
  1:address:point <- copy 12:literal
  9:number/raw <- get 1:address:point/deref, 1:offset
]
+mem: storing 35 in location 9

:(after "reagent tmp" following "case GET:")
tmp.properties.push_back(pair<string, vector<string> >("raw", vector<string>()));

//:: fix 'index'

:(scenario deref_sidesteps_default_space_in_index)
recipe main [
  # pretend pointer to array from outside
  12:number <- copy 2:literal
  13:number <- copy 34:literal
  14:number <- copy 35:literal
  # pretend array
  1000:number <- copy 5:literal
  # actual start of this function
  default-space:address:array:location <- copy 1000:literal
  1:address:array:number <- copy 12:literal
  9:number/raw <- index 1:address:array:number/deref, 1:literal
]
+mem: storing 35 in location 9

:(after "reagent tmp" following "case INDEX:")
tmp.properties.push_back(pair<string, vector<string> >("raw", vector<string>()));

//:: helpers

:(code)
long long int space_base(const reagent& x) {
  return Current_routine->calls.front().default_space;
}

long long int address(long long int offset, long long int base) {
  if (base == 0) return offset;  // raw
//?   cout << base << '\n'; //? 2
  if (offset >= static_cast<long long int>(Memory[base])) {
    // todo: test
    raise << "location " << offset << " is out of bounds " << Memory[base] << '\n';
  }
  return base+1 + offset;
}

:(after "void write_memory(reagent x, vector<double> data)")
  if (x.name == "default-space") {
    assert(scalar(data));
    Current_routine->calls.front().default_space = data.at(0);
//?     cout << "AAA " << Current_routine->calls.front().default_space << '\n'; //? 1
    return;
  }

:(scenario get_default_space)
recipe main [
  default-space:address:array:location <- copy 10:literal
  1:number/raw <- copy default-space:address:array:location
]
+mem: storing 10 in location 1

:(after "vector<double> read_memory(reagent x)")
  if (x.name == "default-space") {
    vector<double> result;
    result.push_back(Current_routine->calls.front().default_space);
    return result;
  }

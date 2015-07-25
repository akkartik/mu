//: A big convenience high-level languages provide is the ability to name memory
//: locations. In mu, a transform called 'transform_names' provides this
//: convenience.

:(scenario convert_names)
recipe main [
  x:number <- copy 0:literal
]
+name: assign x 1
+mem: storing 0 in location 1

:(scenario convert_names_warns)
% Hide_warnings = true;
recipe main [
  x:number <- copy y:number
]
+warn: use before set: y in main

:(after "int main")
  Transform.push_back(transform_names);

:(before "End Globals")
map<recipe_ordinal, map<string, long long int> > Name;
:(after "Clear Other State For recently_added_recipes")
for (long long int i = 0; i < SIZE(recently_added_recipes); ++i) {
  Name.erase(recently_added_recipes.at(i));
}

:(code)
void transform_names(const recipe_ordinal r) {
  bool names_used = false;
  bool numeric_locations_used = false;
  map<string, long long int>& names = Name[r];
  map<string, vector<type_ordinal> > metadata;
  // store the indices 'used' so far in the map
  long long int& curr_idx = names[""];
  ++curr_idx;  // avoid using index 0, benign skip in some other cases
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    instruction& inst = Recipe[r].steps.at(i);
    // Per-recipe Transforms
    // map names to addresses
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in) {
      check_metadata(metadata, inst.ingredients.at(in), r);
      if (is_numeric_location(inst.ingredients.at(in))) numeric_locations_used = true;
      if (is_named_location(inst.ingredients.at(in))) names_used = true;
      if (disqualified(inst.ingredients.at(in), inst)) continue;
      if (!already_transformed(inst.ingredients.at(in), names)) {
        raise << "use before set: " << inst.ingredients.at(in).name << " in " << Recipe[r].name << '\n' << end();
      }
      inst.ingredients.at(in).set_value(lookup_name(inst.ingredients.at(in), r));
    }
    for (long long int out = 0; out < SIZE(inst.products); ++out) {
      check_metadata(metadata, inst.products.at(out), r);
      if (is_numeric_location(inst.products.at(out))) numeric_locations_used = true;
      if (is_named_location(inst.products.at(out))) names_used = true;
      if (disqualified(inst.products.at(out), inst)) continue;
      if (names.find(inst.products.at(out).name) == names.end()) {
        trace("name") << "assign " << inst.products.at(out).name << " " << curr_idx << end();
        names[inst.products.at(out).name] = curr_idx;
        curr_idx += size_of(inst.products.at(out));
      }
      inst.products.at(out).set_value(lookup_name(inst.products.at(out), r));
    }
  }
  if (names_used && numeric_locations_used && r != Recipe_ordinal["interactive"])
    raise << "mixing variable names and numeric addresses in " << Recipe[r].name << '\n' << end();
}

void check_metadata(map<string, vector<type_ordinal> >& metadata, const reagent& x, const recipe_ordinal r) {
  if (is_literal(x)) return;
  if (is_raw(x)) return;
  // if you use raw locations you're probably doing something unsafe
  if (is_integer(x.name)) return;
  if (x.types.empty()) return;  // will throw a more precise warning elsewhere
  if (metadata.find(x.name) == metadata.end())
    metadata[x.name] = x.types;
  if (metadata[x.name] != x.types)
    raise << x.name << " used with multiple types in " << Recipe[r].name << '\n' << end();
}

bool disqualified(/*mutable*/ reagent& x, const instruction& inst) {
//?   cerr << x.to_string() << '\n'; //? 1
  if (x.types.empty()) {
    raise << "missing type in '" << inst.to_string() << "'\n" << end();
    return true;
  }
  if (is_raw(x)) return true;
  if (is_literal(x)) return true;
  if (is_integer(x.name)) return true;
  // End Disqualified Reagents
  if (x.initialized) return true;
  return false;
}

bool already_transformed(const reagent& r, const map<string, long long int>& names) {
  return names.find(r.name) != names.end();
}

long long int lookup_name(const reagent& r, const recipe_ordinal default_recipe) {
  return Name[default_recipe][r.name];
}

type_ordinal skip_addresses(const vector<type_ordinal>& types) {
  for (long long int i = 0; i < SIZE(types); ++i) {
    if (types.at(i) != Type_ordinal["address"]) return types.at(i);
  }
  raise << "expected a container" << '\n' << end();
  return -1;
}

int find_element_name(const type_ordinal t, const string& name) {
  const type_info& container = Type[t];
//?   cout << "looking for element " << name << " in type " << container.name << " with " << SIZE(container.element_names) << " elements\n"; //? 1
  for (long long int i = 0; i < SIZE(container.element_names); ++i) {
    if (container.element_names.at(i) == name) return i;
  }
  raise << "unknown element " << name << " in container " << Type[t].name << '\n' << end();
  return -1;
}

bool is_numeric_location(const reagent& x) {
  if (is_literal(x)) return false;
  if (is_raw(x)) return false;
  if (x.name == "0") return false;  // used for chaining lexical scopes
  return is_integer(x.name);
}

bool is_named_location(const reagent& x) {
  if (is_literal(x)) return false;
  if (is_raw(x)) return false;
  if (is_special_name(x.name)) return false;
  return !is_integer(x.name);
}

bool is_raw(const reagent& r) {
  for (long long int i = /*skip value+type*/1; i < SIZE(r.properties); ++i) {
    if (r.properties.at(i).first == "raw") return true;
  }
  return false;
}

bool is_special_name(const string& s) {
  if (s == "_") return true;
  if (s == "0") return true;
  // End is_special_name Cases
  return false;
}

:(scenario convert_names_passes_dummy)
# _ is just a dummy result that never gets consumed
recipe main [
  _, x:number <- copy 0:literal, 1:literal
]
+name: assign x 1
-name: assign _ 1

//: an escape hatch to suppress name conversion that we'll use later
:(scenario convert_names_passes_raw)
recipe main [
  x:number/raw <- copy 0:literal
]
-name: assign x 1

:(scenario convert_names_warns_when_mixing_names_and_numeric_locations)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1:number
]
+warn: mixing variable names and numeric addresses in main

:(scenario convert_names_warns_when_mixing_names_and_numeric_locations2)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1:literal
  1:number <- copy x:number
]
+warn: mixing variable names and numeric addresses in main

:(scenario convert_names_does_not_warn_when_mixing_names_and_raw_locations)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1:number/raw
]
-warn: mixing variable names and numeric addresses in main
$warn: 0

:(scenario convert_names_does_not_warn_when_mixing_names_and_literals)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1:literal
]
-warn: mixing variable names and numeric addresses in main
$warn: 0

:(scenario convert_names_warns_on_reusing_name_with_different_type)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1:literal
  x:boolean <- copy 1:literal
]
+warn: x used with multiple types in main

//:: Support element names for containers in 'get' and 'get-address'.

//: update our running example container for the next test
:(before "End Mu Types Initialization")
Type[point].element_names.push_back("x");
Type[point].element_names.push_back("y");
:(scenario convert_names_transforms_container_elements)
recipe main [
  p:address:point <- copy 0:literal  # unsafe
  a:number <- get p:address:point/deref, y:offset
  b:number <- get p:address:point/deref, x:offset
]
+name: element y of type point is at offset 1
+name: element x of type point is at offset 0

:(after "Per-recipe Transforms")
// replace element names of containers with offsets
if (inst.operation == Recipe_ordinal["get"]
    || inst.operation == Recipe_ordinal["get-address"]) {
  // at least 2 args, and second arg is offset
  assert(SIZE(inst.ingredients) >= 2);
//?   cout << inst.ingredients.at(1).to_string() << '\n'; //? 1
  if (!is_literal(inst.ingredients.at(1)))
    raise << Recipe[r].name << ": expected ingredient 1 of " << (inst.operation == Recipe_ordinal["get"] ? "'get'" : "'get-address'") << " to have type 'offset'; got " << inst.ingredients.at(1).original_string << '\n' << end();
  if (inst.ingredients.at(1).name.find_first_not_of("0123456789") != string::npos) {
    // since first non-address in base type must be a container, we don't have to canonize
    type_ordinal base_type = skip_addresses(inst.ingredients.at(0).types);
    inst.ingredients.at(1).set_value(find_element_name(base_type, inst.ingredients.at(1).name));
    trace("name") << "element " << inst.ingredients.at(1).name << " of type " << Type[base_type].name << " is at offset " << inst.ingredients.at(1).value << end();
  }
}

//: this test is actually illegal so can't call run
:(scenarios transform)
:(scenario convert_names_handles_containers)
recipe main [
  a:point <- copy 0:literal
  b:number <- copy 0:literal
]
+name: assign a 1
+name: assign b 3

//:: Support variant names for exclusive containers in 'maybe-convert'.

:(scenarios run)
:(scenario maybe_convert_named)
recipe main [
  12:number <- copy 1:literal
  13:number <- copy 35:literal
  14:number <- copy 36:literal
  20:address:point <- maybe-convert 12:number-or-point/raw, p:variant  # unsafe
]
+name: variant p of type number-or-point has tag 1
+mem: storing 13 in location 20

:(after "Per-recipe Transforms")
// convert variant names of exclusive containers
if (inst.operation == Recipe_ordinal["maybe-convert"]) {
  // at least 2 args, and second arg is offset
  assert(SIZE(inst.ingredients) >= 2);
  assert(is_literal(inst.ingredients.at(1)));
  if (inst.ingredients.at(1).name.find_first_not_of("0123456789") != string::npos) {
    // since first non-address in base type must be an exclusive container, we don't have to canonize
    type_ordinal base_type = skip_addresses(inst.ingredients.at(0).types);
    inst.ingredients.at(1).set_value(find_element_name(base_type, inst.ingredients.at(1).name));
    trace("name") << "variant " << inst.ingredients.at(1).name << " of type " << Type[base_type].name << " has tag " << inst.ingredients.at(1).value << end();
  }
}

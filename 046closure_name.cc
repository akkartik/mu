//: Writing to a literal (not computed) address of 0 in a recipe chains two
//: spaces together. When a variable has a property of /space:1, it looks up
//: the variable in the chained/surrounding space. /space:2 looks up the
//: surrounding space of the surrounding space, etc.

:(scenario closure)
recipe main [
  default-space:address:array:location <- new location:type, 30
  1:address:array:location/names:new-counter <- new-counter
  2:number/raw <- increment-counter 1:address:array:location/names:new-counter
  3:number/raw <- increment-counter 1:address:array:location/names:new-counter
]

recipe new-counter [
  default-space:address:array:location <- new location:type, 30
  x:number <- copy 23
  y:number <- copy 3  # variable that will be incremented
  reply default-space:address:array:location
]

recipe increment-counter [
  default-space:address:array:location <- new location:type, 30
  0:address:array:location/names:new-counter <- next-ingredient  # outer space must be created by 'new-counter' above
  y:number/space:1 <- add y:number/space:1, 1  # increment
  y:number <- copy 234  # dummy
  reply y:number/space:1
]

+name: recipe increment-counter is surrounded by new-counter
+mem: storing 5 in location 3

//: To make this work, compute the recipe that provides names for the
//: surrounding space of each recipe. This must happen before transform_names.

:(before "End Globals")
map<recipe_ordinal, recipe_ordinal> Surrounding_space;

:(after "int main")
  Transform.push_back(collect_surrounding_spaces);

:(code)
void collect_surrounding_spaces(const recipe_ordinal r) {
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    const instruction& inst = Recipe[r].steps.at(i);
    if (inst.is_label) continue;
    for (long long int j = 0; j < SIZE(inst.products); ++j) {
      if (is_literal(inst.products.at(j))) continue;
      if (inst.products.at(j).name != "0") continue;
      if (SIZE(inst.products.at(j).types) != 3
          || inst.products.at(j).types.at(0) != Type_ordinal["address"]
          || inst.products.at(j).types.at(1) != Type_ordinal["array"]
          || inst.products.at(j).types.at(2) != Type_ordinal["location"]) {
        raise_error << "slot 0 should always have type address:array:location, but is " << inst.products.at(j).to_string() << '\n' << end();
        continue;
      }
      vector<string> s = property(inst.products.at(j), "names");
      if (s.empty()) {
        raise_error << "slot 0 requires a /names property in recipe " << Recipe[r].name << end();
        continue;
      }
      if (SIZE(s) > 1) raise_error << "slot 0 should have a single value in /names, but got " << inst.products.at(j).to_string() << '\n' << end();
      string surrounding_recipe_name = s.at(0);
      if (Surrounding_space.find(r) != Surrounding_space.end()
          && Surrounding_space[r] != Recipe_ordinal[surrounding_recipe_name]) {
        raise_error << "recipe " << Recipe[r].name << " can have only one 'surrounding' recipe but has " << Recipe[Surrounding_space[r]].name << " and " << surrounding_recipe_name << '\n' << end();
        continue;
      }
      trace("name") << "recipe " << Recipe[r].name << " is surrounded by " << surrounding_recipe_name << end();
      Surrounding_space[r] = Recipe_ordinal[surrounding_recipe_name];
    }
  }
}

//: Once surrounding spaces are available, transform_names uses them to handle
//: /space properties.

:(replace{} "long long int lookup_name(const reagent& r, const recipe_ordinal default_recipe)")
long long int lookup_name(const reagent& x, const recipe_ordinal default_recipe) {
  if (!has_property(x, "space")) {
    if (Name[default_recipe].empty()) raise_error << "name not found: " << x.name << '\n' << end();
    return Name[default_recipe][x.name];
  }
  vector<string> p = property(x, "space");
  if (SIZE(p) != 1) raise_error << "/space property should have exactly one (non-negative integer) value\n" << end();
  long long int n = to_integer(p.at(0));
  assert(n >= 0);
  recipe_ordinal surrounding_recipe = lookup_surrounding_recipe(default_recipe, n);
  set<recipe_ordinal> done;
  vector<recipe_ordinal> path;
  return lookup_name(x, surrounding_recipe, done, path);
}

// If the recipe we need to lookup this name in doesn't have names done yet,
// recursively call transform_names on it.
long long int lookup_name(const reagent& x, const recipe_ordinal r, set<recipe_ordinal>& done, vector<recipe_ordinal>& path) {
  if (!Name[r].empty()) return Name[r][x.name];
  if (done.find(r) != done.end()) {
    raise_error << "can't compute address of " << x.to_string() << " because " << end();
    for (long long int i = 1; i < SIZE(path); ++i) {
      raise_error << path.at(i-1) << " requires computing names of " << path.at(i) << '\n' << end();
    }
    raise_error << path.at(SIZE(path)-1) << " requires computing names of " << r << "..ad infinitum\n" << end();
    return 0;
  }
  done.insert(r);
  path.push_back(r);
  transform_names(r);  // Not passing 'done' through. Might this somehow cause an infinite loop?
  assert(!Name[r].empty());
  return Name[r][x.name];
}

recipe_ordinal lookup_surrounding_recipe(const recipe_ordinal r, long long int n) {
  if (n == 0) return r;
  if (Surrounding_space.find(r) == Surrounding_space.end()) {
    raise_error << "don't know surrounding recipe of " << Recipe[r].name << '\n' << end();
    return 0;
  }
  assert(Surrounding_space[r]);
  return lookup_surrounding_recipe(Surrounding_space[r], n-1);
}

//: weaken use-before-set detection just a tad
:(replace{} "bool already_transformed(const reagent& r, const map<string, long long int>& names)")
bool already_transformed(const reagent& r, const map<string, long long int>& names) {
  if (has_property(r, "space")) {
    vector<string> p = property(r, "space");
    if (SIZE(p) != 1) {
      raise_error << "/space property should have exactly one (non-negative integer) value in " << r.original_string << '\n' << end();
      return false;
    }
    if (p.at(0) != "0") return true;
  }
  return names.find(r.name) != names.end();
}

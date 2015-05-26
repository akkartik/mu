//: Writing to a literal (not computed) address of 0 in a recipe chains two
//: spaces together. When a variable has a property of /space:1, it looks up
//: the variable in the chained/surrounding space. /space:2 looks up the
//: surrounding space of the surrounding space, etc.

:(scenario closure)
recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  1:address:array:location/names:init-counter <- init-counter
#?   $print [AAAAAAAAAAAAAAAA]
#?   $print 1:address:array:location
  2:number/raw <- increment-counter 1:address:array:location/names:init-counter
  3:number/raw <- increment-counter 1:address:array:location/names:init-counter
]

recipe init-counter [
  default-space:address:array:location <- new location:type, 30:literal
  x:number <- copy 23:literal
  y:number <- copy 3:literal  # variable that will be incremented
  reply default-space:address:array:location
]

recipe increment-counter [
  default-space:address:array:location <- new location:type, 30:literal
  0:address:array:location/names:init-counter <- next-ingredient  # outer space must be created by 'init-counter' above
  y:number/space:1 <- add y:number/space:1, 1:literal  # increment
  y:number <- copy 234:literal  # dummy
  reply y:number/space:1
]

+name: recipe increment-counter is surrounded by init-counter
+mem: storing 5 in location 3

//: To make this work, compute the recipe that provides names for the
//: surrounding space of each recipe. This must happen before transform_names.

:(before "End Globals")
map<recipe_number, recipe_number> Surrounding_space;

:(after "int main")
  Transform.push_back(collect_surrounding_spaces);

:(code)
void collect_surrounding_spaces(const recipe_number r) {
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    const instruction& inst = Recipe[r].steps.at(i);
    if (inst.is_label) continue;
    for (long long int j = 0; j < SIZE(inst.products); ++j) {
      if (isa_literal(inst.products.at(j))) continue;
      if (inst.products.at(j).name != "0") continue;
      if (SIZE(inst.products.at(j).types) != 3
          || inst.products.at(j).types.at(0) != Type_number["address"]
          || inst.products.at(j).types.at(1) != Type_number["array"]
          || inst.products.at(j).types.at(2) != Type_number["location"]) {
        raise << "slot 0 should always have type address:array:location, but is " << inst.products.at(j).to_string() << '\n';
        continue;
      }
      vector<string> s = property(inst.products.at(j), "names");
      if (s.empty())
        raise << "slot 0 requires a /names property in recipe " << Recipe[r].name << die();
      if (SIZE(s) > 1) raise << "slot 0 should have a single value in /names, got " << inst.products.at(j).to_string() << '\n';
      string surrounding_recipe_name = s.at(0);
      if (Surrounding_space.find(r) != Surrounding_space.end()
          && Surrounding_space[r] != Recipe_number[surrounding_recipe_name]) {
        raise << "recipe " << Recipe[r].name << " can have only one 'surrounding' recipe but has " << Recipe[Surrounding_space[r]].name << " and " << surrounding_recipe_name << '\n';
        continue;
      }
      trace("name") << "recipe " << Recipe[r].name << " is surrounded by " << surrounding_recipe_name;
      Surrounding_space[r] = Recipe_number[surrounding_recipe_name];
    }
  }
}

//: Once surrounding spaces are available, transform_names uses them to handle
//: /space properties.

:(replace{} "long long int lookup_name(const reagent& r, const recipe_number default_recipe)")
long long int lookup_name(const reagent& x, const recipe_number default_recipe) {
//?   cout << "AAA " << default_recipe << " " << Recipe[default_recipe].name << '\n'; //? 2
//?   cout << "AAA " << x.to_string() << '\n'; //? 1
  if (!has_property(x, "space")) {
    if (Name[default_recipe].empty()) raise << "name not found: " << x.name << '\n' << die();
    return Name[default_recipe][x.name];
  }
  vector<string> p = property(x, "space");
  if (SIZE(p) != 1) raise << "/space property should have exactly one (non-negative integer) value\n";
  long long int n = to_integer(p.at(0));
  assert(n >= 0);
  recipe_number surrounding_recipe = lookup_surrounding_recipe(default_recipe, n);
  set<recipe_number> done;
  vector<recipe_number> path;
  return lookup_name(x, surrounding_recipe, done, path);
}

// If the recipe we need to lookup this name in doesn't have names done yet,
// recursively call transform_names on it.
long long int lookup_name(const reagent& x, const recipe_number r, set<recipe_number>& done, vector<recipe_number>& path) {
  if (!Name[r].empty()) return Name[r][x.name];
  if (done.find(r) != done.end()) {
    raise << "can't compute address of " << x.to_string() << " because ";
    for (long long int i = 1; i < SIZE(path); ++i) {
      raise << path.at(i-1) << " requires computing names of " << path.at(i) << '\n';
    }
    raise << path.at(SIZE(path)-1) << " requires computing names of " << r << "..ad infinitum\n" << die();
    return 0;
  }
  done.insert(r);
  path.push_back(r);
  transform_names(r);  // Not passing 'done' through. Might this somehow cause an infinite loop?
  assert(!Name[r].empty());
  return Name[r][x.name];
}

recipe_number lookup_surrounding_recipe(const recipe_number r, long long int n) {
  if (n == 0) return r;
  if (Surrounding_space.find(r) == Surrounding_space.end()) {
    raise << "don't know surrounding recipe of " << Recipe[r].name << '\n';
    return 0;
  }
  assert(Surrounding_space[r]);
  return lookup_surrounding_recipe(Surrounding_space[r], n-1);
}

//: weaken use-before-set warnings just a tad
:(replace{} "bool already_transformed(const reagent& r, const map<string, long long int>& names)")
bool already_transformed(const reagent& r, const map<string, long long int>& names) {
  if (has_property(r, "space")) {
    vector<string> p = property(r, "space");
    assert(SIZE(p) == 1);
    if (p.at(0) != "0") return true;
  }
  return names.find(r.name) != names.end();
}

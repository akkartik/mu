//: Writing to a literal (not computed) address of 0 in a recipe chains two
//: spaces together. When a variable has a property of /space:1, it looks up
//: the variable in the chained/surrounding space. /space:2 looks up the
//: surrounding space of the surrounding space, etc.

:(scenario closure)
recipe main [
  default-space:address:shared:array:location <- new location:type, 30
  1:address:shared:array:location/names:new-counter <- new-counter
  2:number/raw <- increment-counter 1:address:shared:array:location/names:new-counter
  3:number/raw <- increment-counter 1:address:shared:array:location/names:new-counter
]

recipe new-counter [
  default-space:address:shared:array:location <- new location:type, 30
  x:number <- copy 23
  y:number <- copy 3  # variable that will be incremented
  reply default-space:address:shared:array:location
]

recipe increment-counter [
  default-space:address:shared:array:location <- new location:type, 30
  0:address:shared:array:location/names:new-counter <- next-ingredient  # outer space must be created by 'new-counter' above
  y:number/space:1 <- add y:number/space:1, 1  # increment
  y:number <- copy 234  # dummy
  reply y:number/space:1
]

+name: lexically surrounding space for recipe increment-counter comes from new-counter
+mem: storing 5 in location 3

//: To make this work, compute the recipe that provides names for the
//: surrounding space of each recipe.

:(before "End Globals")
map<recipe_ordinal, recipe_ordinal> Surrounding_space;

:(before "Transform.push_back(transform_names)")
Transform.push_back(collect_surrounding_spaces);  // idempotent

:(code)
void collect_surrounding_spaces(const recipe_ordinal r) {
  trace(9991, "transform") << "--- collect surrounding spaces for recipe " << get(Recipe, r).name << end();
//?   cerr << "--- collect surrounding spaces for recipe " << get(Recipe, r).name << '\n';
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    const instruction& inst = get(Recipe, r).steps.at(i);
    if (inst.is_label) continue;
    for (long long int j = 0; j < SIZE(inst.products); ++j) {
      if (is_literal(inst.products.at(j))) continue;
      if (inst.products.at(j).name != "0") continue;
      type_tree* type = inst.products.at(j).type;
      if (!type
          || type->value != get(Type_ordinal, "address")
          || !type->right
          || type->right->value != get(Type_ordinal, "shared")
          || !type->right->right
          || type->right->right->value != get(Type_ordinal, "array")
          || !type->right->right->right
          || type->right->right->right->value != get(Type_ordinal, "location")
          || type->right->right->right->right) {
        raise_error << "slot 0 should always have type address:shared:array:location, but is " << to_string(inst.products.at(j)) << '\n' << end();
        continue;
      }
      string_tree* s = property(inst.products.at(j), "names");
      if (!s) {
        raise_error << "slot 0 requires a /names property in recipe " << get(Recipe, r).name << end();
        continue;
      }
      if (s->right) raise_error << "slot 0 should have a single value in /names, but got " << to_string(inst.products.at(j)) << '\n' << end();
      const string& surrounding_recipe_name = s->value;
      if (surrounding_recipe_name.empty()) {
        raise_error << "slot 0 doesn't initialize its /names property in recipe " << get(Recipe, r).name << end();
        continue;
      }
      if (contains_key(Surrounding_space, r)
          && Surrounding_space[r] != get(Recipe_ordinal, surrounding_recipe_name)) {
        raise_error << "recipe " << get(Recipe, r).name << " can have only one 'surrounding' recipe but has " << get(Recipe, Surrounding_space[r]).name << " and " << surrounding_recipe_name << '\n' << end();
        continue;
      }
      trace(9993, "name") << "lexically surrounding space for recipe " << get(Recipe, r).name << " comes from " << surrounding_recipe_name << end();
//?       cerr << "lexically surrounding space for recipe " << get(Recipe, r).name << " comes from " << surrounding_recipe_name << '\n';
      if (!contains_key(Recipe_ordinal, surrounding_recipe_name)) {
        raise << "can't find recipe providing surrounding space for " << get(Recipe, r).name << ": " << surrounding_recipe_name << '\n' << end();
        continue;
      }
      Surrounding_space[r] = get(Recipe_ordinal, surrounding_recipe_name);
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
  string_tree* p = property(x, "space");
  if (!p || p->right) raise_error << "/space property should have exactly one (non-negative integer) value\n" << end();
  long long int n = to_integer(p->value);
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
  if (contains_key(done, r)) {
    raise_error << "can't compute address of " << to_string(x) << " because " << end();
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
  if (!contains_key(Surrounding_space, r)) {
    raise_error << "don't know surrounding recipe of " << get(Recipe, r).name << '\n' << end();
    return 0;
  }
  assert(Surrounding_space[r]);
  return lookup_surrounding_recipe(Surrounding_space[r], n-1);
}

//: weaken use-before-set detection just a tad
:(replace{} "bool already_transformed(const reagent& r, const map<string, long long int>& names)")
bool already_transformed(const reagent& r, const map<string, long long int>& names) {
  if (has_property(r, "space")) {
    string_tree* p = property(r, "space");
    if (!p || p->right) {
      raise_error << "/space property should have exactly one (non-negative integer) value in " << r.original_string << '\n' << end();
      return false;
    }
    if (p->value != "0") return true;
  }
  return contains_key(names, r.name);
}

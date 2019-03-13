//: Writing to a literal (not computed) address of 0 in a recipe chains two
//: spaces together. When a variable has a property of /space:1, it looks up
//: the variable in the chained/surrounding space. /space:2 looks up the
//: surrounding space of the surrounding space, etc.
//:
//: todo: warn on default-space abuse. default-space for one recipe should
//: never come from another, otherwise memory will be corrupted.

void test_closure() {
  run(
      "def main [\n"
      "  default-space:space <- new location:type, 30\n"
      "  2:space/names:new-counter <- new-counter\n"
      "  10:num/raw <- increment-counter 2:space/names:new-counter\n"
      "  11:num/raw <- increment-counter 2:space/names:new-counter\n"
      "]\n"
      "def new-counter [\n"
      "  default-space:space <- new location:type, 30\n"
      "  x:num <- copy 23\n"
      "  y:num <- copy 13\n"  // variable that will be incremented
      "  return default-space:space\n"
      "]\n"
      "def increment-counter [\n"
      "  default-space:space <- new location:type, 30\n"
      "  0:space/names:new-counter <- next-ingredient\n"  // outer space must be created by 'new-counter' above
      "  y:num/space:1 <- add y:num/space:1, 1\n"  // increment
      "  y:num <- copy 234\n"  // dummy
      "  return y:num/space:1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "name: lexically surrounding space for recipe increment-counter comes from new-counter\n"
      "mem: storing 15 in location 11\n"
  );
}

//: To make this work, compute the recipe that provides names for the
//: surrounding space of each recipe.

:(before "End Globals")
map<recipe_ordinal, recipe_ordinal> Surrounding_space;  // internal to transform; no need to snapshot
:(before "End Reset")
Surrounding_space.clear();

:(before "Begin Type Modifying Transforms")
Transform.push_back(collect_surrounding_spaces);  // idempotent

:(code)
void collect_surrounding_spaces(const recipe_ordinal r) {
  trace(101, "transform") << "--- collect surrounding spaces for recipe " << get(Recipe, r).name << end();
  for (int i = 0;  i < SIZE(get(Recipe, r).steps);  ++i) {
    const instruction& inst = get(Recipe, r).steps.at(i);
    if (inst.is_label) continue;
    for (int j = 0;  j < SIZE(inst.products);  ++j) {
      if (is_literal(inst.products.at(j))) continue;
      if (inst.products.at(j).name != "0") continue;
      if (!is_mu_space(inst.products.at(j))) {
        raise << "slot 0 should always have type address:array:location, but is '" << to_string(inst.products.at(j)) << "'\n" << end();
        continue;
      }
      string_tree* s = property(inst.products.at(j), "names");
      if (!s) {
        raise << "slot 0 requires a /names property in recipe '" << get(Recipe, r).name << "'\n" << end();
        continue;
      }
      if (!s->atom) raise << "slot 0 should have a single value in /names, but got '" << to_string(inst.products.at(j)) << "'\n" << end();
      const string& surrounding_recipe_name = s->value;
      if (surrounding_recipe_name.empty()) {
        raise << "slot 0 doesn't initialize its /names property in recipe '" << get(Recipe, r).name << "'\n" << end();
        continue;
      }
      if (contains_key(Surrounding_space, r)
          && get(Surrounding_space, r) != get(Recipe_ordinal, surrounding_recipe_name)) {
        raise << "recipe '" << get(Recipe, r).name << "' can have only one 'surrounding' recipe but has '" << get(Recipe, get(Surrounding_space, r)).name << "' and '" << surrounding_recipe_name << "'\n" << end();
        continue;
      }
      trace(103, "name") << "lexically surrounding space for recipe " << get(Recipe, r).name << " comes from " << surrounding_recipe_name << end();
      if (!contains_key(Recipe_ordinal, surrounding_recipe_name)) {
        raise << "can't find recipe providing surrounding space for '" << get(Recipe, r).name << "'; looking for '" << surrounding_recipe_name << "'\n" << end();
        continue;
      }
      put(Surrounding_space, r, get(Recipe_ordinal, surrounding_recipe_name));
    }
  }
}

//: Once surrounding spaces are available, transform_names uses them to handle
//: /space properties.

:(replace{} "int lookup_name(const reagent& r, const recipe_ordinal default_recipe)")
int lookup_name(const reagent& x, const recipe_ordinal default_recipe) {
  if (!has_property(x, "space")) {
    if (Name[default_recipe].empty()) raise << "name not found: " << x.name << '\n' << end();
    return Name[default_recipe][x.name];
  }
  string_tree* p = property(x, "space");
  if (!p || !p->atom) raise << "/space property should have exactly one (non-negative integer) value\n" << end();
  int n = to_integer(p->value);
  assert(n >= 0);
  recipe_ordinal surrounding_recipe = lookup_surrounding_recipe(default_recipe, n);
  if (surrounding_recipe == -1) return -1;
  set<recipe_ordinal> done;
  vector<recipe_ordinal> path;
  return lookup_name(x, surrounding_recipe, done, path);
}

// If the recipe we need to lookup this name in doesn't have names done yet,
// recursively call transform_names on it.
int lookup_name(const reagent& x, const recipe_ordinal r, set<recipe_ordinal>& done, vector<recipe_ordinal>& path) {
  if (!Name[r].empty()) return Name[r][x.name];
  if (contains_key(done, r)) {
    raise << "can't compute address of '" << to_string(x) << "' because\n" << end();
    for (int i = 1;  i < SIZE(path);  ++i) {
      raise << path.at(i-1) << " requires computing names of " << path.at(i) << '\n' << end();
    }
    raise << path.at(SIZE(path)-1) << " requires computing names of " << r << "..ad infinitum\n" << end();
    return -1;
  }
  done.insert(r);
  path.push_back(r);
  transform_names(r);  // Not passing 'done' through. Might this somehow cause an infinite loop?
  assert(!Name[r].empty());
  return Name[r][x.name];
}

recipe_ordinal lookup_surrounding_recipe(const recipe_ordinal r, int n) {
  if (n == 0) return r;
  if (!contains_key(Surrounding_space, r)) {
    raise << "don't know surrounding recipe of '" << get(Recipe, r).name << "'\n" << end();
    return -1;
  }
  assert(contains_key(Surrounding_space, r));
  return lookup_surrounding_recipe(get(Surrounding_space, r), n-1);
}

//: weaken use-before-set detection just a tad
:(replace{} "bool already_transformed(const reagent& r, const map<string, int>& names)")
bool already_transformed(const reagent& r, const map<string, int>& names) {
  if (has_property(r, "space")) {
    string_tree* p = property(r, "space");
    if (!p || !p->atom) {
      raise << "/space property should have exactly one (non-negative integer) value in '" << r.original_string << "'\n" << end();
      return false;
    }
    if (p->value != "0") return true;
  }
  return contains_key(names, r.name);
}

:(code)
void test_missing_surrounding_space() {
  Hide_errors = true;
  run(
      "def f [\n"
      "  local-scope\n"
      "  x:num/space:1 <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: don't know surrounding recipe of 'f'\n"
      "error: f: can't find a place to store 'x'\n"
  );
}

//: extra test for try_reclaim_locals() from previous layers
void test_local_scope_ignores_nonlocal_spaces() {
  run(
      "def new-scope [\n"
      "  local-scope\n"
      "  x:&:num <- new number:type\n"
      "  *x:&:num <- copy 34\n"
      "  return default-space:space\n"
      "]\n"
      "def use-scope [\n"
      "  local-scope\n"
      "  outer:space/names:new-scope <- next-ingredient\n"
      "  0:space/names:new-scope <- copy outer:space\n"
      "  return *x:&:num/space:1\n"
      "]\n"
      "def main [\n"
      "  1:space/raw <- new-scope\n"
      "  3:num/raw <- use-scope 1:space/raw\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 34 in location 3\n"
  );
}

void test_recursive_transform_names() {
  run(
      "def foo [\n"
      "  local-scope\n"
      "  x:num <- copy 0\n"
      "  return default-space:space/names:foo\n"
      "]\n"
      "def main [\n"
      "  local-scope\n"
      "  0:space/names:foo <- foo\n"
      "  x:num/space:1 <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

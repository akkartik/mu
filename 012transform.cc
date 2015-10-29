//: Phase 2: Filter loaded recipes through an extensible list of 'transforms'.
//:
//: The hope is that this framework of transform tools will provide a
//: deconstructed alternative to conventional compilers.

:(before "End recipe Fields")
long long int transformed_until;
:(before "End recipe Constructor")
transformed_until = -1;

:(before "End Types")
typedef void (*transform_fn)(recipe_ordinal);

:(before "End Globals")
vector<transform_fn> Transform;

:(code)
void transform_all() {
  trace(9990, "transform") << "=== transform_all()" << end();
  for (long long int t = 0; t < SIZE(Transform); ++t) {
//?     cerr << "transform " << t << '\n';
    for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
      recipe& r = p->second;
      if (r.steps.empty()) continue;
      if (r.transformed_until != t-1) continue;
//?       cerr << "  recipe " << r.name << '\n';
      (*Transform.at(t))(/*recipe_ordinal*/p->first);
      r.transformed_until = t;
    }
  }
  parse_int_reagents();  // do this after all other transforms have run
  // End Transform
}

void parse_int_reagents() {
  trace(9991, "transform") << "--- parsing any uninitialized reagents as integers" << end();
  for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
    recipe& r = p->second;
    if (r.steps.empty()) continue;
    for (long long int index = 0; index < SIZE(r.steps); ++index) {
      instruction& inst = r.steps.at(index);
      for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
        populate_value(inst.ingredients.at(i));
      }
      for (long long int i = 0; i < SIZE(inst.products); ++i) {
        populate_value(inst.products.at(i));
      }
    }
  }
}

void populate_value(reagent& r) {
  if (r.initialized) return;
  // End Reagent-parsing Exceptions
  if (!is_integer(r.name)) return;
  r.set_value(to_integer(r.name));
}

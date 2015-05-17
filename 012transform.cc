//: Phase 2: Filter loaded recipes through an extensible list of 'transforms'.
//:
//: The hope is that this framework of transform tools will provide a
//: deconstructed alternative to conventional compilers.

:(before "End recipe Fields")
long long int transformed_until;
  recipe() :transformed_until(-1) {}

:(before "End Types")
typedef void (*transform_fn)(recipe_number);

:(before "End Globals")
vector<transform_fn> Transform;

:(code)
void transform_all() {
//?   cout << "AAA transform_all\n"; //? 1
  for (long long int t = 0; t < SIZE(Transform); ++t) {
    for (map<recipe_number, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
      recipe& r = p->second;
      if (r.steps.empty()) continue;
      if (r.transformed_until != t-1) continue;
      (*Transform.at(t))(/*recipe_number*/p->first);
      r.transformed_until = t;
    }
  }
  parse_int_reagents();  // do this after all other transforms have run
}

void parse_int_reagents() {
//?   cout << "parse_int_reagents\n"; //? 1
  for (map<recipe_number, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
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
  if (!is_integer(r.name)) return;
  r.set_value(to_integer(r.name));
}

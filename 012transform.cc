//: Phase 2: Filter loaded recipes through an extensible list of 'transforms'.
//:
//: The hope is that this framework of transform tools will provide a
//: deconstructed alternative to conventional compilers.
//:
//: We're going to have many transforms in mu, and getting their order right
//: (not the same as ordering of layers) is a well-known problem. Some tips:
//:   a) Design each layer to rely on as few previous layers as possible.
//:
//:   b) When positioning transforms, try to find the tightest constraint in
//:   each transform relative to previous layers.
//:
//:   c) Even so you'll periodically need to try adjusting each transform
//:   relative to those in previous layers to find a better arrangement.

:(before "End recipe Fields")
int transformed_until;
:(before "End recipe Constructor")
transformed_until = -1;

:(before "End Types")
typedef void (*transform_fn)(recipe_ordinal);

:(before "End Globals")
vector<transform_fn> Transform;

:(after "int main")
  // Begin Transforms
    // Begin Instruction Inserting/Deleting Transforms
    // End Instruction Inserting/Deleting Transforms

    // Begin Instruction Modifying Transforms
    // End Instruction Modifying Transforms
  // End Transforms

  // Begin Checks
  // End Checks

:(code)
void transform_all() {
  trace(9990, "transform") << "=== transform_all()" << end();
//?   cerr << "=== transform_all\n";
  for (int t = 0; t < SIZE(Transform); ++t) {
//?     cerr << "transform " << t << '\n';
    for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
      recipe& r = p->second;
      if (r.steps.empty()) continue;
      if (r.transformed_until != t-1) continue;
      // End Transform Checks
      (*Transform.at(t))(/*recipe_ordinal*/p->first);
      r.transformed_until = t;
    }
  }
//?   cerr << "wrapping up transform\n";
  parse_int_reagents();  // do this after all other transforms have run
  // End transform_all
}

void parse_int_reagents() {
  trace(9991, "transform") << "--- parsing any uninitialized reagents as integers" << end();
  for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin(); p != Recipe.end(); ++p) {
    recipe& r = p->second;
    if (r.steps.empty()) continue;
    for (int index = 0; index < SIZE(r.steps); ++index) {
      instruction& inst = r.steps.at(index);
      for (int i = 0; i < SIZE(inst.ingredients); ++i) {
        populate_value(inst.ingredients.at(i));
      }
      for (int i = 0; i < SIZE(inst.products); ++i) {
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

// helper for tests -- temporarily suppress run
void transform(string form) {
  load(form);
  transform_all();
}

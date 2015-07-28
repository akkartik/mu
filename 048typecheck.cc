//: Some simple sanity checks for types, and also attempts to guess them where
//: they aren't provided.

:(scenario transform_types_warns_on_reusing_name_with_different_type)
% Hide_warnings = true;
recipe main [
  x:number <- copy 1
  x:boolean <- copy 1
]
+warn: x used with multiple types in main

:(after "int main")
  Transform.push_back(transform_types);

:(code)
void transform_types(const recipe_ordinal r) {
  map<string, vector<type_ordinal> > metadata;
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    instruction& inst = Recipe[r].steps.at(i);
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in) {
      check_metadata(metadata, inst.ingredients.at(in), r);
    }
    for (long long int out = 0; out < SIZE(inst.products); ++out) {
      check_metadata(metadata, inst.products.at(out), r);
    }
  }
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

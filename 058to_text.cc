//: Primitive to convert any type to text (array of characters).
//: Later layers will allow us to override this to do something smarter for
//: specific types.

:(before "End Mu Types Initialization")
put(Type_abbreviations, "text", new_type_tree("address:array:character"));

:(before "End Primitive Recipe Declarations")
TO_TEXT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "to-text", TO_TEXT);
:(before "End Primitive Recipe Checks")
case TO_TEXT: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'to-text' requires a single ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  // can handle any type
  break;
}
:(before "End Primitive Recipe Implementations")
case TO_TEXT: {
  products.resize(1);
  products.at(0).push_back(new_mu_string(print_mu(current_instruction().ingredients.at(0), ingredients.at(0))));
  break;
}

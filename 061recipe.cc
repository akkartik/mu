//: So far we've been calling a fixed recipe in each instruction, but we'd
//: also like to make the recipe a variable, pass recipes to "higher-order"
//: recipes, return recipes from recipes and so on.

:(before "End Mu Types Initialization")
// 'recipe' is a literal
put(Type_ordinal, "recipe", 0);
// 'recipe-ordinal' is the literal that can store recipe literals
type_ordinal recipe_ordinal = put(Type_ordinal, "recipe-ordinal", Next_type_ordinal++);
get_or_insert(Type, recipe_ordinal).name = "recipe-ordinal";

:(before "End Reagent-parsing Exceptions")
if (r.properties.at(0).second && r.properties.at(0).second->value == "recipe") {
  r.set_value(get(Recipe_ordinal, r.name));
  return;
}

:(code)
bool is_mu_recipe(reagent r) {
  if (!r.type) return false;
  if (r.type->value == get(Type_ordinal, "recipe")) return true;
  if (r.type->value == get(Type_ordinal, "recipe-ordinal")) return true;
  // End is_mu_recipe Cases
  return false;
}

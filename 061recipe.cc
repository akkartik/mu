//: So far we've been calling a fixed recipe in each instruction, but we'd
//: also like to make the recipe a variable, pass recipes to "higher-order"
//: recipes, return recipes from recipes and so on.

:(before "End Mu Types Initialization")
put(Type_ordinal, "recipe-literal", 0);
// 'recipe' variables can store recipe-literal
type_ordinal recipe = put(Type_ordinal, "recipe", Next_type_ordinal++);
get_or_insert(Type, recipe).name = "recipe";

:(before "End transform_names Exceptions")
if (!x.properties.at(0).second && contains_key(Recipe_ordinal, x.name)) {
  x.properties.at(0).second = new string_tree("recipe-literal");
  x.type = new type_tree(get(Type_ordinal, "recipe-literal"));
  x.set_value(get(Recipe_ordinal, x.name));
  return true;
}

:(code)
bool is_mu_recipe(reagent r) {
  if (!r.type) return false;
  if (r.properties.at(0).second->value == "recipe") return true;
  if (r.properties.at(0).second->value == "recipe-literal") return true;
  // End is_mu_recipe Cases
  return false;
}

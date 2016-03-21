//: Calls can take ingredients just like primitives. To access a recipe's
//: ingredients, use 'next-ingredient'.

:(scenario next_ingredient)
def main [
  f 2
]
def f [
  12:number <- next-ingredient
  13:number <- add 1, 12:number
]
+mem: storing 3 in location 13

:(scenario next_ingredient_missing)
def main [
  f
]
def f [
  _, 12:number <- next-ingredient
]
+mem: storing 0 in location 12

:(before "End call Fields")
vector<vector<double> > ingredient_atoms;
vector<reagent> ingredients;
int next_ingredient_to_process;
:(before "End call Constructor")
next_ingredient_to_process = 0;

:(before "End Call Housekeeping")
for (int i = 0; i < SIZE(ingredients); ++i) {
  current_call().ingredient_atoms.push_back(ingredients.at(i));
  reagent ingredient = call_instruction.ingredients.at(i);
  canonize_type(ingredient);
  current_call().ingredients.push_back(ingredient);
}

:(before "End Primitive Recipe Declarations")
NEXT_INGREDIENT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "next-ingredient", NEXT_INGREDIENT);
:(before "End Primitive Recipe Checks")
case NEXT_INGREDIENT: {
  if (!inst.ingredients.empty()) {
    raise << maybe(get(Recipe, r).name) << "'next-ingredient' didn't expect any ingredients in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case NEXT_INGREDIENT: {
  assert(!Current_routine->calls.empty());
  if (current_call().next_ingredient_to_process < SIZE(current_call().ingredient_atoms)) {
    reagent product = current_instruction().products.at(0);
    canonize_type(product);
    if (current_recipe_name() == "main") {
      // no ingredient types since the call might be implicit; assume ingredients are always strings
      // todo: how to test this?
      if (!is_mu_string(product))
        raise << "main: wrong type for ingredient " << product.original_string << '\n' << end();
    }
    else if (!types_coercible(product,
                              current_call().ingredients.at(current_call().next_ingredient_to_process))) {
      raise << maybe(current_recipe_name()) << "wrong type for ingredient " << product.original_string << '\n' << end();
      // End next-ingredient Type Mismatch Error
    }
    products.push_back(
        current_call().ingredient_atoms.at(current_call().next_ingredient_to_process));
    assert(SIZE(products) == 1);  products.resize(2);  // push a new vector
    products.at(1).push_back(1);
    ++current_call().next_ingredient_to_process;
  }
  else {
    if (SIZE(current_instruction().products) < 2)
      raise << maybe(current_recipe_name()) << "no ingredient to save in " << current_instruction().products.at(0).original_string << '\n' << end();
    if (current_instruction().products.empty()) break;
    products.resize(2);
    // pad the first product with sufficient zeros to match its type
    int size = size_of(current_instruction().products.at(0));
    for (int i = 0; i < size; ++i)
      products.at(0).push_back(0);
    products.at(1).push_back(0);
  }
  break;
}

:(scenario next_ingredient_fail_on_missing)
% Hide_errors = true;
def main [
  f
]
def f [
  11:number <- next-ingredient
]
+error: f: no ingredient to save in 11:number

:(scenario rewind_ingredients)
def main [
  f 2
]
def f [
  12:number <- next-ingredient  # consume ingredient
  _, 1:boolean <- next-ingredient  # will not find any ingredients
  rewind-ingredients
  13:number, 2:boolean <- next-ingredient  # will find ingredient again
]
+mem: storing 2 in location 12
+mem: storing 0 in location 1
+mem: storing 2 in location 13
+mem: storing 1 in location 2

:(before "End Primitive Recipe Declarations")
REWIND_INGREDIENTS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "rewind-ingredients", REWIND_INGREDIENTS);
:(before "End Primitive Recipe Checks")
case REWIND_INGREDIENTS: {
  break;
}
:(before "End Primitive Recipe Implementations")
case REWIND_INGREDIENTS: {
  current_call().next_ingredient_to_process = 0;
  break;
}

:(scenario ingredient)
def main [
  f 1, 2
]
def f [
  12:number <- ingredient 1  # consume second ingredient first
  13:number, 1:boolean <- next-ingredient  # next-ingredient tries to scan past that
]
+mem: storing 2 in location 12
+mem: storing 0 in location 1

:(before "End Primitive Recipe Declarations")
INGREDIENT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "ingredient", INGREDIENT);
:(before "End Primitive Recipe Checks")
case INGREDIENT: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'ingredient' expects exactly one ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(0)) && !is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'ingredient' expects a literal ingredient, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case INGREDIENT: {
  if (static_cast<int>(ingredients.at(0).at(0)) < SIZE(current_call().ingredient_atoms)) {
    current_call().next_ingredient_to_process = ingredients.at(0).at(0);
    products.push_back(
        current_call().ingredient_atoms.at(current_call().next_ingredient_to_process));
    assert(SIZE(products) == 1);  products.resize(2);  // push a new vector
    products.at(1).push_back(1);
    ++current_call().next_ingredient_to_process;
  }
  else {
    if (SIZE(current_instruction().products) > 1) {
      products.resize(2);
      products.at(0).push_back(0);  // todo: will fail noisily if we try to read a compound value
      products.at(1).push_back(0);
    }
  }
  break;
}

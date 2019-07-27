//: Calls can take ingredients just like primitives. To access a recipe's
//: ingredients, use 'next-ingredient'.

void test_next_ingredient() {
  run(
      "def main [\n"
      "  f 2\n"
      "]\n"
      "def f [\n"
      "  12:num <- next-ingredient\n"
      "  13:num <- add 1, 12:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 3 in location 13\n"
  );
}

void test_next_ingredient_missing() {
  run(
      "def main [\n"
      "  f\n"
      "]\n"
      "def f [\n"
      "  _, 12:num <- next-ingredient\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 12\n"
  );
}

:(before "End call Fields")
vector<vector<double> > ingredient_atoms;
vector<reagent> ingredients;
int next_ingredient_to_process;
:(before "End call Constructor")
next_ingredient_to_process = 0;

:(before "End Call Housekeeping")
for (int i = 0;  i < SIZE(ingredients);  ++i) {
  current_call().ingredient_atoms.push_back(ingredients.at(i));
  reagent/*copy*/ ingredient = call_instruction.ingredients.at(i);
  // End Compute Call Ingredient
  current_call().ingredients.push_back(ingredient);
  // End Populate Call Ingredient
}

:(before "End Primitive Recipe Declarations")
NEXT_INGREDIENT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "next-ingredient", NEXT_INGREDIENT);
put(Recipe_ordinal, "next-input", NEXT_INGREDIENT);
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
    reagent/*copy*/ product = current_instruction().products.at(0);
    // End Preprocess NEXT_INGREDIENT product
    if (current_recipe_name() == "main") {
      // no ingredient types since the call might be implicit; assume ingredients are always strings
      // todo: how to test this?
      if (!is_mu_text(product))
        raise << "main: wrong type for ingredient '" << product.original_string << "'\n" << end();
    }
    else if (!types_coercible(product,
                              current_call().ingredients.at(current_call().next_ingredient_to_process))) {
      raise << maybe(current_recipe_name()) << "wrong type for ingredient '" << product.original_string << "': " << current_call().ingredients.at(current_call().next_ingredient_to_process).original_string << '\n' << end();
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
      raise << maybe(current_recipe_name()) << "no ingredient to save in '" << current_instruction().products.at(0).original_string << "'\n" << end();
    if (current_instruction().products.empty()) break;
    products.resize(2);
    // pad the first product with sufficient zeros to match its type
    products.at(0).resize(size_of(current_instruction().products.at(0)));
    products.at(1).push_back(0);
  }
  break;
}

:(code)
void test_next_ingredient_fail_on_missing() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  f\n"
      "]\n"
      "def f [\n"
      "  11:num <- next-ingredient\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: f: no ingredient to save in '11:num'\n"
  );
}

void test_rewind_ingredients() {
  run(
      "def main [\n"
      "  f 2\n"
      "]\n"
      "def f [\n"
      "  12:num <- next-ingredient\n"  // consume ingredient
      "  _, 1:bool <- next-ingredient\n"  // will not find any ingredients
      "  rewind-ingredients\n"
      "  13:num, 2:bool <- next-ingredient\n"  // will find ingredient again
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 2 in location 12\n"
      "mem: storing 0 in location 1\n"
      "mem: storing 2 in location 13\n"
      "mem: storing 1 in location 2\n"
  );
}

:(before "End Primitive Recipe Declarations")
REWIND_INGREDIENTS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "rewind-ingredients", REWIND_INGREDIENTS);
put(Recipe_ordinal, "rewind-inputs", REWIND_INGREDIENTS);
:(before "End Primitive Recipe Checks")
case REWIND_INGREDIENTS: {
  break;
}
:(before "End Primitive Recipe Implementations")
case REWIND_INGREDIENTS: {
  current_call().next_ingredient_to_process = 0;
  break;
}

//: another primitive: 'ingredient' for random access

:(code)
void test_ingredient() {
  run(
      "def main [\n"
      "  f 1, 2\n"
      "]\n"
      "def f [\n"
      "  12:num <- ingredient 1\n"  // consume second ingredient first
      "  13:num, 1:bool <- next-ingredient\n"  // next-ingredient tries to scan past that
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 2 in location 12\n"
      "mem: storing 0 in location 1\n"
  );
}

:(before "End Primitive Recipe Declarations")
INGREDIENT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "ingredient", INGREDIENT);
put(Recipe_ordinal, "input", INGREDIENT);
:(before "End Primitive Recipe Checks")
case INGREDIENT: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'ingredient' expects exactly one ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(0)) && !is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'ingredient' expects a literal ingredient, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
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

//: a particularly common array type is the text, or address:array:character
:(code)
bool is_mu_text(reagent/*copy*/ x) {
  // End Preprocess is_mu_text(reagent x)
  return x.type
      && !x.type->atom
      && x.type->left->atom
      && x.type->left->value == Address_type_ordinal
      && x.type->right
      && !x.type->right->atom
      && x.type->right->left->atom
      && x.type->right->left->value == Array_type_ordinal
      && x.type->right->right
      && !x.type->right->right->atom
      && x.type->right->right->left->value == Character_type_ordinal
      && x.type->right->right->right == NULL;
}

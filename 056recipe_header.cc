//: Advanced notation for the common/easy case where a recipe takes some fixed
//: number of ingredients and yields some fixed number of products.

:(scenario recipe_with_header)
recipe main [
  1:number/raw <- add2 3, 5
]
recipe add2 x:number, y:number -> z:number [
  local-scope
  load-ingredients
  z:number <- add x, y
  reply z
]
+mem: storing 8 in location 1

//: When loading recipes save any header.

:(before "End recipe Fields")
bool has_header;
vector<reagent> ingredients;
vector<reagent> products;
:(before "End recipe Constructor")
has_header = false;

:(before "End recipe Refinements")
if (in.peek() != '[') {
  trace(9999, "parse") << "recipe has a header; parsing" << end();
  load_recipe_header(in, result);
}

:(code)
void load_recipe_header(istream& in, recipe& result) {
  result.has_header = true;
  while (has_data(in) && in.peek() != '[' && in.peek() != '\n') {
    string s = next_word(in);
    if (s == "->") break;
    result.ingredients.push_back(reagent(s));
    trace(9999, "parse") << "header ingredient: " << result.ingredients.back().original_string << end();
    skip_whitespace_but_not_newline(in);
  }
  while (has_data(in) && in.peek() != '[' && in.peek() != '\n') {
    string s = next_word(in);
    result.products.push_back(reagent(s));
    trace(9999, "parse") << "header product: " << result.products.back().original_string << end();
    skip_whitespace_but_not_newline(in);
  }
  // End Load Recipe Header(result)
}

:(scenario recipe_handles_stray_comma)
recipe main [
  1:number/raw <- add2 3, 5
]
recipe add2 x:number, y:number -> z:number, [
  local-scope
  load-ingredients
  z:number <- add x, y
  reply z
]
+mem: storing 8 in location 1

:(scenario recipe_handles_stray_comma_2)
recipe main [
  foo
]
recipe foo, [
  1:number/raw <- add 2, 2
]
recipe bar [
  1:number/raw <- add 2, 3
]
+mem: storing 4 in location 1

:(scenario recipe_handles_missing_bracket)
% Hide_errors = true;
recipe main
]
+error: recipe body must begin with '['

:(scenario recipe_handles_missing_bracket_2)
% Hide_errors = true;
recipe main
  local-scope
  {
  }
]
# doesn't overflow line when reading header
-parse: header ingredient: local-scope
+error: recipe body must begin with '['

:(scenario recipe_handles_missing_bracket_3)
% Hide_errors = true;
recipe main  # comment
  local-scope
  {
  }
]
# doesn't overflow line when reading header
-parse: header ingredient: local-scope
+error: recipe body must begin with '['

:(after "Begin debug_string(recipe x)")
out << "ingredients:\n";
for (long long int i = 0; i < SIZE(x.ingredients); ++i)
  out << "  " << debug_string(x.ingredients.at(i)) << '\n';
out << "products:\n";
for (long long int i = 0; i < SIZE(x.products); ++i)
  out << "  " << debug_string(x.products.at(i)) << '\n';

//: If a recipe never mentions any ingredients or products, assume it has a header.

:(scenario recipe_without_ingredients_or_products_has_header)
recipe test [
  1:number <- copy 34
]
+parse: recipe test has a header

:(before "End recipe Body(result)")
if (!result.has_header) {
  result.has_header = true;
  for (long long int i = 0; i < SIZE(result.steps); ++i) {
    const instruction& inst = result.steps.at(i);
    if ((inst.name == "reply" && !inst.ingredients.empty())
        || inst.name == "next-ingredient"
        || inst.name == "ingredient"
        || inst.name == "rewind-ingredients") {
      result.has_header = false;
      break;
    }
  }
}
if (result.has_header) {
  trace(9999, "parse") << "recipe " << result.name << " has a header" << end();
}

//: Rewrite 'load-ingredients' to instructions to create all reagents in the header.

:(before "End Rewrite Instruction(curr, recipe result)")
if (curr.name == "load-ingredients") {
  curr.clear();
  for (long long int i = 0; i < SIZE(result.ingredients); ++i) {
    curr.operation = get(Recipe_ordinal, "next-ingredient");
    curr.name = "next-ingredient";
    curr.products.push_back(result.ingredients.at(i));
    result.steps.push_back(curr);
    curr.clear();
  }
}

//:: Check types going in and out of all recipes with headers.

:(scenarios transform)
:(scenario recipe_headers_are_checked)
% Hide_errors = true;
recipe add2 x:number, y:number -> z:number [
  local-scope
  load-ingredients
  z:address:number <- copy 0/unsafe
  reply z
]
+error: add2: replied with the wrong type at 'reply z'

:(before "End Checks")
Transform.push_back(check_reply_instructions_against_header);  // idempotent

:(code)
void check_reply_instructions_against_header(const recipe_ordinal r) {
  const recipe& caller_recipe = get(Recipe, r);
  if (caller_recipe.products.empty()) return;
  trace(9991, "transform") << "--- checking reply instructions against header for " << caller_recipe.name << end();
//?   cerr << "--- checking reply instructions against header for " << caller_recipe.name << '\n';
  for (long long int i = 0; i < SIZE(caller_recipe.steps); ++i) {
    const instruction& inst = caller_recipe.steps.at(i);
    if (inst.name != "reply") continue;
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
      if (!types_match(caller_recipe.products.at(i), inst.ingredients.at(i)))
        raise_error << maybe(caller_recipe.name) << "replied with the wrong type at '" << inst.to_string() << "'\n" << end();
    }
  }
}

:(scenario recipe_headers_check_for_duplicate_names)
% Hide_errors = true;
recipe add2 x:number, x:number -> z:number [
  local-scope
  load-ingredients
  reply z
]
+error: add2: x can't repeat in the ingredients

:(before "End recipe Fields")
map<string, int> ingredient_index;

:(after "Begin Instruction Modifying Transforms")
Transform.push_back(check_header_ingredients);  // idempotent

:(code)
void check_header_ingredients(const recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  if (caller_recipe.products.empty()) return;
  trace(9991, "transform") << "--- checking reply instructions against header for " << caller_recipe.name << end();
  for (long long int i = 0; i < SIZE(caller_recipe.ingredients); ++i) {
    if (contains_key(caller_recipe.ingredient_index, caller_recipe.ingredients.at(i).name))
      raise_error << maybe(caller_recipe.name) << caller_recipe.ingredients.at(i).name << " can't repeat in the ingredients\n" << end();
    put(caller_recipe.ingredient_index, caller_recipe.ingredients.at(i).name, i);
  }
}

//: Deduce types from the header if possible.

:(scenarios run)
:(scenario deduce_instruction_types_from_recipe_header)
recipe main [
  1:number/raw <- add2 3, 5
]
recipe add2 x:number, y:number -> z:number [
  local-scope
  load-ingredients
  z <- add x, y  # no type for z
  reply z
]
+mem: storing 8 in location 1

:(after "Begin Type Modifying Transforms")
Transform.push_back(deduce_types_from_header);  // idempotent

:(code)
void deduce_types_from_header(const recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  if (caller_recipe.products.empty()) return;
  trace(9991, "transform") << "--- deduce types from header for " << caller_recipe.name << end();
//?   cerr << "--- deduce types from header for " << caller_recipe.name << '\n';
  map<string, const type_tree*> header_type;
  map<string, const string_tree*> header_type_name;
  for (long long int i = 0; i < SIZE(caller_recipe.ingredients); ++i) {
    put(header_type, caller_recipe.ingredients.at(i).name, caller_recipe.ingredients.at(i).type);
    put(header_type_name, caller_recipe.ingredients.at(i).name, caller_recipe.ingredients.at(i).properties.at(0).second);
    trace(9993, "transform") << "type of " << caller_recipe.ingredients.at(i).name << " is " << debug_string(caller_recipe.ingredients.at(i).type) << end();
  }
  for (long long int i = 0; i < SIZE(caller_recipe.products); ++i) {
    put(header_type, caller_recipe.products.at(i).name, caller_recipe.products.at(i).type);
    put(header_type_name, caller_recipe.products.at(i).name, caller_recipe.products.at(i).properties.at(0).second);
    trace(9993, "transform") << "type of " << caller_recipe.products.at(i).name << " is " << debug_string(caller_recipe.products.at(i).type) << end();
  }
  for (long long int i = 0; i < SIZE(caller_recipe.steps); ++i) {
    instruction& inst = caller_recipe.steps.at(i);
    trace(9992, "transform") << "instruction: " << inst.to_string() << end();
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
      if (inst.ingredients.at(i).type) continue;
      if (header_type.find(inst.ingredients.at(i).name) == header_type.end()) {
        raise << maybe(caller_recipe.name) << "unknown variable " << inst.ingredients.at(i).name << " in '" << inst.to_string() << "'\n" << end();
        continue;
      }
      if (!inst.ingredients.at(i).type)
        inst.ingredients.at(i).type = new type_tree(*get(header_type, inst.ingredients.at(i).name));
      if (!inst.ingredients.at(i).properties.at(0).second)
        inst.ingredients.at(i).properties.at(0).second = new string_tree(*get(header_type_name, inst.ingredients.at(i).name));
      trace(9993, "transform") << "type of " << inst.ingredients.at(i).name << " is " << debug_string(inst.ingredients.at(i).type) << end();
    }
    for (long long int i = 0; i < SIZE(inst.products); ++i) {
      trace(9993, "transform") << "  product: " << debug_string(inst.products.at(i)) << end();
      if (inst.products.at(i).type) continue;
      if (header_type.find(inst.products.at(i).name) == header_type.end()) {
        raise << maybe(caller_recipe.name) << "unknown variable " << inst.products.at(i).name << " in '" << inst.to_string() << "'\n" << end();
        continue;
      }
      if (!inst.products.at(i).type)
        inst.products.at(i).type = new type_tree(*get(header_type, inst.products.at(i).name));
      if (!inst.products.at(i).properties.at(0).second)
        inst.products.at(i).properties.at(0).second = new string_tree(*get(header_type_name, inst.products.at(i).name));
      trace(9993, "transform") << "type of " << inst.products.at(i).name << " is " << debug_string(inst.products.at(i).type) << end();
    }
  }
}

//: One final convenience: no need to say what to return if the information is
//: in the header.

:(scenario reply_based_on_header)
recipe main [
  1:number/raw <- add2 3, 5
]
recipe add2 x:number, y:number -> z:number [
  local-scope
  load-ingredients
  z <- add x, y
  reply
]
+mem: storing 8 in location 1

:(after "Transform.push_back(check_header_ingredients)")
Transform.push_back(fill_in_reply_ingredients);  // idempotent

:(code)
void fill_in_reply_ingredients(recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  if (!caller_recipe.has_header) return;
  trace(9991, "transform") << "--- fill in reply ingredients from header for recipe " << caller_recipe.name << end();
  for (long long int i = 0; i < SIZE(caller_recipe.steps); ++i) {
    instruction& inst = caller_recipe.steps.at(i);
    if (inst.name == "reply" && inst.ingredients.empty())
      add_header_products(inst, caller_recipe);
  }
  // fall through reply
  if (caller_recipe.steps.at(SIZE(caller_recipe.steps)-1).name != "reply") {
    instruction inst;
    inst.name = "reply";
    add_header_products(inst, caller_recipe);
    caller_recipe.steps.push_back(inst);
  }
}

void add_header_products(instruction& inst, const recipe& caller_recipe) {
  assert(inst.name == "reply");
  // collect any products with the same names as ingredients
  for (long long int i = 0; i < SIZE(caller_recipe.products); ++i) {
    // if the ingredient is missing, add it from the header
    if (SIZE(inst.ingredients) == i)
      inst.ingredients.push_back(caller_recipe.products.at(i));
    // if it's missing /same_as_ingredient, try to fill it in
    if (contains_key(caller_recipe.ingredient_index, caller_recipe.products.at(i).name) && !has_property(inst.ingredients.at(i), "same_as_ingredient")) {
      ostringstream same_as_ingredient;
      same_as_ingredient << get(caller_recipe.ingredient_index, caller_recipe.products.at(i).name);
      inst.ingredients.at(i).properties.push_back(pair<string, string_tree*>("same-as-ingredient", new string_tree(same_as_ingredient.str())));
    }
  }
}

:(scenario explicit_reply_ignores_header)
recipe main [
  1:number/raw, 2:number/raw <- add2 3, 5
]
recipe add2 a:number, b:number -> y:number, z:number [
  local-scope
  load-ingredients
  y <- add a, b
  z <- subtract a, b
  reply a, z
]
+mem: storing 3 in location 1
+mem: storing -2 in location 2

:(scenario reply_on_fallthrough_based_on_header)
recipe main [
  1:number/raw <- add2 3, 5
]
recipe add2 x:number, y:number -> z:number [
  local-scope
  load-ingredients
  z <- add x, y
]
+transform: instruction: reply z:number
+mem: storing 8 in location 1

:(scenario reply_on_fallthrough_already_exists)
recipe main [
  1:number/raw <- add2 3, 5
]
recipe add2 x:number, y:number -> z:number [
  local-scope
  load-ingredients
  z <- add x, y  # no type for z
  reply z
]
+transform: instruction: reply z
-transform: instruction: reply z:number
+mem: storing 8 in location 1

:(scenario recipe_headers_perform_same_ingredient_check)
% Hide_errors = true;
recipe main [
  1:number <- copy 34
  2:number <- copy 34
  3:number <- add2 1:number, 2:number
]
recipe add2 x:number, y:number -> x:number [
  local-scope
  load-ingredients
]
+error: main: '3:number <- add2 1:number, 2:number' should write to 1:number rather than 3:number

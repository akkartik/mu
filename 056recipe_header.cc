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

:(before "End Recipe Refinements")
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

:(before "End Recipe Body(result)")
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
  recipe_ordinal op = get(Recipe_ordinal, "next-ingredient-without-typechecking");
  for (long long int i = 0; i < SIZE(result.ingredients); ++i) {
    curr.operation = op;
    curr.name = "next-ingredient-without-typechecking";
    curr.products.push_back(result.ingredients.at(i));
    result.steps.push_back(curr);
    curr.clear();
  }
}

//: internal version of next-ingredient; don't call this directly
:(before "End Primitive Recipe Declarations")
NEXT_INGREDIENT_WITHOUT_TYPECHECKING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "next-ingredient-without-typechecking", NEXT_INGREDIENT_WITHOUT_TYPECHECKING);
:(before "End Primitive Recipe Checks")
case NEXT_INGREDIENT_WITHOUT_TYPECHECKING: {
  break;
}
:(before "End Primitive Recipe Implementations")
case NEXT_INGREDIENT_WITHOUT_TYPECHECKING: {
  assert(!Current_routine->calls.empty());
  if (current_call().next_ingredient_to_process < SIZE(current_call().ingredient_atoms)) {
    products.push_back(
        current_call().ingredient_atoms.at(current_call().next_ingredient_to_process));
    assert(SIZE(products) == 1);  products.resize(2);  // push a new vector
    products.at(1).push_back(1);
    ++current_call().next_ingredient_to_process;
  }
  else {
    products.resize(2);
    // pad the first product with sufficient zeros to match its type
    long long int size = size_of(current_instruction().products.at(0));
    for (long long int i = 0; i < size; ++i)
      products.at(0).push_back(0);
    products.at(1).push_back(0);
  }
  break;
}

//:: Check all calls against headers.

:(scenario show_clear_error_on_bad_call)
% Hide_errors = true;
recipe main [
  1:number <- foo 34
]
recipe foo x:boolean -> y:number [
  local-scope
  load-ingredients
  reply 35
]
+error: main: ingredient 0 has the wrong type at '1:number <- foo 34'

:(scenario show_clear_error_on_bad_call_2)
% Hide_errors = true;
recipe main [
  1:boolean <- foo 34
]
recipe foo x:number -> y:number [
  local-scope
  load-ingredients
  reply x
]
+error: main: product 0 has the wrong type at '1:boolean <- foo 34'

:(after "Transform.push_back(check_instruction)")
Transform.push_back(check_calls_against_header);  // idempotent
:(code)
void check_calls_against_header(const recipe_ordinal r) {
  trace(9991, "transform") << "--- type-check calls inside recipe " << get(Recipe, r).name << end();
  const recipe& caller = get(Recipe, r);
  for (long long int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    if (inst.operation < MAX_PRIMITIVE_RECIPES) continue;
    const recipe& callee = get(Recipe, inst.operation);
    if (!callee.has_header) continue;
    for (long int i = 0; i < min(SIZE(inst.ingredients), SIZE(callee.ingredients)); ++i) {
      // ingredients coerced from call to callee
      if (!types_coercible(callee.ingredients.at(i), inst.ingredients.at(i)))
        raise_error << maybe(caller.name) << "ingredient " << i << " has the wrong type at '" << to_string(inst) << "'\n" << end();
      if (is_unique_address(inst.ingredients.at(i)))
        raise << maybe(caller.name) << "try to avoid passing non-shared addresses into calls, like ingredient " << i << " at '" << to_string(inst) << "'\n" << end();
    }
    for (long int i = 0; i < min(SIZE(inst.products), SIZE(callee.products)); ++i) {
      if (is_dummy(inst.products.at(i))) continue;
      // products coerced from callee to call
      if (!types_coercible(inst.products.at(i), callee.products.at(i)))
        raise_error << maybe(caller.name) << "product " << i << " has the wrong type at '" << to_string(inst) << "'\n" << end();
      if (is_unique_address(inst.products.at(i)))
        raise << maybe(caller.name) << "try to avoid getting non-shared addresses out of calls, like product " << i << " at '" << to_string(inst) << "'\n" << end();
    }
  }
}

bool is_unique_address(reagent x) {
  if (!canonize_type(x)) return false;
  if (!x.type) return false;
  if (x.type->value != get(Type_ordinal, "address")) return false;
  if (!x.type->right) return true;
  return x.type->right->value != get(Type_ordinal, "shared");
}

//: additionally, warn on calls receiving non-shared addresses

:(scenario warn_on_calls_with_addresses)
% Hide_warnings= true;
recipe main [
  1:address:number <- copy 3/unsafe
  foo 1:address:number
]
recipe foo x:address:number [
  local-scope
  load-ingredients
]
+warn: main: try to avoid passing non-shared addresses into calls, like ingredient 0 at 'foo 1:address:number'

:(scenario warn_on_calls_with_addresses_2)
% Hide_warnings= true;
recipe main [
  1:address:number <- foo
]
recipe foo -> x:address:number [
  local-scope
  load-ingredients
  x <- copy 0
]
+warn: main: try to avoid getting non-shared addresses out of calls, like product 0 at '1:address:number <- foo '

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
  if (!caller_recipe.has_header) return;
  trace(9991, "transform") << "--- checking reply instructions against header for " << caller_recipe.name << end();
  for (long long int i = 0; i < SIZE(caller_recipe.steps); ++i) {
    const instruction& inst = caller_recipe.steps.at(i);
    if (inst.name != "reply") continue;
    if (SIZE(caller_recipe.products) != SIZE(inst.ingredients)) {
      raise_error << maybe(caller_recipe.name) << "replied with the wrong number of products at '" << to_string(inst) << "'\n" << end();
      continue;
    }
    for (long long int i = 0; i < SIZE(caller_recipe.products); ++i) {
      if (!types_match(caller_recipe.products.at(i), inst.ingredients.at(i)))
        raise_error << maybe(caller_recipe.name) << "replied with the wrong type at '" << to_string(inst) << "'\n" << end();
    }
  }
}

:(scenario recipe_headers_are_checked_2)
% Hide_errors = true;
recipe add2 x:number, y:number [
  local-scope
  load-ingredients
  z:address:number <- copy 0/unsafe
  reply z
]
+error: add2: replied with the wrong number of products at 'reply z'

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
  caller_recipe.ingredient_index.clear();
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
    trace(9993, "transform") << "type of " << caller_recipe.ingredients.at(i).name << " is " << to_string(caller_recipe.ingredients.at(i).type) << end();
  }
  for (long long int i = 0; i < SIZE(caller_recipe.products); ++i) {
    put(header_type, caller_recipe.products.at(i).name, caller_recipe.products.at(i).type);
    put(header_type_name, caller_recipe.products.at(i).name, caller_recipe.products.at(i).properties.at(0).second);
    trace(9993, "transform") << "type of " << caller_recipe.products.at(i).name << " is " << to_string(caller_recipe.products.at(i).type) << end();
  }
  for (long long int i = 0; i < SIZE(caller_recipe.steps); ++i) {
    instruction& inst = caller_recipe.steps.at(i);
    trace(9992, "transform") << "instruction: " << to_string(inst) << end();
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
      if (inst.ingredients.at(i).type) continue;
      if (header_type.find(inst.ingredients.at(i).name) == header_type.end())
        continue;
      if (!inst.ingredients.at(i).type)
        inst.ingredients.at(i).type = new type_tree(*get(header_type, inst.ingredients.at(i).name));
      if (!inst.ingredients.at(i).properties.at(0).second)
        inst.ingredients.at(i).properties.at(0).second = new string_tree(*get(header_type_name, inst.ingredients.at(i).name));
      trace(9993, "transform") << "type of " << inst.ingredients.at(i).name << " is " << to_string(inst.ingredients.at(i).type) << end();
    }
    for (long long int i = 0; i < SIZE(inst.products); ++i) {
      trace(9993, "transform") << "  product: " << to_string(inst.products.at(i)) << end();
      if (inst.products.at(i).type) continue;
      if (header_type.find(inst.products.at(i).name) == header_type.end())
        continue;
      if (!inst.products.at(i).type)
        inst.products.at(i).type = new type_tree(*get(header_type, inst.products.at(i).name));
      if (!inst.products.at(i).properties.at(0).second)
        inst.products.at(i).properties.at(0).second = new string_tree(*get(header_type_name, inst.products.at(i).name));
      trace(9993, "transform") << "type of " << inst.products.at(i).name << " is " << to_string(inst.products.at(i).type) << end();
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
    if (inst.name == "reply")
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

:(before "End Includes")
using std::min;
using std::max;

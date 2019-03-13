//: Advanced notation for the common/easy case where a recipe takes some fixed
//: number of ingredients and yields some fixed number of products.

void test_recipe_with_header() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z:num <- add x, y\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 8 in location 1\n"
  );
}

//: When loading recipes save any header.

:(before "End recipe Fields")
bool has_header;
vector<reagent> ingredients;
vector<reagent> products;
:(before "End recipe Constructor")
has_header = false;

:(before "End Recipe Refinements")
if (in.peek() != '[') {
  trace(101, "parse") << "recipe has a header; parsing" << end();
  load_recipe_header(in, result);
}

:(code)
void load_recipe_header(istream& in, recipe& result) {
  result.has_header = true;
  while (has_data(in) && in.peek() != '[' && in.peek() != '\n') {
    string s = next_word(in);
    if (s.empty()) {
      assert(!has_data(in));
      raise << "incomplete recipe header at end of file (0)\n" << end();
      return;
    }
    if (s == "<-")
      raise << "recipe " << result.name << " should say '->' and not '<-'\n" << end();
    if (s == "->") break;
    result.ingredients.push_back(reagent(s));
    trace(101, "parse") << "header ingredient: " << result.ingredients.back().original_string << end();
    skip_whitespace_but_not_newline(in);
  }
  while (has_data(in) && in.peek() != '[' && in.peek() != '\n') {
    string s = next_word(in);
    if (s.empty()) {
      assert(!has_data(in));
      raise << "incomplete recipe header at end of file (1)\n" << end();
      return;
    }
    result.products.push_back(reagent(s));
    trace(101, "parse") << "header product: " << result.products.back().original_string << end();
    skip_whitespace_but_not_newline(in);
  }
  // End Load Recipe Header(result)
}

void test_recipe_handles_stray_comma() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num, [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z:num <- add x, y\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 8 in location 1\n"
  );
}

void test_recipe_handles_stray_comma_2() {
  run(
      "def main [\n"
      "  foo\n"
      "]\n"
      "def foo, [\n"
      "  1:num/raw <- add 2, 2\n"
      "]\n"
      "def bar [\n"
      "  1:num/raw <- add 2, 3\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 4 in location 1\n"
  );
}

void test_recipe_handles_wrong_arrow() {
  Hide_errors = true;
  run(
      "def foo a:num <- b:num [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: recipe foo should say '->' and not '<-'\n"
  );
}

void test_recipe_handles_missing_bracket() {
  Hide_errors = true;
  run(
      "def main\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: recipe body must begin with '['\n"
  );
}

void test_recipe_handles_missing_bracket_2() {
  Hide_errors = true;
  run(
      "def main\n"
      "  local-scope\n"
      "  {\n"
      "  }\n"
      "]\n"
  );
  // doesn't overflow line when reading header
  CHECK_TRACE_DOESNT_CONTAIN("parse: header ingredient: local-scope");
  CHECK_TRACE_CONTENTS(
      "error: main: recipe body must begin with '['\n"
  );
}

void test_recipe_handles_missing_bracket_3() {
  Hide_errors = true;
  run(
      "def main  # comment\n"
      "  local-scope\n"
      "  {\n"
      "  }\n"
      "]\n"
  );
  // doesn't overflow line when reading header
  CHECK_TRACE_DOESNT_CONTAIN("parse: header ingredient: local-scope");
  CHECK_TRACE_CONTENTS(
      "error: main: recipe body must begin with '['\n"
  );
}

:(after "Begin debug_string(recipe x)")
out << "ingredients:\n";
for (int i = 0;  i < SIZE(x.ingredients);  ++i)
  out << "  " << debug_string(x.ingredients.at(i)) << '\n';
out << "products:\n";
for (int i = 0;  i < SIZE(x.products);  ++i)
  out << "  " << debug_string(x.products.at(i)) << '\n';

//: If a recipe never mentions any ingredients or products, assume it has a header.

:(code)
void test_recipe_without_ingredients_or_products_has_header() {
  run(
      "def test [\n"
      "  1:num <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse: recipe test has a header\n"
  );
}

:(before "End Recipe Body(result)")
if (!result.has_header) {
  result.has_header = true;
  for (int i = 0;  i < SIZE(result.steps);  ++i) {
    const instruction& inst = result.steps.at(i);
    if ((inst.name == "reply" && !inst.ingredients.empty())
        || (inst.name == "return" && !inst.ingredients.empty())
        || inst.name == "next-ingredient"
        || inst.name == "ingredient"
        || inst.name == "rewind-ingredients") {
      result.has_header = false;
      break;
    }
  }
}
if (result.has_header) {
  trace(101, "parse") << "recipe " << result.name << " has a header" << end();
}

//: Support type abbreviations in headers.

:(code)
void test_type_abbreviations_in_recipe_headers() {
  run(
      "def main [\n"
      "  local-scope\n"
      "  a:text <- foo\n"
      "  1:char/raw <- index *a, 0\n"
      "]\n"
      "def foo -> a:text [  # 'text' is an abbreviation\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  a <- new [abc]\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 97 in location 1\n"
  );
}

:(before "End Expand Type Abbreviations(caller)")
for (long int i = 0;  i < SIZE(caller.ingredients);  ++i)
  expand_type_abbreviations(caller.ingredients.at(i).type);
for (long int i = 0;  i < SIZE(caller.products);  ++i)
  expand_type_abbreviations(caller.products.at(i).type);

//: Rewrite 'load-ingredients' to instructions to create all reagents in the header.

:(before "End Rewrite Instruction(curr, recipe result)")
if (curr.name == "load-ingredients" || curr.name == "load-inputs") {
  curr.clear();
  recipe_ordinal op = get(Recipe_ordinal, "next-ingredient-without-typechecking");
  for (int i = 0;  i < SIZE(result.ingredients);  ++i) {
    curr.operation = op;
    curr.name = "next-ingredient-without-typechecking";
    curr.products.push_back(result.ingredients.at(i));
    result.steps.push_back(curr);
    curr.clear();
  }
}
if (curr.name == "next-ingredient-without-typechecking") {
  raise << maybe(result.name) << "never call 'next-ingredient-without-typechecking' directly\n" << end();
  curr.clear();
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
    products.at(0).resize(size_of(current_instruction().products.at(0)));
    products.at(1).push_back(0);
  }
  break;
}

//: more useful error messages if someone forgets 'load-ingredients'
:(code)
void test_load_ingredients_missing_error() {
  Hide_errors = true;
  run(
      "def foo a:num [\n"
      "  local-scope\n"
      "  b:num <- add a:num, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: tried to read ingredient 'a' in 'b:num <- add a:num, 1' but it hasn't been written to yet\n"
      "error:   did you forget 'load-ingredients'?\n"
  );
}

:(after "use-before-set Error")
if (is_present_in_ingredients(caller, ingredient.name))
  raise << "  did you forget 'load-ingredients'?\n" << end();

:(code)
void test_load_ingredients_missing_error_2() {
  Hide_errors = true;
  run(
      "def foo a:num [\n"
      "  local-scope\n"
      "  b:num <- add a, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: missing type for 'a' in 'b:num <- add a, 1'\n"
      "error:   did you forget 'load-ingredients'?\n"
  );
}

:(after "missing-type Error 1")
if (is_present_in_ingredients(get(Recipe, get(Recipe_ordinal, recipe_name)), x.name))
  raise << "  did you forget 'load-ingredients'?\n" << end();

:(code)
bool is_present_in_ingredients(const recipe& callee, const string& ingredient_name) {
  for (int i = 0;  i < SIZE(callee.ingredients);  ++i) {
    if (callee.ingredients.at(i).name == ingredient_name)
      return true;
  }
  return false;
}

//:: Check all calls against headers.

void test_show_clear_error_on_bad_call() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:num <- foo 34\n"
      "]\n"
      "def foo x:point -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return 35\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: ingredient 0 has the wrong type at '1:num <- foo 34'\n"
  );
}

void test_show_clear_error_on_bad_call_2() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:point <- foo 34\n"
      "]\n"
      "def foo x:num -> y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return x\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: product 0 has the wrong type at '1:point <- foo 34'\n"
  );
}

:(after "Transform.push_back(check_instruction)")
Transform.push_back(check_calls_against_header);  // idempotent
:(code)
void check_calls_against_header(const recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  trace(101, "transform") << "--- type-check calls inside recipe " << caller.name << end();
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    const instruction& inst = caller.steps.at(i);
    if (is_primitive(inst.operation)) continue;
    const recipe& callee = get(Recipe, inst.operation);
    if (!callee.has_header) continue;
    for (long int i = 0;  i < min(SIZE(inst.ingredients), SIZE(callee.ingredients));  ++i) {
      // ingredients coerced from call to callee
      if (!types_coercible(callee.ingredients.at(i), inst.ingredients.at(i))) {
        raise << maybe(caller.name) << "ingredient " << i << " has the wrong type at '" << to_original_string(inst) << "'\n" << end();
        raise << "  ['" << to_string(callee.ingredients.at(i).type) << "' vs '" << to_string(inst.ingredients.at(i).type) << "']\n" << end();
      }
    }
    for (long int i = 0;  i < min(SIZE(inst.products), SIZE(callee.products));  ++i) {
      if (is_dummy(inst.products.at(i))) continue;
      // products coerced from callee to call
      if (!types_coercible(inst.products.at(i), callee.products.at(i))) {
        raise << maybe(caller.name) << "product " << i << " has the wrong type at '" << to_original_string(inst) << "'\n" << end();
        raise << "  ['" << to_string(inst.products.at(i).type) << "' vs '" << to_string(callee.products.at(i).type) << "']\n" << end();
      }
    }
  }
}

//:: Check types going in and out of all recipes with headers.

void test_recipe_headers_are_checked() {
  Hide_errors = true;
  transform(
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z:&:num <- copy 0/unsafe\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: add2: replied with the wrong type at 'return z'\n"
  );
}

:(before "End Checks")
Transform.push_back(check_return_instructions_against_header);  // idempotent

:(code)
void check_return_instructions_against_header(const recipe_ordinal r) {
  const recipe& caller_recipe = get(Recipe, r);
  if (!caller_recipe.has_header) return;
  trace(101, "transform") << "--- checking return instructions against header for " << caller_recipe.name << end();
  for (int i = 0;  i < SIZE(caller_recipe.steps);  ++i) {
    const instruction& inst = caller_recipe.steps.at(i);
    if (inst.name != "reply" && inst.name != "return") continue;
    if (SIZE(caller_recipe.products) != SIZE(inst.ingredients)) {
      raise << maybe(caller_recipe.name) << "replied with the wrong number of products at '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    for (int i = 0;  i < SIZE(caller_recipe.products);  ++i) {
      if (!types_match(caller_recipe.products.at(i), inst.ingredients.at(i)))
        raise << maybe(caller_recipe.name) << "replied with the wrong type at '" << to_original_string(inst) << "'\n" << end();
    }
  }
}

void test_recipe_headers_are_checked_2() {
  Hide_errors = true;
  transform(
      "def add2 x:num, y:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z:&:num <- copy 0/unsafe\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: add2: replied with the wrong number of products at 'return z'\n"
  );
}

void test_recipe_headers_are_checked_against_pre_transformed_instructions() {
  Hide_errors = true;
  transform(
      "def foo -> x:num [\n"
      "  local-scope\n"
      "  x:num <- copy 0\n"
      "  z:bool <- copy false\n"
      "  return-if z, z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: replied with the wrong type at 'return-if z, z'\n"
  );
}

void test_recipe_headers_check_for_duplicate_names() {
  Hide_errors = true;
  transform(
      "def foo x:num, x:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: 'x' can't repeat in the ingredients\n"
  );
}

void test_recipe_headers_check_for_duplicate_names_2() {
  Hide_errors = true;
  transform(
      "def foo x:num, x:num [  # no result\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: 'x' can't repeat in the ingredients\n"
  );
}

void test_recipe_headers_check_for_missing_types() {
  Hide_errors = true;
  transform(
      "def main [\n"
      "  foo 0\n"
      "]\n"
      "def foo a [\n"  // no type for 'a'
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: ingredient 'a' has no type\n"
  );
}

:(before "End recipe Fields")
map<string, int> ingredient_index;

:(after "Begin Instruction Modifying Transforms")
Transform.push_back(check_header_ingredients);  // idempotent

:(code)
void check_header_ingredients(const recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  caller_recipe.ingredient_index.clear();
  trace(101, "transform") << "--- checking return instructions against header for " << caller_recipe.name << end();
  for (int i = 0;  i < SIZE(caller_recipe.ingredients);  ++i) {
    if (caller_recipe.ingredients.at(i).type == NULL)
      raise << maybe(caller_recipe.name) << "ingredient '" << caller_recipe.ingredients.at(i).name << "' has no type\n" << end();
    if (contains_key(caller_recipe.ingredient_index, caller_recipe.ingredients.at(i).name))
      raise << maybe(caller_recipe.name) << "'" << caller_recipe.ingredients.at(i).name << "' can't repeat in the ingredients\n" << end();
    put(caller_recipe.ingredient_index, caller_recipe.ingredients.at(i).name, i);
  }
}

//: Deduce types from the header if possible.

void test_deduce_instruction_types_from_recipe_header() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z <- add x, y  # no type for z\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 8 in location 1\n"
  );
}

:(after "Begin Type Modifying Transforms")
Transform.push_back(deduce_types_from_header);  // idempotent

:(code)
void deduce_types_from_header(const recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  if (caller_recipe.products.empty()) return;
  trace(101, "transform") << "--- deduce types from header for " << caller_recipe.name << end();
  map<string, const type_tree*> header_type;
  for (int i = 0;  i < SIZE(caller_recipe.ingredients);  ++i) {
    if (!caller_recipe.ingredients.at(i).type) continue;  // error handled elsewhere
    put(header_type, caller_recipe.ingredients.at(i).name, caller_recipe.ingredients.at(i).type);
    trace(103, "transform") << "type of " << caller_recipe.ingredients.at(i).name << " is " << names_to_string(caller_recipe.ingredients.at(i).type) << end();
  }
  for (int i = 0;  i < SIZE(caller_recipe.products);  ++i) {
    if (!caller_recipe.products.at(i).type) continue;  // error handled elsewhere
    put(header_type, caller_recipe.products.at(i).name, caller_recipe.products.at(i).type);
    trace(103, "transform") << "type of " << caller_recipe.products.at(i).name << " is " << names_to_string(caller_recipe.products.at(i).type) << end();
  }
  for (int i = 0;  i < SIZE(caller_recipe.steps);  ++i) {
    instruction& inst = caller_recipe.steps.at(i);
    trace(102, "transform") << "instruction: " << to_string(inst) << end();
    for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
      if (inst.ingredients.at(i).type) continue;
      if (header_type.find(inst.ingredients.at(i).name) == header_type.end())
        continue;
      if (!contains_key(header_type, inst.ingredients.at(i).name)) continue;  // error handled elsewhere
      inst.ingredients.at(i).type = new type_tree(*get(header_type, inst.ingredients.at(i).name));
      trace(103, "transform") << "type of " << inst.ingredients.at(i).name << " is " << names_to_string(inst.ingredients.at(i).type) << end();
    }
    for (int i = 0;  i < SIZE(inst.products);  ++i) {
      trace(103, "transform") << "  product: " << to_string(inst.products.at(i)) << end();
      if (inst.products.at(i).type) continue;
      if (header_type.find(inst.products.at(i).name) == header_type.end())
        continue;
      if (!contains_key(header_type, inst.products.at(i).name)) continue;  // error handled elsewhere
      inst.products.at(i).type = new type_tree(*get(header_type, inst.products.at(i).name));
      trace(103, "transform") << "type of " << inst.products.at(i).name << " is " << names_to_string(inst.products.at(i).type) << end();
    }
  }
}

//: One final convenience: no need to say what to return if the information is
//: in the header.

void test_return_based_on_header() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z <- add x, y\n"
      "  return\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 8 in location 1\n"
  );
}

:(after "Transform.push_back(check_header_ingredients)")
Transform.push_back(fill_in_return_ingredients);  // idempotent

:(code)
void fill_in_return_ingredients(const recipe_ordinal r) {
  recipe& caller_recipe = get(Recipe, r);
  trace(101, "transform") << "--- fill in return ingredients from header for recipe " << caller_recipe.name << end();
  if (!caller_recipe.has_header) return;
  for (int i = 0;  i < SIZE(caller_recipe.steps);  ++i) {
    instruction& inst = caller_recipe.steps.at(i);
    if (inst.name == "reply" || inst.name == "return")
      add_header_products(inst, caller_recipe);
  }
  // fall through return
  if (!caller_recipe.steps.empty()) {
    const instruction& final_instruction = caller_recipe.steps.at(SIZE(caller_recipe.steps)-1);
    if (final_instruction.name == "reply" || final_instruction.name == "return")
      return;
  }
  instruction inst;
  inst.name = "return";
  add_header_products(inst, caller_recipe);
  caller_recipe.steps.push_back(inst);
}

void add_header_products(instruction& inst, const recipe& caller_recipe) {
  assert(inst.name == "reply" || inst.name == "return");
  // collect any products with the same names as ingredients
  for (int i = 0;  i < SIZE(caller_recipe.products);  ++i) {
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

void test_explicit_return_ignores_header() {
  run(
      "def main [\n"
      "  1:num/raw, 2:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 a:num, b:num -> y:num, z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  y <- add a, b\n"
      "  z <- subtract a, b\n"
      "  return a, z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 3 in location 1\n"
      "mem: storing -2 in location 2\n"
  );
}

void test_return_on_fallthrough_based_on_header() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z <- add x, y\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: instruction: return {z: \"number\"}\n"
      "mem: storing 8 in location 1\n"
  );
}

void test_return_on_fallthrough_already_exists() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z <- add x, y  # no type for z\n"
      "  return z\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: instruction: return {z: ()}\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("transform: instruction: return z:num");
  CHECK_TRACE_CONTENTS(
      "mem: storing 8 in location 1\n"
  );
}

void test_return_causes_error_in_empty_recipe() {
  Hide_errors = true;
  run(
      "def foo -> x:num [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: tried to read ingredient 'x' in 'return x:num' but it hasn't been written to yet\n"
  );
}

void test_return_after_conditional_return_based_on_header() {
  run(
      "def main [\n"
      "  1:num/raw <- add2 3, 5\n"
      "]\n"
      "def add2 x:num, y:num -> z:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  z <- add x, y\n"  // no type for z
      "  return-if false, 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 8 in location 1\n"
  );
}

void test_recipe_headers_perform_same_ingredient_check() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:num <- copy 34\n"
      "  2:num <- copy 34\n"
      "  3:num <- add2 1:num, 2:num\n"
      "]\n"
      "def add2 x:num, y:num -> x:num [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: '3:num <- add2 1:num, 2:num' should write to '1:num' rather than '3:num'\n"
  );
}

//: One special-case is recipe 'main'. Make sure it's only ever taking in text
//: ingredients, and returning a single number.

void test_recipe_header_ingredients_constrained_for_main() {
  Hide_errors = true;
  run(
      "def main x:num [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: ingredients of recipe 'main' must all be text (address:array:character)\n"
  );
}
void test_recipe_header_products_constrained_for_main() {
  Hide_errors = true;
  run(
      "def main -> x:text [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: recipe 'main' must return at most a single product, a number\n"
  );
}
void test_recipe_header_products_constrained_for_main_2() {
  Hide_errors = true;
  run(
      "def main -> x:num, y:num [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: recipe 'main' must return at most a single product, a number\n"
  );
}

:(after "Transform.push_back(expand_type_abbreviations)")
Transform.push_back(check_recipe_header_constraints);
:(code)
void check_recipe_header_constraints(const recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  if (caller.name != "main") return;
  trace(102, "transform") << "check recipe header constraints for recipe " << caller.name << end();
  if (!caller.has_header) return;
  reagent/*local*/ expected_ingredient("x:address:array:character");
  for (int i = 0; i < SIZE(caller.ingredients); ++i) {
    if (!types_strictly_match(expected_ingredient, caller.ingredients.at(i))) {
      raise << "ingredients of recipe 'main' must all be text (address:array:character)\n" << end();
      break;
    }
  }
  int nprod = SIZE(caller.products);
  reagent/*local*/ expected_product("x:number");
  if (nprod > 1
      || (nprod == 1 && !types_strictly_match(expected_product, caller.products.at(0)))) {
    raise << "recipe 'main' must return at most a single product, a number\n" << end();
  }
}

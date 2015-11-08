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
skip_whitespace(in);
if (in.peek() != '[') {
  trace(9999, "parse") << "recipe has a header; parsing" << end();
  load_recipe_header(in, result);
}

:(code)
void load_recipe_header(istream& in, recipe& result) {
  result.has_header = true;
  while (in.peek() != '[') {
    string s = next_word(in);
    if (s == "->") break;
    result.ingredients.push_back(reagent(s));
    trace(9999, "parse") << "header ingredient: " << result.ingredients.back().original_string << end();
    skip_whitespace(in);
  }
  while (in.peek() != '[') {
    string s = next_word(in);
    result.products.push_back(reagent(s));
    trace(9999, "parse") << "header product: " << result.products.back().original_string << end();
    skip_whitespace(in);
  }
  // End Load Recipe Header(result)
}

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
  z:address:number <- copy 0/raw
  reply z
]
+error: add2: replied with the wrong type at 'reply z'

:(after "Transform.push_back(check_types_by_name)")
Transform.push_back(check_header_products);  // idempotent

:(code)
void check_header_products(const recipe_ordinal r) {
  const recipe& rr = get(Recipe, r);
  if (rr.products.empty()) return;
  trace(9991, "transform") << "--- checking reply instructions against header for " << rr.name << end();
//?   cerr << "--- checking reply instructions against header for " << rr.name << '\n';
  for (long long int i = 0; i < SIZE(rr.steps); ++i) {
    const instruction& inst = rr.steps.at(i);
    if (inst.name != "reply") continue;
    if (SIZE(rr.products) != SIZE(inst.ingredients)) {
      raise_error << maybe(rr.name) << "tried to reply the wrong number of products in '" << inst.to_string() << "'\n" << end();
    }
    for (long long int i = 0; i < SIZE(rr.products); ++i) {
      if (!types_match(rr.products.at(i), inst.ingredients.at(i))) {
        raise_error << maybe(rr.name) << "replied with the wrong type at '" << inst.to_string() << "'\n" << end();
      }
    }
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

:(before "Transform.push_back(check_header_products)")
Transform.push_back(deduce_types_from_header);  // idempotent

:(code)
void deduce_types_from_header(const recipe_ordinal r) {
  recipe& rr = get(Recipe, r);
  if (rr.products.empty()) return;
  trace(9991, "transform") << "--- deduce types from header for " << rr.name << end();
//?   cerr << "--- deduce types from header for " << rr.name << '\n';
  map<string, const type_tree*> header;
  for (long long int i = 0; i < SIZE(rr.ingredients); ++i) {
    header[rr.ingredients.at(i).name] = rr.ingredients.at(i).type;
  }
  for (long long int i = 0; i < SIZE(rr.products); ++i) {
    header[rr.products.at(i).name] = rr.products.at(i).type;
  }
  for (long long int i = 0; i < SIZE(rr.steps); ++i) {
    instruction& inst = rr.steps.at(i);
    trace(9992, "transform") << inst.to_string() << end();
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
      if (inst.ingredients.at(i).type) continue;
      if (header.find(inst.ingredients.at(i).name) == header.end()) {
        raise << maybe(rr.name) << "unknown variable " << inst.ingredients.at(i).name << " in '" << inst.to_string() << "'\n" << end();
        continue;
      }
      inst.ingredients.at(i).type = new type_tree(*header[inst.ingredients.at(i).name]);
      trace(9993, "transform") << "type of " << inst.ingredients.at(i).name << " is " << debug_string(inst.ingredients.at(i).type) << end();
    }
    for (long long int i = 0; i < SIZE(inst.products); ++i) {
      if (inst.products.at(i).type) continue;
      if (header.find(inst.products.at(i).name) == header.end()) {
        raise << maybe(rr.name) << "unknown variable " << inst.products.at(i).name << " in '" << inst.to_string() << "'\n" << end();
        continue;
      }
      inst.products.at(i).type = new type_tree(*header[inst.products.at(i).name]);
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

:(after "Transform.push_back(insert_fragments)")
Transform.push_back(fill_in_reply_ingredients);

:(code)
void fill_in_reply_ingredients(recipe_ordinal r) {
  if (!get(Recipe, r).has_header) return;
  trace(9991, "transform") << "--- fill in reply ingredients from header for recipe " << get(Recipe, r).name << end();
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    if (inst.name == "reply" && inst.ingredients.empty()) {
      for (long long int i = 0; i < SIZE(get(Recipe, r).products); ++i)
        inst.ingredients.push_back(get(Recipe, r).products.at(i));
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
+transform: reply z:number
+mem: storing 8 in location 1

:(after "Transform.push_back(insert_fragments)")
Transform.push_back(deduce_fallthrough_reply);

:(code)
void deduce_fallthrough_reply(const recipe_ordinal r) {
  recipe& rr = get(Recipe, r);
  if (rr.products.empty()) return;
  if (rr.steps.empty()) return;
  if (rr.steps.at(SIZE(rr.steps)-1).name != "reply") {
    instruction inst;
    inst.operation = REPLY;
    inst.name = "reply";
    for (long long int i = 0; i < SIZE(rr.products); ++i) {
      inst.ingredients.push_back(rr.products.at(i));
    }
    rr.steps.push_back(inst);
  }
}

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
+transform: reply z
-transform: reply z:number
+mem: storing 8 in location 1

//: allow using literal strings anywhere that will accept immutable strings

:(before "End Instruction Inserting/Deleting Transforms")
initialize_transform_rewrite_literal_string_to_text();
Transform.push_back(rewrite_literal_string_to_text);

:(before "End Globals")
set<string> recipes_taking_literal_strings;
:(code)
void initialize_transform_rewrite_literal_string_to_text() {
  recipes_taking_literal_strings.insert("$print");
  recipes_taking_literal_strings.insert("trace");
  recipes_taking_literal_strings.insert("stash");
  recipes_taking_literal_strings.insert("assert");
  recipes_taking_literal_strings.insert("new");
  recipes_taking_literal_strings.insert("run");
  recipes_taking_literal_strings.insert("assume-console");
  recipes_taking_literal_strings.insert("memory-should-contain");
  recipes_taking_literal_strings.insert("trace-should-contain");
  recipes_taking_literal_strings.insert("trace-should-not-contain");
  recipes_taking_literal_strings.insert("check-trace-count-for-label");
  recipes_taking_literal_strings.insert("screen-should-contain");
  recipes_taking_literal_strings.insert("screen-should-contain-in-color");
}

void rewrite_literal_string_to_text(recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- rewrite literal strings in recipe " << caller.name << end();
  if (contains_numeric_locations(caller)) return;
  vector<instruction> new_instructions;
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    if (recipes_taking_literal_strings.find(inst.name) == recipes_taking_literal_strings.end()) {
      for (int j = 0; j < SIZE(inst.ingredients); ++j) {
        if (!is_literal_string(inst.ingredients.at(j))) continue;
        instruction def;
        ostringstream ingredient_name;
        ingredient_name << inst.name << '_' << i << '_' << j << ":address:shared:array:character";
        def.name = "new";
        def.ingredients.push_back(inst.ingredients.at(j));
        def.products.push_back(reagent(ingredient_name.str()));
        new_instructions.push_back(def);
        inst.ingredients.at(j).clear();  // reclaim old memory
        inst.ingredients.at(j) = reagent(ingredient_name.str());
      }
    }
    new_instructions.push_back(inst);
  }
  caller.steps.swap(new_instructions);
}

bool contains_numeric_locations(const recipe& caller) {
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    for (int in = 0; in < SIZE(inst.ingredients); ++in)
      if (is_numeric_location(inst.ingredients.at(in)))
        return true;
    for (int out = 0; out < SIZE(inst.products); ++out)
      if (is_numeric_location(inst.products.at(out)))
        return true;
  }
  return false;
}

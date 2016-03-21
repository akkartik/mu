//: when encountering other types, try to convert them to strings using
//: 'to-text'

:(scenarios transform)
:(scenario rewrite_stashes_to_text)
recipe main [
  local-scope
  n:number <- copy 34
  stash n
]
+transform: stash_2_0:address:shared:array:character <- to-text-line n
+transform: stash stash_2_0:address:shared:array:character

:(before "End Instruction Inserting/Deleting Transforms")
Transform.push_back(rewrite_stashes_to_text);

:(code)
void rewrite_stashes_to_text(recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- rewrite 'stash' instructions in recipe " << caller.name << end();
  // in recipes without named locations, 'stash' is still not extensible
  if (contains_numeric_locations(caller)) return;
  rewrite_stashes_to_text(caller);
}

void rewrite_stashes_to_text(recipe& caller) {
  vector<instruction> new_instructions;
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    if (inst.name == "stash") {
      for (int j = 0; j < SIZE(inst.ingredients); ++j) {
        if (is_literal(inst.ingredients.at(j))) continue;
        if (is_mu_string(inst.ingredients.at(j))) continue;
        instruction def;
        def.name = "to-text-line";
        def.ingredients.push_back(inst.ingredients.at(j));
        ostringstream ingredient_name;
        ingredient_name << "stash_" << i << '_' << j << ":address:shared:array:character";
        def.products.push_back(reagent(ingredient_name.str()));
        trace(9993, "transform") << to_string(def) << end();
        new_instructions.push_back(def);
        inst.ingredients.at(j).clear();  // reclaim old memory
        inst.ingredients.at(j) = reagent(ingredient_name.str());
      }
    }
    trace(9993, "transform") << to_string(inst) << end();
    new_instructions.push_back(inst);
  }
  caller.steps.swap(new_instructions);
}

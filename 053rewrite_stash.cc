//: when encountering other types, try to convert them to strings using
//: 'to-text'

:(scenarios transform)
:(scenario rewrite_stashes_to_text)
recipe main [
  local-scope
  n:number <- copy 34
  stash n
]
+transform: stash_0_0:address:shared:array:character <- to-text-line n
+transform: stash stash_0_0:address:shared:array:character

:(before "End Instruction Inserting/Deleting Transforms")
Transform.push_back(rewrite_stashes_to_text);

:(code)
void rewrite_stashes_to_text(recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- rewrite 'stash' instructions in recipe " << caller.name << end();
  if (contains_named_locations(caller))
    rewrite_stashes_to_text_named(caller);
  // in recipes without named locations, 'stash' is still not extensible
}

bool contains_named_locations(const recipe& caller) {
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    for (int in = 0; in < SIZE(inst.ingredients); ++in)
      if (is_named_location(inst.ingredients.at(in)))
        return true;
    for (int out = 0; out < SIZE(inst.products); ++out)
      if (is_named_location(inst.products.at(out)))
        return true;
  }
  return false;
}

void rewrite_stashes_to_text_named(recipe& caller) {
  static int stash_instruction_idx = 0;
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
        ingredient_name << "stash_" << stash_instruction_idx << '_' << j << ":address:shared:array:character";
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
  new_instructions.swap(caller.steps);
}

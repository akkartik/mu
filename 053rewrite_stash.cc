//: when encountering other types, try to convert them to strings using
//: 'to-text'

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
  for (long long int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    for (long long int in = 0; in < SIZE(inst.ingredients); ++in)
      if (is_named_location(inst.ingredients.at(in)))
        return true;
    for (long long int out = 0; out < SIZE(inst.products); ++out)
      if (is_named_location(inst.products.at(out)))
        return true;
  }
  return false;
}

void rewrite_stashes_to_text_named(recipe& caller) {
  static long long int stash_instruction_idx = 0;
  vector<instruction> new_instructions;
  for (long long int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    if (inst.name == "stash") {
      for (long long int j = 0; j < SIZE(inst.ingredients); ++j) {
        if (is_literal(inst.ingredients.at(j))) continue;
        if (is_mu_string(inst.ingredients.at(j))) continue;
        instruction def;
        def.name = "to-text-line";
        def.ingredients.push_back(inst.ingredients.at(j));
        ostringstream ingredient_name;
        ingredient_name << "stash_" << stash_instruction_idx << '_' << j << ":address:shared:array:character";
        def.products.push_back(reagent(ingredient_name.str()));
        new_instructions.push_back(def);
        inst.ingredients.at(j).clear();  // reclaim old memory
        inst.ingredients.at(j) = reagent(ingredient_name.str());
      }
    }
    new_instructions.push_back(inst);
  }
  new_instructions.swap(caller.steps);
}

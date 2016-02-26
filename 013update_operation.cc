//: Once all code is loaded, save operation ids of instructions and check that
//: nothing's undefined.

:(before "End Instruction Modifying Transforms")
Transform.push_back(update_instruction_operations);  // idempotent

:(code)
void update_instruction_operations(recipe_ordinal r) {
  trace(9991, "transform") << "--- compute instruction operations for recipe " << get(Recipe, r).name << end();
  recipe& caller = get(Recipe, r);
//?   cerr << "--- compute instruction operations for recipe " << caller.name << '\n';
  for (long long int index = 0; index < SIZE(caller.steps); ++index) {
    instruction& inst = caller.steps.at(index);
    if (inst.is_label) continue;
    if (!contains_key(Recipe_ordinal, inst.name)) {
      raise << maybe(caller.name) << "instruction " << inst.name << " has no recipe\n" << end();
      continue;
    }
    inst.operation = get(Recipe_ordinal, inst.name);
    // End Instruction Operation Checks
  }
}

// hook to suppress inserting recipe name into errors (for later layers)
string maybe(string s) {
  return s + ": ";
}

// temporarily suppress run
void transform(string form) {
  load(form);
  transform_all();
}

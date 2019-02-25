//: Once all code is loaded, save operation ids of instructions and check that
//: nothing's undefined.

:(before "End Instruction Modifying Transforms")
Transform.push_back(update_instruction_operations);  // idempotent

:(code)
void update_instruction_operations(const recipe_ordinal r) {
  trace(101, "transform") << "--- compute instruction operations for recipe " << get(Recipe, r).name << end();
  recipe& caller = get(Recipe, r);
//?   cerr << "--- compute instruction operations for recipe " << caller.name << '\n';
  for (int index = 0;  index < SIZE(caller.steps);  ++index) {
    instruction& inst = caller.steps.at(index);
    if (inst.is_label) continue;
    if (!contains_key(Recipe_ordinal, inst.name)) {
      raise << maybe(caller.name) << "instruction '" << inst.name << "' has no recipe in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    inst.operation = get(Recipe_ordinal, inst.name);
    // End Instruction Operation Checks
  }
}

// hook to suppress inserting recipe name into errors
string maybe(string recipe_name) {
  // End maybe(recipe_name) Special-cases
  return recipe_name + ": ";
}

:(scenarios transform)
:(scenario missing_arrow)
% Hide_errors = true;
def main [
  1:number , copy 0  # typo: ',' instead of '<-'
]
+error: main: instruction '1:number' has no recipe in '1:number copy, 0'

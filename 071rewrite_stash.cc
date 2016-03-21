//: when encountering other types, try to convert them to strings using
//: 'to-text'

:(scenarios transform)
:(scenario rewrite_stashes_to_text)
recipe main [
  local-scope
  n:number <- copy 34
  stash n
]
+transform: {stash_2_0: ("address" "shared" "array" "character")} <- to-text-line {n: "number"}
+transform: stash {stash_2_0: ("address" "shared" "array" "character")}

//: special case: rewrite attempts to stash contents of most arrays to avoid
//: passing addresses around

:(scenario rewrite_stashes_of_arrays)
recipe main [
  local-scope
  n:address:shared:array:number <- new number:type, 3
  stash *n
]
+transform: {stash_2_0: ("address" "shared" "array" "character")} <- array-to-text-line {n: ("address" "shared" "array" "number")}
+transform: stash {stash_2_0: ("address" "shared" "array" "character")}

:(before "End Instruction Inserting/Deleting Transforms")
Transform.push_back(rewrite_stashes_to_text);

:(code)
void rewrite_stashes_to_text(recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- rewrite 'stash' instructions in recipe " << caller.name << end();
  // in recipes without named locations, 'stash' is still not extensible
  if (contains_numeric_locations(caller)) return;
  check_or_set_types_by_name(r);  // prerequisite
  rewrite_stashes_to_text(caller);
}

void rewrite_stashes_to_text(recipe& caller) {
  vector<instruction> new_instructions;
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    if (inst.name == "stash") {
      for (int j = 0; j < SIZE(inst.ingredients); ++j) {
        assert(inst.ingredients.at(j).type);
        if (is_literal(inst.ingredients.at(j))) continue;
        if (is_mu_string(inst.ingredients.at(j))) continue;
        instruction def;
        if (is_address_of_array(inst.ingredients.at(j))) {
          def.name = "array-to-text-line";
          reagent tmp = inst.ingredients.at(j);
          drop_one_lookup(tmp);
          def.ingredients.push_back(tmp);
        }
        else {
          def.name = "to-text-line";
          def.ingredients.push_back(inst.ingredients.at(j));
        }
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

bool is_address_of_array(reagent x) {
  if (!canonize_type(x)) return false;
  return x.type->name == "array";
}

//: Make sure that the new system is strictly better than just the 'stash'
//: primitive by itself.

:(scenarios run)
:(scenario rewrite_stash_continues_to_fall_back_to_default_implementation)
# type without a to-text implementation
container foo [
  x:number
  y:number
]
recipe main [
  local-scope
  x:foo <- merge 34, 35
  stash x
]
+app: 34 35

:(before "End Primitive Recipe Declarations")
TO_TEXT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "to-text", TO_TEXT);
:(before "End Primitive Recipe Checks")
case TO_TEXT: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'to-text' requires a single ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case TO_TEXT: {
  products.resize(1);
  products.at(0).push_back(new_mu_string(print_mu(current_instruction().ingredients.at(0), ingredients.at(0))));
  break;
}

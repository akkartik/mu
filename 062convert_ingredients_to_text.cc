//: make some functions more friendly by trying to auto-convert their ingredients to text

:(scenarios transform)
:(scenario rewrite_stashes_to_text)
recipe main [
  local-scope
  n:number <- copy 34
  stash n
]
+transform: {stash_2_0: ("address" "array" "character")} <- to-text-line {n: "number"}
+transform: stash {stash_2_0: ("address" "array" "character")}

:(scenario rewrite_traces_to_text)
recipe main [
  local-scope
  n:number <- copy 34
  trace 2, [app], n
]
+transform: {trace_2_2: ("address" "array" "character")} <- to-text-line {n: "number"}
+transform: trace {2: "literal"}, {"app": "literal-string"}, {trace_2_2: ("address" "array" "character")}

//: special case: rewrite attempts to stash contents of most arrays to avoid
//: passing addresses around

:(scenario rewrite_stashes_of_arrays)
recipe main [
  local-scope
  n:address:array:number <- new number:type, 3
  stash *n
]
+transform: {stash_2_0: ("address" "array" "character")} <- array-to-text-line {n: ("address" "array" "number")}
+transform: stash {stash_2_0: ("address" "array" "character")}

:(scenario ignore_stashes_of_static_arrays)
recipe main [
  local-scope
  n:array:number:3 <- create-array
  stash n
]
+transform: stash {n: ("array" "number" "3")}

:(scenario rewrite_stashes_of_recipe_header_products)
container foo [
  x:number
]
recipe bar -> x:foo [
  local-scope
  load-ingredients
  x <- merge 34
  stash x
]
+transform: stash {stash_2_0: ("address" "array" "character")}

//: misplaced; should be in instruction inserting/deleting transforms, but has
//: prerequisites: deduce_types_from_header and check_or_set_types_by_name
:(after "Transform.push_back(deduce_types_from_header)")
Transform.push_back(convert_ingredients_to_text);

:(code)
void convert_ingredients_to_text(recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- convert some ingredients to text in recipe " << caller.name << end();
  // in recipes without named locations, 'stash' is still not extensible
  if (contains_numeric_locations(caller)) return;
  convert_ingredients_to_text(caller);
}

void convert_ingredients_to_text(recipe& caller) {
  vector<instruction> new_instructions;
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    if (inst.name == "stash") {
      for (int j = 0; j < SIZE(inst.ingredients); ++j) {
        ostringstream ingredient_name;
        ingredient_name << "stash_" << i << '_' << j << ":address:array:character";
        convert_ingredient_to_text(inst.ingredients.at(j), new_instructions, ingredient_name.str());
      }
    }
    else if (inst.name == "trace") {
      for (int j = /*skip*/2; j < SIZE(inst.ingredients); ++j) {
        ostringstream ingredient_name;
        ingredient_name << "trace_" << i << '_' << j << ":address:array:character";
        convert_ingredient_to_text(inst.ingredients.at(j), new_instructions, ingredient_name.str());
      }
    }
    trace(9993, "transform") << to_string(inst) << end();
    new_instructions.push_back(inst);
  }
  caller.steps.swap(new_instructions);
}

// add an instruction to convert reagent 'r' to text in list 'out', then
// replace r with converted text
void convert_ingredient_to_text(reagent& r, vector<instruction>& out, const string& tmp_var) {
  if (!r.type) return;  // error; will be handled elsewhere
  if (is_literal(r)) return;
  if (is_mu_string(r)) return;
  // don't try to extend static arrays
  if (is_static_array(r)) return;
  instruction def;
  if (is_lookup_of_address_of_array(r)) {
    def.name = "array-to-text-line";
    reagent/*copy*/ tmp = r;
    drop_one_lookup(tmp);
    def.ingredients.push_back(tmp);
  }
  else {
    def.name = "to-text-line";
    def.ingredients.push_back(r);
  }
  def.products.push_back(reagent(tmp_var));
  trace(9993, "transform") << to_string(def) << end();
  out.push_back(def);
  r.clear();  // reclaim old memory
  r = reagent(tmp_var);
}

bool is_lookup_of_address_of_array(reagent/*copy*/ x) {
  if (x.type->atom) return false;
  if (x.type->left->name != "address") return false;
  if (!canonize_type(x)) return false;
  return is_mu_array(x);
}

bool is_static_array(const reagent& x) {
  // no canonize_type()
  return !x.type->atom && x.type->left->atom && x.type->left->name == "array";
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

//: make some recipes more friendly by trying to auto-convert their ingredients to text

void test_rewrite_stashes_to_text() {
  transform(
      "def main [\n"
      "  local-scope\n"
      "  n:num <- copy 34\n"
      "  stash n\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: {stash_2_0: (\"address\" \"array\" \"character\")} <- to-text-line {n: \"number\"}\n"
      "transform: stash {stash_2_0: (\"address\" \"array\" \"character\")}\n"
  );
}

void test_rewrite_traces_to_text() {
  transform(
      "def main [\n"
      "  local-scope\n"
      "  n:num <- copy 34\n"
      "  trace 2, [app], n\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: {trace_2_2: (\"address\" \"array\" \"character\")} <- to-text-line {n: \"number\"}\n"
      "transform: trace {2: \"literal\"}, {\"app\": \"literal-string\"}, {trace_2_2: (\"address\" \"array\" \"character\")}\n"
  );
}

//: special case: rewrite attempts to stash contents of most arrays to avoid
//: passing addresses around

void test_rewrite_stashes_of_arrays() {
  transform(
      "def main [\n"
      "  local-scope\n"
      "  n:&:@:num <- new number:type, 3\n"
      "  stash *n\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: {stash_2_0: (\"address\" \"array\" \"character\")} <- array-to-text-line {n: (\"address\" \"array\" \"number\")}\n"
      "transform: stash {stash_2_0: (\"address\" \"array\" \"character\")}\n"
  );
}

void test_ignore_stashes_of_static_arrays() {
  transform(
      "def main [\n"
      "  local-scope\n"
      "  n:@:num:3 <- create-array\n"
      "  stash n\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: stash {n: (\"array\" \"number\" \"3\")}\n"
  );
}

void test_rewrite_stashes_of_recipe_header_products() {
  transform(
      "container foo [\n"
      "  x:num\n"
      "]\n"
      "def bar -> x:foo [\n"
      "  local-scope\n"
      "  load-ingredients\n"
      "  x <- merge 34\n"
      "  stash x\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: stash {stash_2_0: (\"address\" \"array\" \"character\")}\n"
  );
}

//: misplaced; should be in instruction inserting/deleting transforms, but has
//: prerequisites: deduce_types_from_header and check_or_set_types_by_name
:(after "Transform.push_back(deduce_types_from_header)")
Transform.push_back(convert_ingredients_to_text);  // idempotent

:(code)
void convert_ingredients_to_text(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(101, "transform") << "--- convert some ingredients to text in recipe " << caller.name << end();
  // in recipes without named locations, 'stash' is still not extensible
  if (contains_numeric_locations(caller)) return;
  convert_ingredients_to_text(caller);
}

void convert_ingredients_to_text(recipe& caller) {
  vector<instruction> new_instructions;
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    instruction& inst = caller.steps.at(i);
    // all these cases are getting hairy. how can we make this extensible?
    if (inst.name == "stash") {
      for (int j = 0;  j < SIZE(inst.ingredients);  ++j) {
        if (is_literal_text(inst.ingredients.at(j))) continue;
        ostringstream ingredient_name;
        ingredient_name << "stash_" << i << '_' << j << ":address:array:character";
        convert_ingredient_to_text(inst.ingredients.at(j), new_instructions, ingredient_name.str());
      }
    }
    else if (inst.name == "trace") {
      for (int j = /*skip*/2;  j < SIZE(inst.ingredients);  ++j) {
        if (is_literal_text(inst.ingredients.at(j))) continue;
        ostringstream ingredient_name;
        ingredient_name << "trace_" << i << '_' << j << ":address:array:character";
        convert_ingredient_to_text(inst.ingredients.at(j), new_instructions, ingredient_name.str());
      }
    }
    else if (inst.name_before_rewrite == "append") {
      // override only variants that try to append to a string
      // Beware: this hack restricts how much 'append' can be overridden. Any
      // new variants that match:
      //   append _:text, ___
      // will never ever get used.
      if (is_literal_text(inst.ingredients.at(0)) || is_mu_text(inst.ingredients.at(0))) {
        for (int j = /*skip base*/1;  j < SIZE(inst.ingredients);  ++j) {
          ostringstream ingredient_name;
          ingredient_name << "append_" << i << '_' << j << ":address:array:character";
          convert_ingredient_to_text(inst.ingredients.at(j), new_instructions, ingredient_name.str());
        }
      }
    }
    trace(103, "transform") << to_string(inst) << end();
    new_instructions.push_back(inst);
  }
  caller.steps.swap(new_instructions);
}

// add an instruction to convert reagent 'r' to text in list 'out', then
// replace r with converted text
void convert_ingredient_to_text(reagent& r, vector<instruction>& out, const string& tmp_var) {
  if (!r.type) return;  // error; will be handled elsewhere
  if (is_mu_text(r)) return;
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
  trace(103, "transform") << to_string(def) << end();
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

//: Supporting 'append' above requires remembering what name an instruction
//: had before any rewrites or transforms.
:(before "End instruction Fields")
string name_before_rewrite;
:(before "End instruction Clear")
name_before_rewrite.clear();
:(before "End next_instruction(curr)")
curr->name_before_rewrite = curr->name;

:(code)
void test_append_other_types_to_text() {
  run(
      "def main [\n"
      "  local-scope\n"
      "  n:num <- copy 11\n"
      "  c:char <- copy 111/o\n"
      "  a:text <- append [abc], 10, n, c\n"
      "  expected:text <- new [abc1011o]\n"
      "  10:bool/raw <- equal a, expected\n"
      "]\n"
  );
}

//: Make sure that the new system is strictly better than just the 'stash'
//: primitive by itself.

void test_rewrite_stash_continues_to_fall_back_to_default_implementation() {
  run(
      // type without a to-text implementation
      "container foo [\n"
      "  x:num\n"
      "  y:num\n"
      "]\n"
      "def main [\n"
      "  local-scope\n"
      "  x:foo <- merge 34, 35\n"
      "  stash x\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "app: 34 35\n"
  );
}

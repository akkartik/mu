//: Introduce a new transform to perform various checks in instructions before
//: we start running them. It'll be extensible, so that we can add checks for
//: new recipes as we extend 'run' to support them.
//:
//: Doing checking in a separate part complicates things, because the values
//: of variables in memory and the processor (current_recipe_name,
//: current_instruction) aren't available at checking time. If I had a more
//: sophisticated layer system I'd introduce the simpler version first and
//: transform it in a separate layer or set of layers.

:(after "Transform.push_back(update_instruction_operations)")
Transform.push_back(check_instruction);

:(code)
void check_instruction(const recipe_ordinal r) {
  trace(9991, "transform") << "--- perform checks for recipe " << get(Recipe, r).name << end();
//?   cerr << "--- perform checks for recipe " << get(Recipe, r).name << '\n';
  map<string, vector<type_ordinal> > metadata;
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    if (inst.is_label) continue;
    switch (inst.operation) {
      // Primitive Recipe Checks
      case COPY: {
        if (SIZE(inst.products) != SIZE(inst.ingredients)) {
          raise_error << "ingredients and products should match in '" << inst.to_string() << "'\n" << end();
          break;
        }
        for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
          if (!types_match(inst.products.at(i), inst.ingredients.at(i))) {
            raise_error << maybe(get(Recipe, r).name) << "can't copy " << inst.ingredients.at(i).original_string << " to " << inst.products.at(i).original_string << "; types don't match\n" << end();
            goto finish_checking_instruction;
          }
        }
        break;
      }
      // End Primitive Recipe Checks
      default: {
        // Defined Recipe Checks
        // End Defined Recipe Checks
      }
    }
    finish_checking_instruction:;
  }
}

:(scenario copy_checks_reagent_count)
% Hide_errors = true;
recipe main [
  1:number <- copy 34, 35
]
+error: ingredients and products should match in '1:number <- copy 34, 35'

:(scenario write_scalar_to_array_disallowed)
% Hide_errors = true;
recipe main [
  1:array:number <- copy 34
]
+error: main: can't copy 34 to 1:array:number; types don't match

:(scenario write_scalar_to_array_disallowed_2)
% Hide_errors = true;
recipe main [
  1:number, 2:array:number <- copy 34, 35
]
+error: main: can't copy 35 to 2:array:number; types don't match

:(scenario write_scalar_to_address_disallowed)
% Hide_errors = true;
recipe main [
  1:address:number <- copy 34
]
+error: main: can't copy 34 to 1:address:number; types don't match

:(code)
bool types_match(reagent lhs, reagent rhs) {
  // '_' never raises type error
  if (is_dummy(lhs)) return true;
  // to sidestep type-checking, use /raw in the source.
  // this is unsafe, and will be highlighted in red inside vim. just for some tests.
  if (is_raw(rhs)) return true;
  // allow writing 0 to any address
  if (rhs.name == "0" && is_mu_address(lhs)) return true;
  if (is_literal(rhs)) return !is_mu_array(lhs) && !is_mu_address(lhs) && size_of(rhs) == size_of(lhs);
  if (!lhs.type) return !rhs.type;
  return types_match(lhs.type, rhs.type);
}

// two types match if the second begins like the first
// (trees perform the same check recursively on each subtree)
bool types_match(type_tree* lhs, type_tree* rhs) {
  if (!lhs) return true;
  if (!rhs || rhs->value == 0) {
    if (lhs->value == get(Type_ordinal, "array")) return false;
    if (lhs->value == get(Type_ordinal, "address")) return false;
    return size_of(rhs) == size_of(lhs);
  }
  if (lhs->value != rhs->value) return false;
  return types_match(lhs->left, rhs->left) && types_match(lhs->right, rhs->right);
}

// hacky version that allows 0 addresses
bool types_match(const reagent lhs, const type_tree* rhs, const vector<double>& data) {
  if (is_dummy(lhs)) return true;
  if (rhs->value == 0) {
    if (lhs.type->value == get(Type_ordinal, "array")) return false;
    if (lhs.type->value == get(Type_ordinal, "address")) return scalar(data) && data.at(0) == 0;
    return size_of(rhs) == size_of(lhs);
  }
  if (lhs.type->value != rhs->value) return false;
  return types_match(lhs.type->left, rhs->left) && types_match(lhs.type->right, rhs->right);
}

bool is_raw(const reagent& r) {
  return has_property(r, "raw");
}

bool is_mu_array(reagent r) {
  if (!r.type) return false;
  if (is_literal(r)) return false;
  return r.type->value == get(Type_ordinal, "array");
}

bool is_mu_address(reagent r) {
  if (!r.type) return false;
  if (is_literal(r)) return false;
  return r.type->value == get(Type_ordinal, "address");
}

bool is_mu_number(reagent r) {
  if (!r.type) return false;
  if (is_literal(r))
    return r.properties.at(0).second->value == "literal-number"
        || r.properties.at(0).second->value == "literal";
  if (r.type->value == get(Type_ordinal, "character")) return true;  // permit arithmetic on unicode code points
  return r.type->value == get(Type_ordinal, "number");
}

bool is_mu_scalar(reagent r) {
  if (!r.type) return false;
  if (is_literal(r))
    return !r.properties.at(0).second || r.properties.at(0).second->value != "literal-string";
  if (is_mu_array(r)) return false;
  return size_of(r) == 1;
}

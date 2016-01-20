//: Introduce a new transform to perform various checks in instructions before
//: we start running them. It'll be extensible, so that we can add checks for
//: new recipes as we extend 'run' to support them.
//:
//: Doing checking in a separate part complicates things, because the values
//: of variables in memory and the processor (current_recipe_name,
//: current_instruction) aren't available at checking time. If I had a more
//: sophisticated layer system I'd introduce the simpler version first and
//: transform it in a separate layer or set of layers.

:(before "End Checks")
Transform.push_back(check_instruction);  // idempotent

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
          if (!types_coercible(inst.products.at(i), inst.ingredients.at(i))) {
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

:(scenario write_address_to_number_allowed)
% Hide_errors = true;
recipe main [
  1:address:number <- copy 12/unsafe
  2:number <- copy 1:address:number
]
+mem: storing 12 in location 2
$error: 0

:(code)
// types_match with some leniency
bool types_coercible(const reagent& lhs, const reagent& rhs) {
  if (types_match(lhs, rhs)) return true;
  if (is_mu_address(rhs) && is_mu_number(lhs)) return true;
  // End types_coercible Special-cases
  return false;
}

bool types_match(const reagent& lhs, const reagent& rhs) {
  // to sidestep type-checking, use /unsafe in the source.
  // this will be highlighted in red inside vim. just for setting up some tests.
  if (is_unsafe(rhs)) return true;
  if (is_literal(rhs)) {
    if (is_mu_array(lhs)) return false;
    // End Matching Types For Literal(lhs)
    // allow writing 0 to any address
    if (is_mu_address(lhs)) return rhs.name == "0";
    if (!lhs.type) return false;
    if (lhs.type->value == get(Type_ordinal, "boolean"))
      return boolean_matches_literal(lhs, rhs);
    return size_of(lhs) == 1;  // literals are always scalars
  }
  return types_strictly_match(lhs, rhs);
}

bool boolean_matches_literal(const reagent& lhs, const reagent& rhs) {
  if (!is_literal(rhs)) return false;
  if (!lhs.type) return false;
  if (lhs.type->value != get(Type_ordinal, "boolean")) return false;
  return rhs.name == "0" || rhs.name == "1";
}

// copy arguments because later layers will want to make changes to them
// without perturbing the caller
bool types_strictly_match(reagent lhs, reagent rhs) {
  if (is_literal(rhs) && lhs.type->value == get(Type_ordinal, "number")) return true;
  // to sidestep type-checking, use /unsafe in the source.
  // this will be highlighted in red inside vim. just for setting up some tests.
  if (is_unsafe(rhs)) return true;
  // '_' never raises type error
  if (is_dummy(lhs)) return true;
  if (!lhs.type) return !rhs.type;
  return types_strictly_match(lhs.type, rhs.type);
}

// two types match if the second begins like the first
// (trees perform the same check recursively on each subtree)
bool types_strictly_match(type_tree* lhs, type_tree* rhs) {
  if (!lhs) return true;
  if (!rhs) return lhs->value == 0;
  if (lhs->value != rhs->value) return false;
  return types_strictly_match(lhs->left, rhs->left) && types_strictly_match(lhs->right, rhs->right);
}

bool is_unsafe(const reagent& r) {
  return has_property(r, "unsafe");
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
  if (is_literal(r)) {
    if (!r.properties.at(0).second) return false;
    return r.properties.at(0).second->value == "literal-number"
        || r.properties.at(0).second->value == "literal";
  }
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

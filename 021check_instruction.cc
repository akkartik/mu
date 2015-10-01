//: Introduce a new transform to perform various checks in instructions before
//: we start running them. It'll be extensible, so that we can add checks for
//: new recipes as we extend 'run' to support them.

:(after "int main")
  Transform.push_back(check_instruction);

:(code)
void check_instruction(const recipe_ordinal r) {
  map<string, vector<type_ordinal> > metadata;
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    instruction& inst = Recipe[r].steps.at(i);
    switch (inst.operation) {
      // Primitive Recipe Checks
      case COPY: {
        if (SIZE(inst.products) != SIZE(inst.ingredients)) {
          raise << "ingredients and products should match in '" << inst.to_string() << "'\n" << end();
          break;
        }
        for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
          if (!types_match(inst.products.at(i), inst.ingredients.at(i))) {
            raise << maybe(Recipe[r].name) << "can't copy " << inst.ingredients.at(i).original_string << " to " << inst.products.at(i).original_string << "; types don't match\n" << end();
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
% Hide_warnings = true;
recipe main [
  1:number <- copy 34, 35
]
+warn: ingredients and products should match in '1:number <- copy 34, 35'

:(scenario write_scalar_to_array_disallowed)
% Hide_warnings = true;
recipe main [
  1:array:number <- copy 34
]
+warn: main: can't copy 34 to 1:array:number; types don't match

:(scenario write_scalar_to_array_disallowed_2)
% Hide_warnings = true;
recipe main [
  1:number, 2:array:number <- copy 34, 35
]
+warn: main: can't copy 35 to 2:array:number; types don't match

:(scenario write_scalar_to_address_disallowed)
% Hide_warnings = true;
recipe main [
  1:address:number <- copy 34
]
+warn: main: can't copy 34 to 1:address:number; types don't match

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
  // more refined types can always be copied to less refined ones
  if (SIZE(lhs.types) > SIZE(rhs.types)) return false;
  if (SIZE(lhs.types) == SIZE(rhs.types)) return lhs.types == rhs.types;
  rhs.types.resize(SIZE(lhs.types));
  return lhs.types == rhs.types;
}

bool is_raw(const reagent& r) {
  for (long long int i = /*skip value+type*/1; i < SIZE(r.properties); ++i) {
    if (r.properties.at(i).first == "raw") return true;
  }
  return false;
}

bool is_mu_array(reagent r) {
  if (is_literal(r)) return false;
  return !r.types.empty() && r.types.at(0) == Type_ordinal["array"];
}

bool is_mu_address(reagent r) {
  if (is_literal(r)) return false;
  return !r.types.empty() && r.types.at(0) == Type_ordinal["address"];
}

bool is_mu_number(reagent r) {
  if (is_literal(r))
    return r.properties.at(0).second.at(0) == "literal-number"
        || r.properties.at(0).second.at(0) == "literal";
  if (r.types.empty()) return false;
  if (r.types.at(0) == Type_ordinal["character"]) return true;  // permit arithmetic on unicode code points
  return r.types.at(0) == Type_ordinal["number"];
}

bool is_mu_scalar(reagent r) {
  if (is_literal(r))
    return r.properties.at(0).second.empty() || r.properties.at(0).second.at(0) != "literal-string";
  if (is_mu_array(r)) return false;
  return size_of(r) == 1;
}

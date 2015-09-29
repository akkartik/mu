

:(after "int main")
  Transform.push_back(check_types_by_instruction);

:(code)
void check_types_by_instruction(const recipe_ordinal r) {
  map<string, vector<type_ordinal> > metadata;
  for (long long int i = 0; i < SIZE(Recipe[r].steps); ++i) {
    instruction& inst = Recipe[r].steps.at(i);
    switch (inst.operation) {
      // Primitive Recipe Type Checks
      case COPY: {
        if (SIZE(inst.products) != SIZE(inst.ingredients)) {
          raise << "ingredients and products should match in '" << inst.to_string() << "'\n" << end();
          break;
        }
        for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
          if (!is_mu_array(inst.ingredients.at(i)) && is_mu_array(inst.products.at(i))) {
            raise << Recipe[r].name << ": can't copy " << inst.ingredients.at(i).original_string << " to array " << inst.products.at(i).original_string << "\n" << end();
            goto finish_checking_instruction;
          }
          if (is_mu_array(inst.ingredients.at(i)) && !is_mu_array(inst.products.at(i))) {
            raise << Recipe[r].name << ": can't copy array " << inst.ingredients.at(i).original_string << " to " << inst.products.at(i).original_string << "\n" << end();
            goto finish_checking_instruction;
          }
        }
        break;
      }
      // End Primitive Recipe Type Checks
      default: {
        // Defined Recipe Type Checks
        // End Defined Recipe Type Checks
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
+warn: main: can't copy 34 to array 1:array:number

:(scenario write_scalar_to_array_disallowed_2)
% Hide_warnings = true;
recipe main [
  1:number, 2:array:number <- copy 34, 35
]
+warn: main: can't copy 35 to array 2:array:number

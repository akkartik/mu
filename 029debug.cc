:(before "End Primitive Recipe Declarations")
_PRINT,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$print"] = _PRINT;
:(before "End Primitive Recipe Implementations")
case _PRINT: {
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    if (is_literal(current_instruction().ingredients.at(i))) {
      trace(Primitive_recipe_depth, "run") << "$print: " << current_instruction().ingredients.at(i).name << end();
      if (has_property(current_instruction().ingredients.at(i), "newline"))
        cout << '\n';
      else
        cout << current_instruction().ingredients.at(i).name;
    }
    else {
      for (long long int j = 0; j < SIZE(ingredients.at(i)); ++j) {
        trace(Primitive_recipe_depth, "run") << "$print: " << ingredients.at(i).at(j) << end();
        if (j > 0) cout << " ";
        cout << ingredients.at(i).at(j);
      }
    }
  }
  break;
}

:(before "End Primitive Recipe Declarations")
_EXIT,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$exit"] = _EXIT;
:(before "End Primitive Recipe Implementations")
case _EXIT: {
  exit(0);
  break;
}

:(scenario assert)
% Hide_warnings = true;  // '%' lines insert arbitrary C code into tests before calling 'run' with the lines below. Must be immediately after :(scenario) line.
recipe main [
  assert 0:literal, [this is an assert in mu]
]
+warn: this is an assert in mu

:(before "End Primitive Recipe Declarations")
ASSERT,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["assert"] = ASSERT;
:(before "End Primitive Recipe Implementations")
case ASSERT: {
  if (SIZE(ingredients) != 2) {
    raise << current_recipe_name() << ": 'assert' takes exactly two ingredients rather than '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << current_recipe_name() << ": 'assert' requires a boolean for its first ingredient, but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(1))) {
    raise << current_recipe_name() << ": 'assert' requires a literal string for its second ingredient, but got " << current_instruction().ingredients.at(1).original_string << '\n' << end();
    break;
  }
  if (!ingredients.at(0).at(0)) {
    raise << current_instruction().ingredients.at(1).name << '\n' << end();
  }
  break;
}

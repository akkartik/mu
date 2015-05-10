:(scenario assert)
% Hide_warnings = true;
recipe main [
  assert 0:literal, [this is an assert in mu]
]
+warn: this is an assert in mu

:(before "End Primitive Recipe Declarations")
ASSERT,
:(before "End Primitive Recipe Numbers")
Recipe_number["assert"] = ASSERT;
:(before "End Primitive Recipe Implementations")
case ASSERT: {
  assert(ingredients.size() == 2);
  assert(ingredients.at(0).size() == 1);  // scalar
  if (!ingredients.at(0).at(0)) {
    assert(isa_literal(current_instruction().ingredients.at(1)));
//?     tb_shutdown(); //? 1
    raise << current_instruction().ingredients.at(1).name << '\n' << die();
//?     exit(0); //? 1
  }
  break;
}

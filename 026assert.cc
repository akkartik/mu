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
  assert(!current_instruction().ingredients.empty());
  trace("run") << "ingredient 0 is " << current_instruction().ingredients[0].name;
  vector<long long int> arg0 = read_memory(current_instruction().ingredients[0]);
  assert(arg0.size() == 1);
  if (arg0[0] == 0)
    raise << current_instruction().ingredients[1].name << '\n';
  break;
}

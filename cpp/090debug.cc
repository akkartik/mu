//: Recipe to look at elements of containers.

:(before "End Primitive Recipe Declarations")
_PRINT,
:(before "End Primitive Recipe Numbers")
Recipe_number["$print"] = _PRINT;
:(before "End Primitive Recipe Implementations")
case _PRINT: {
  if (isa_literal(current_instruction().ingredients[0])) {
    trace("run") << "$print: " << current_instruction().ingredients[0].name;
    cout << current_instruction().ingredients[0].name;
    break;
  }
  vector<int> result(read_memory(current_instruction().ingredients[0]));
  for (size_t i = 0; i < result.size(); ++i) {
    trace("run") << "$print: " << result[i];
    if (i > 0) cout << " ";
    cout << result[i];
  }
  break;
}

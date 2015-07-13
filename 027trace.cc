//: Allow mu programs to log facts just like we've been doing in C++ so far.

:(scenario trace)
recipe main [
  trace [foo], [this is a trace in mu]
]
+foo: this is a trace in mu

:(before "End Primitive Recipe Declarations")
TRACE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["trace"] = TRACE;
:(before "End Primitive Recipe Implementations")
case TRACE: {
  assert(is_literal(current_instruction().ingredients.at(0)));
  string label = current_instruction().ingredients.at(0).name;
  assert(is_literal(current_instruction().ingredients.at(1)));
  string message = current_instruction().ingredients.at(1).name;
  trace(1, label) << message;
  break;
}

:(before "End Primitive Recipe Declarations")
HIDE_WARNINGS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["hide-warnings"] = HIDE_WARNINGS;
:(before "End Primitive Recipe Implementations")
case HIDE_WARNINGS: {
  Hide_warnings = true;
  break;
}

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

:(before "End Primitive Recipe Declarations")
_START_TRACING,
:(before "End Primitive Recipe Numbers")
Recipe_number["$start-tracing"] = _START_TRACING;
:(before "End Primitive Recipe Implementations")
case _START_TRACING: {
  Trace_stream->dump_layer = "all";
//?   cout << Trace_stream << ": " << Trace_stream->dump_layer << '\n'; //? 1
  break;
}

:(before "End Primitive Recipe Declarations")
_STOP_TRACING,
:(before "End Primitive Recipe Numbers")
Recipe_number["$stop-tracing"] = _STOP_TRACING;
:(before "End Primitive Recipe Implementations")
case _STOP_TRACING: {
  Trace_stream->dump_layer = "";
  break;
}

:(before "End Primitive Recipe Declarations")
_EXIT,
:(before "End Primitive Recipe Numbers")
Recipe_number["$exit"] = _EXIT;
:(before "End Primitive Recipe Implementations")
case _EXIT: {
  exit(0);
  break;
}

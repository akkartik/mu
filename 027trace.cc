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

:(before "End Primitive Recipe Declarations")
SHOW_WARNINGS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["show-warnings"] = SHOW_WARNINGS;
:(before "End Primitive Recipe Implementations")
case SHOW_WARNINGS: {
  Hide_warnings = false;
  break;
}

//: helpers for debugging

:(before "End Primitive Recipe Declarations")
_START_TRACING,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$start-tracing"] = _START_TRACING;
:(before "End Primitive Recipe Implementations")
case _START_TRACING: {
  if (current_instruction().ingredients.empty())
    Trace_stream->dump_layer = "all";
  else
    Trace_stream->dump_layer = current_instruction().ingredients.at(0).name;
//?   cout << Trace_stream << ": " << Trace_stream->dump_layer << '\n'; //? 1
  break;
}

:(before "End Primitive Recipe Declarations")
_STOP_TRACING,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$stop-tracing"] = _STOP_TRACING;
:(before "End Primitive Recipe Implementations")
case _STOP_TRACING: {
  Trace_stream->dump_layer = "";
  break;
}

:(before "End Primitive Recipe Declarations")
_CLOSE_TRACE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$close-trace"] = _CLOSE_TRACE;
:(before "End Primitive Recipe Implementations")
case _CLOSE_TRACE: {
  if (Trace_stream) {
    delete Trace_stream;
    Trace_stream = NULL;
  }
  break;
}

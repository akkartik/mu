//: Recipe to look at elements of containers.

:(before "End Primitive Recipe Declarations")
_PRINT,
:(before "End Primitive Recipe Numbers")
Recipe_number["$print"] = _PRINT;
:(before "End Primitive Recipe Implementations")
case _PRINT: {
  for (index_t i = 0; i < ingredients.size(); ++i) {
    if (isa_literal(current_instruction().ingredients.at(i))) {
      trace("run") << "$print: " << current_instruction().ingredients.at(i).name;
      cout << current_instruction().ingredients.at(i).name;
    }
    else {
      for (index_t j = 0; j < ingredients.at(i).size(); ++j) {
        trace("run") << "$print: " << ingredients.at(i).at(j);
        if (j > 0) cout << " ";
        cout << ingredients.at(i).at(j);
      }
    }
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

:(before "End Primitive Recipe Declarations")
_DUMP_LAYER,
:(before "End Primitive Recipe Numbers")
Recipe_number["$dump-layer"] = _DUMP_LAYER;
:(before "End Primitive Recipe Implementations")
case _DUMP_LAYER: {
  Trace_stream->dump_layer = current_instruction().ingredients.at(0).name;
  break;
}

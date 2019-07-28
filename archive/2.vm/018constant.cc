//: A few literal constants.

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-boolean", 0);

//: 'true'

:(code)
void test_true() {
  load(
      "def main [\n"
      "  1:boolean <- copy true\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {true: \"literal-boolean\"}\n"
  );
}

:(before "End Parsing reagent")
if (name == "true") {
  if (type != NULL) {
    raise << "'true' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-boolean");
  set_value(1);
}

//: 'false'

:(code)
void test_false() {
  load(
      "def main [\n"
      "  1:boolean <- copy false\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {false: \"literal-boolean\"}\n"
  );
}

:(before "End Parsing reagent")
if (name == "false") {
  if (type != NULL) {
    raise << "'false' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-boolean");
  set_value(0);
}

//: 'null'

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-address", 0);

:(code)
void test_null() {
  load(
      "def main [\n"
      "  1:address:number <- copy null\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse:   ingredient: {null: \"literal-address\"}\n"
  );
}

:(before "End Parsing reagent")
if (name == "null") {
  if (type != NULL) {
    raise << "'null' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-address");
  set_value(0);
}

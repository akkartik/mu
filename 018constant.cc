//: A few literal constants.

:(scenarios load)  // use 'load' instead of 'run' in all scenarios in this layer

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-boolean", 0);

//: 'true'

:(scenario true)
def main [
  1:boolean <- copy true
]
+parse:   ingredient: {true: "literal-boolean"}

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

:(scenario false)
def main [
  1:boolean <- copy false
]
+parse:   ingredient: {false: "literal-boolean"}

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

:(scenario null)
def main [
  1:address:number <- copy null
]
+parse:   ingredient: {null: "literal-address"}

:(before "End Parsing reagent")
if (name == "null") {
  if (type != NULL) {
    raise << "'null' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-address");
  set_value(0);
}

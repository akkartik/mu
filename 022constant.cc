//: A few literal constants.

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-boolean", 0);

:(scenario true)
def main [
  1:boolean <- copy true
]
+mem: storing 1 in location 1

:(before "End Parsing reagent")
if (name == "true") {
  if (type != NULL) {
    raise << "'true' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-boolean");
  set_value(1);
}
:(before "End Literal types_match Special-cases")
if (is_mu_boolean(to)) return from.name == "false" || from.name == "true";

:(scenario false)
def main [
  1:boolean <- copy false
]
+mem: storing 0 in location 1

:(before "End Parsing reagent")
if (name == "false") {
  if (type != NULL) {
    raise << "'false' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-boolean");
  set_value(0);
}

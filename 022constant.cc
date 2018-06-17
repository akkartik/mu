//: A few literal constants.

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-boolean", 0);

//: 'true'

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

//: 'false'

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

//: 'null'

:(scenario null)
def main [
  1:address:number <- copy null
]
+mem: storing 0 in location 1

:(scenario null_has_wildcard_type)
def main [
  1:address:boolean <- copy null
]
+mem: storing 0 in location 1

:(before "End Mu Types Initialization")
put(Type_ordinal, "literal-address", 0);

:(before "End Parsing reagent")
if (name == "null") {
  if (type != NULL) {
    raise << "'null' is a literal and can't take a type\n" << end();
    return;
  }
  type = new type_tree("literal-address");
  set_value(0);
}

:(before "End Literal->Address types_match(from) Special-cases")
// allow writing null to any address
if (from.name == "null") return true;

//: scenarios for type abbreviations that we couldn't write until now

:(scenario type_abbreviation_for_compound)
type foo = address:number
def main [
  1:foo <- copy null
]
+transform: product type after expanding abbreviations: ("address" "number")

:(scenario use_type_abbreviations_when_declaring_type_abbreviations)
type foo = &:num
def main [
  1:foo <- copy null
]
+transform: product type after expanding abbreviations: ("address" "number")

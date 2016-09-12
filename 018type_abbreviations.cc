//: For convenience, make some common types shorter.

:(scenario type_abbreviations)
type foo = number
def main [
  a:foo <- copy 34
]
+run: {a: "number"} <- copy {34: "literal"}

//:: Allow type abbreviations to be defined in mu code.

:(before "End Globals")
map<string, type_tree*> Type_abbreviations, Type_abbreviations_snapshot;
:(before "End save_snapshots")
Type_abbreviations_snapshot = Type_abbreviations;
:(before "End restore_snapshots")
restore_type_abbreviations();
:(code)
void restore_type_abbreviations() {
  for (map<string, type_tree*>::iterator p = Type_abbreviations.begin(); p != Type_abbreviations.end(); ++p) {
    if (!contains_key(Type_abbreviations_snapshot, p->first))
      delete p->second;
  }
  Type_abbreviations.clear();
  Type_abbreviations = Type_abbreviations_snapshot;
}

:(before "End Command Handlers")
else if (command == "type") {
  load_type_abbreviations(in);
}

:(code)
void load_type_abbreviations(istream& in) {
  string new_type_name = next_word(in);
  assert(has_data(in) || !new_type_name.empty());
  if (!has_data(in) || new_type_name.empty()) {
    raise << "incomplete 'type' statement; must be of the form 'type <new type name> = <type expression>'\n" << end();
    return;
  }
  string arrow = next_word(in);
  assert(has_data(in) || !arrow.empty());
  if (arrow.empty()) {
    raise << "incomplete 'type' statement 'type " << new_type_name << "'\n" << end();
    return;
  }
  if (arrow != "=") {
    raise << "'type' statements must be of the form 'type <new type name> = <type expression>' but got 'type " << new_type_name << ' ' << arrow << "'\n" << end();
    return;
  }
  if (!has_data(in)) {
    raise << "incomplete 'type' statement 'type " << new_type_name << " ='\n" << end();
    return;
  }
  string old = next_word(in);
  if (old.empty()) {
    raise << "incomplete 'type' statement 'type " << new_type_name << " ='\n" << end();
    raise << "'type' statements must be of the form 'type <new type name> = <type expression>' but got 'type " << new_type_name << ' ' << arrow << "'\n" << end();
    return;
  }
  if (contains_key(Type_abbreviations, new_type_name)) {
    raise << "'type' conflict: '" << new_type_name << "' defined as both '" << names_to_string_without_quotes(get(Type_abbreviations, new_type_name)) << "' and '" << old << "'\n" << end();
    return;
  }
  trace(9990, "type") << "alias " << new_type_name << " = " << old << end();
  type_tree* old_type = new_type_tree(old);
  put(Type_abbreviations, new_type_name, old_type);
}

type_tree* new_type_tree(const string& x) {
  string_tree* type_names = starts_with(x, "(") ? parse_string_tree(x) : parse_string_list(x);
  type_tree* result = new_type_tree(type_names);
  delete type_names;
  expand_type_abbreviations(result);
  return result;
}

string_tree* parse_string_list(const string& s) {
  istringstream in(s);
  in >> std::noskipws;
  return parse_property_list(in);
}

:(scenario type_error1)
% Hide_errors = true;
type foo
+error: incomplete 'type' statement 'type foo'

:(scenario type_error2)
% Hide_errors = true;
type foo =
+error: incomplete 'type' statement 'type foo ='

:(scenario type_error3)
% Hide_errors = true;
type foo bar baz
+error: 'type' statements must be of the form 'type <new type name> = <type expression>' but got 'type foo bar'

:(scenario type_conflict_error)
% Hide_errors = true;
type foo = bar
type foo = baz
+error: 'type' conflict: 'foo' defined as both 'bar' and 'baz'

:(scenario type_abbreviation_for_compound)
type foo = address:number
def main [
  a:foo <- copy 0
]
+run: {a: ("address" "number")} <- copy {0: "literal"}

//:: A few default abbreviations.

:(before "End Mu Types Initialization")
put(Type_abbreviations, "&", new type_tree("address"));
put(Type_abbreviations, "@", new type_tree("array"));
put(Type_abbreviations, "num", new type_tree("number"));
put(Type_abbreviations, "bool", new type_tree("boolean"));
put(Type_abbreviations, "char", new type_tree("character"));

:(scenario use_type_abbreviations_when_declaring_type_abbreviations)
type foo = &:num
def main [
  a:foo <- copy 0
]
+run: {a: ("address" "number")} <- copy {0: "literal"}

//:: Expand type aliases before running.
//: We'll do this in a transform so that we don't need to define abbreviations
//: before we use them.

:(scenarios transform)
:(scenario abbreviations_for_address_and_array)
def main [
  f 1:&:number  # abbreviation for 'address:number'
  f 2:@:number  # abbreviation for 'array:number'
  f 3:&:@:number  # combining '&' and '@'
  f 4:&:&:@:&:@:number  # ..any number of times
  f {5: (array (& number) 3)}  # support for dilated reagents and more complex parse trees
]
def f [
]
+transform: --- expand type abbreviations in recipe 'main'
+transform: ingredient type after expanding abbreviations: ("address" "number")
+transform: ingredient type after expanding abbreviations: ("array" "number")
+transform: ingredient type after expanding abbreviations: ("address" "array" "number")
+transform: ingredient type after expanding abbreviations: ("address" "address" "array" "address" "array" "number")
+transform: ingredient type after expanding abbreviations: ("array" ("address" "number") "3")

:(before "Transform.push_back(update_instruction_operations)")
// Begin Type Modifying Transforms
Transform.push_back(expand_type_abbreviations);  // idempotent
// End Type Modifying Transforms

:(code)
void expand_type_abbreviations(const recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- expand type abbreviations in recipe '" << caller.name << "'" << end();
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    trace(9991, "transform") << "instruction '" << inst.original_string << end();
    for (long int i = 0; i < SIZE(inst.ingredients); ++i) {
      expand_type_abbreviations(inst.ingredients.at(i).type);
      trace(9992, "transform") << "ingredient type after expanding abbreviations: " << names_to_string(inst.ingredients.at(i).type) << end();
    }
    for (long int i = 0; i < SIZE(inst.products); ++i) {
      expand_type_abbreviations(inst.products.at(i).type);
      trace(9992, "transform") << "product type after expanding abbreviations: " << names_to_string(inst.products.at(i).type) << end();
    }
  }
}

void expand_type_abbreviations(type_tree* type) {
  if (!type) return;
  if (!type->atom) {
    expand_type_abbreviations(type->left);
    expand_type_abbreviations(type->right);
    return;
  }
  if (contains_key(Type_abbreviations, type->name))
    *type = type_tree(*get(Type_abbreviations, type->name));
}

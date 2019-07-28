//: For convenience, allow Mu types to be abbreviated.

void test_type_abbreviations() {
  transform(
      "type foo = number\n"
      "def main [\n"
      "  a:foo <- copy 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: product type after expanding abbreviations: \"number\"\n"
  );
}

:(before "End Globals")
map<string, type_tree*> Type_abbreviations, Type_abbreviations_snapshot;

//:: Defining type abbreviations.

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
  trace(100, "type") << "alias " << new_type_name << " = " << old << end();
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

void test_type_error1() {
  Hide_errors = true;
  transform(
      "type foo\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: incomplete 'type' statement 'type foo'\n"
  );
}

void test_type_error2() {
  Hide_errors = true;
  transform(
      "type foo =\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: incomplete 'type' statement 'type foo ='\n"
  );
}

void test_type_error3() {
  Hide_errors = true;
  transform(
      "type foo bar baz\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: 'type' statements must be of the form 'type <new type name> = <type expression>' but got 'type foo bar'\n"
  );
}

void test_type_conflict_error() {
  Hide_errors = true;
  transform(
      "type foo = bar\n"
      "type foo = baz\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: 'type' conflict: 'foo' defined as both 'bar' and 'baz'\n"
  );
}

void test_type_abbreviation_for_compound() {
  transform(
      "type foo = address:number\n"
      "def main [\n"
      "  1:foo <- copy null\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: product type after expanding abbreviations: (\"address\" \"number\")\n"
  );
}

//: cleaning up type abbreviations between tests and before exiting

:(before "End save_snapshots")
Type_abbreviations_snapshot = Type_abbreviations;
:(before "End restore_snapshots")
restore_type_abbreviations();
:(before "End One-time Setup")
atexit(clear_type_abbreviations);
:(code)
void restore_type_abbreviations() {
  for (map<string, type_tree*>::iterator p = Type_abbreviations.begin();  p != Type_abbreviations.end();  ++p) {
    if (!contains_key(Type_abbreviations_snapshot, p->first))
      delete p->second;
  }
  Type_abbreviations.clear();
  Type_abbreviations = Type_abbreviations_snapshot;
}
void clear_type_abbreviations() {
  for (map<string, type_tree*>::iterator p = Type_abbreviations.begin();  p != Type_abbreviations.end();  ++p)
    delete p->second;
  Type_abbreviations.clear();
}

//:: A few default abbreviations.

:(before "End Mu Types Initialization")
put(Type_abbreviations, "&", new_type_tree("address"));
put(Type_abbreviations, "@", new_type_tree("array"));
put(Type_abbreviations, "num", new_type_tree("number"));
put(Type_abbreviations, "bool", new_type_tree("boolean"));
put(Type_abbreviations, "char", new_type_tree("character"));

:(code)
void test_use_type_abbreviations_when_declaring_type_abbreviations() {
  transform(
      "type foo = &:num\n"
      "def main [\n"
      "  1:foo <- copy null\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: product type after expanding abbreviations: (\"address\" \"number\")\n"
  );
}

//:: Expand type aliases before running.
//: We'll do this in a transform so that we don't need to define abbreviations
//: before we use them.

void test_abbreviations_for_address_and_array() {
  transform(
      "def main [\n"
      "  f 1:&:num\n"  // abbreviation for 'address:number'
      "  f 2:@:num\n"  // abbreviation for 'array:number'
      "  f 3:&:@:num\n"  // combining '&' and '@'
      "  f 4:&:&:@:&:@:num\n"  // ..any number of times
      "  f {5: (array (& num) 3)}\n"  // support for dilated reagents and more complex parse trees
      "]\n"
      "def f [\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: --- expand type abbreviations in recipe 'main'\n"
      "transform: ingredient type after expanding abbreviations: (\"address\" \"number\")\n"
      "transform: ingredient type after expanding abbreviations: (\"array\" \"number\")\n"
      "transform: ingredient type after expanding abbreviations: (\"address\" \"array\" \"number\")\n"
      "transform: ingredient type after expanding abbreviations: (\"address\" \"address\" \"array\" \"address\" \"array\" \"number\")\n"
      "transform: ingredient type after expanding abbreviations: (\"array\" (\"address\" \"number\") \"3\")\n"
  );
}

:(before "Transform.push_back(update_instruction_operations)")
Transform.push_back(expand_type_abbreviations);  // idempotent
// Begin Type Modifying Transforms
// End Type Modifying Transforms

:(code)
void expand_type_abbreviations(const recipe_ordinal r) {
  expand_type_abbreviations(get(Recipe, r));
}

void expand_type_abbreviations(const recipe& caller) {
  trace(101, "transform") << "--- expand type abbreviations in recipe '" << caller.name << "'" << end();
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    const instruction& inst = caller.steps.at(i);
    trace(102, "transform") << "instruction '" << to_original_string(inst) << end();
    for (long int i = 0;  i < SIZE(inst.ingredients);  ++i) {
      expand_type_abbreviations(inst.ingredients.at(i).type);
      trace(102, "transform") << "ingredient type after expanding abbreviations: " << names_to_string(inst.ingredients.at(i).type) << end();
    }
    for (long int i = 0;  i < SIZE(inst.products);  ++i) {
      expand_type_abbreviations(inst.products.at(i).type);
      trace(102, "transform") << "product type after expanding abbreviations: " << names_to_string(inst.products.at(i).type) << end();
    }
  }
  // End Expand Type Abbreviations(caller)
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

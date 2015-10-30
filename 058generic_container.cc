//:: Container definitions can contain type parameters.
//:
//: Extremely hacky initial implementation:
//:
//: a) We still don't support the full complexity of type trees inside
//: container definitions. So for example you can't have a container element
//: with this type:
//:   (map (array address character) (list number))
//:
//: b) We also can't include type parameters anywhere except at the top of the
//: type of a container element.

:(scenario size_of_generic_container)
container foo:_t [
  x:_t
  y:number
]
recipe main [
  1:foo:number <- merge 12, 13
  3:foo:point <- merge 14, 15, 16
]
+mem: storing 12 in location 1
+mem: storing 13 in location 2
+mem: storing 14 in location 3
+mem: storing 15 in location 4
+mem: storing 16 in location 5

:(before "End Globals")
// We'll use large type ordinals to mean "the following type of the variable".
const int START_TYPE_INGREDIENTS = 2000;
:(before "End Test Run Initialization")
assert(Next_type_ordinal < START_TYPE_INGREDIENTS);

:(before "End type_info Fields")
map<string, type_ordinal> type_ingredient_names;

:(before "End container Name Refinements")
if (name.find(':') != string::npos) {
  trace(9999, "parse") << "container has type ingredients; parsing" << end();
  read_type_ingredients(name);
}

:(code)
void read_type_ingredients(string& name) {
  string save_name = name;
  istringstream in(save_name);
  name = slurp_until(in, ':');
  if (Type_ordinal.find(name) == Type_ordinal.end() || Type_ordinal[name] == 0)
    Type_ordinal[name] = Next_type_ordinal++;
  type_info& info = Type[Type_ordinal[name]];
  long long int next_type_ordinal = START_TYPE_INGREDIENTS;
  while (!in.eof()) {
    string curr = slurp_until(in, ':');
    if (info.type_ingredient_names.find(curr) != info.type_ingredient_names.end()) {
      raise_error << "can't repeat type ingredient names in a single container definition\n" << end();
      return;
    }
    info.type_ingredient_names[curr] = next_type_ordinal++;
  }
}

:(before "End insert_container Special Uses(type_name)")
// check for use of type ingredients
if (type_name.at(0) == '_') {
  *curr_type = new type_tree(info.type_ingredient_names[type_name]);
  trace(9999, "parse") << "  type: " << info.type_ingredient_names[type_name] << end();
  continue;
}

:(before "End Container Type Checks")
if (type->value >= START_TYPE_INGREDIENTS
    && (type->value - START_TYPE_INGREDIENTS) < SIZE(Type[type->value].type_ingredient_names))
  return;

:(before "End size_of(type) Container Cases")
if (t.elements.at(i)->value >= START_TYPE_INGREDIENTS) {
  trace(9999, "type") << "checking size of type ingredient\n";
  result += size_of_type_ingredient(t.elements.at(i)->value - START_TYPE_INGREDIENTS,
                                    type->right);
  continue;
}

:(code)
// generic version of size_of
long long int size_of_type_ingredient(long long int type_ingredient_index, const type_tree* rest_of_type) {
  const type_tree* curr = rest_of_type;
  while (type_ingredient_index > 0) {
    assert(curr);
    --type_ingredient_index;
    curr = curr->right;
  }
  assert(curr);
  assert(!curr->left);  // unimplemented
  trace(9999, "type") << "type deduced to be " << Type[curr->value].name << "$\n";
  type_tree tmp(curr->value);
  if (curr->right)
    tmp.right = new type_tree(*curr->right);
  return size_of(&tmp);
}

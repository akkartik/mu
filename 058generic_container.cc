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

//: Suppress unknown type checks in generic containers.

:(before "Check Container Field Types(info)")
if (!info.type_ingredient_names.empty()) continue;

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
  if (!contains_key(Type_ordinal, name) || get(Type_ordinal, name) == 0)
    put(Type_ordinal, name, Next_type_ordinal++);
  type_info& info = get_or_insert(Type, get(Type_ordinal, name));
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
    && (type->value - START_TYPE_INGREDIENTS) < SIZE(get(Type, type->value).type_ingredient_names))
  return;

:(before "End size_of(type) Container Cases")
if (t.elements.at(i)->value >= START_TYPE_INGREDIENTS) {
  trace(9999, "type") << "checking size of type ingredient\n" << end();
  long long int size = size_of_type_ingredient(t.elements.at(i), type->right);
  if (!size) {
    ostringstream out;
    dump_types(type, out);
    raise_error << "illegal type '" << out.str() << "' seems to be missing a type ingredient or three\n" << end();
  }
  result += size_of_type_ingredient(t.elements.at(i), type->right);
  continue;
}

:(code)
// generic version of size_of
long long int size_of_type_ingredient(const type_tree* element_template, const type_tree* rest_of_use) {
  long long int type_ingredient_index = element_template->value - START_TYPE_INGREDIENTS;
  const type_tree* curr = rest_of_use;
  if (!curr) return 0;
  while (type_ingredient_index > 0) {
    --type_ingredient_index;
    curr = curr->right;
    if (!curr) return 0;
  }
  assert(curr);
  assert(!curr->left);  // unimplemented
  trace(9999, "type") << "type deduced to be " << get(Type, curr->value).name << "$" << end();
  type_tree tmp(curr->value);
  if (curr->right)
    tmp.right = new type_tree(*curr->right);
  return size_of(&tmp);
}

:(scenario get_on_generic_container)
container foo:_t [
  x:_t
  y:number
]
recipe main [
  1:foo:point <- merge 14, 15, 16
  2:number <- get 1:foo:point, y:offset
]
+mem: storing 16 in location 2

:(before "End GET field Cases")
if (get(Type, base_type).elements.at(i)->value >= START_TYPE_INGREDIENTS) {
  src += size_of_type_ingredient(get(Type, base_type).elements.at(i), base.type->right);
  continue;
}

:(scenario get_on_generic_container_2)
container foo:_t [
  x:_t
  y:number
]
recipe main [
  1:foo:point <- merge 14, 15, 16
  2:point <- get 1:foo:point, x:offset
]
+mem: storing 14 in location 2
+mem: storing 15 in location 3

:(before "End element_type Special-cases")
if (contains_type_ingredient(element)) {
  if (!canonized_base.type->right) {
    raise_error << "illegal type '" << dump_types(canonized_base) << "' seems to be missing a type ingredient or three\n" << end();
  }
  replace_type_ingredients(element.type, canonized_base.type->right);
}

:(code)
bool contains_type_ingredient(const reagent& x) {
  return contains_type_ingredient(x.type);
}

bool contains_type_ingredient(const type_tree* type) {
  if (!type) return false;
  if (type->value >= START_TYPE_INGREDIENTS) return true;
  return contains_type_ingredient(type->left) || contains_type_ingredient(type->right);
}

void replace_type_ingredients(type_tree* element_type, type_tree* callsite_type) {
  if (!callsite_type) return;  // error but it's already been raised above
  if (!element_type) return;
  if (element_type->value >= START_TYPE_INGREDIENTS) {
    if (!has_nth_type(callsite_type, element_type->value-START_TYPE_INGREDIENTS)) {
      ostringstream out;
      dump_types(callsite_type, out);
      raise_error << "illegal type '" << out.str() << "' seems to be missing a type ingredient or three\n" << end();
      return;
    }
    element_type->value = nth_type(callsite_type, element_type->value-START_TYPE_INGREDIENTS);
  }
  replace_type_ingredients(element_type->right, callsite_type);
}

type_ordinal nth_type(type_tree* base, long long int n) {
  assert(n >= 0);
  if (n == 0) return base->value;  // todo: base->left
  return nth_type(base->right, n-1);
}

bool has_nth_type(type_tree* base, long long int n) {
  assert(n >= 0);
  if (base == NULL) return false;
  if (n == 0) return true;
  return has_nth_type(base->right, n-1);
}

:(scenario get_on_generic_container_error)
% Hide_errors = true;
container foo:_t [
  x:_t
  y:number
]
recipe main [
  10:foo:point <- merge 14, 15, 16
  1:number <- get 10:foo, 1:offset
]
+error: illegal type 'foo' seems to be missing a type ingredient or three

//: get-address similarly

:(scenario get_address_on_generic_container)
container foo:_t [
  x:_t
  y:number
]
recipe main [
  10:foo:point <- merge 14, 15, 16
  1:address:number <- get-address 10:foo:point, 1:offset
]
+mem: storing 12 in location 1

:(before "End GET_ADDRESS field Cases")
if (get(Type, base_type).elements.at(i)->value >= START_TYPE_INGREDIENTS) {
  result += size_of_type_ingredient(get(Type, base_type).elements.at(i), base.type->right);
  continue;
}

:(scenario get_on_generic_container_inside_generic_container)
container foo:_t [
  x:_t
  y:number
]
container bar [
  x:foo:point
  y:number
]
recipe main [
  1:bar <- merge 14, 15, 16, 17
  2:number <- get 1:bar, 1:offset
]
+mem: storing 17 in location 2

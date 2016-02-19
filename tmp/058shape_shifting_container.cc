//:: Container definitions can contain 'type ingredients'

:(scenario size_of_shape_shifting_container)
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

:(scenario size_of_shape_shifting_container_2)
% Hide_errors = true;
# multiple type ingredients
container foo:_a:_b [
  x:_a
  y:_b
]
recipe main [
  1:foo:number:boolean <- merge 34, 1/true
]
$error: 0

:(scenario size_of_shape_shifting_container_3)
% Hide_errors = true;
container foo:_a:_b [
  x:_a
  y:_b
]
recipe main [
  1:address:shared:array:character <- new [abc]
  # compound types for type ingredients
  {2: (foo number (address shared array character))} <- merge 34/x, 1:address:shared:array:character/y
]
$error: 0

:(scenario size_of_shape_shifting_container_4)
% Hide_errors = true;
container foo:_a:_b [
  x:_a
  y:_b
]
container bar:_a:_b [
  # dilated element
  {data: (foo _a (address shared _b))}
]
recipe main [
  1:address:shared:array:character <- new [abc]
  2:bar:number:array:character <- merge 34/x, 1:address:shared:array:character/y
]
$error: 0

:(before "End Globals")
// We'll use large type ordinals to mean "the following type of the variable".
const int START_TYPE_INGREDIENTS = 2000;
:(before "End Test Run Initialization")
assert(Next_type_ordinal < START_TYPE_INGREDIENTS);

:(before "End type_info Fields")
map<string, type_ordinal> type_ingredient_names;

//: Suppress unknown type checks in shape-shifting containers.

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
  while (has_data(in)) {
    string curr = slurp_until(in, ':');
    if (info.type_ingredient_names.find(curr) != info.type_ingredient_names.end()) {
      raise_error << "can't repeat type ingredient names in a single container definition\n" << end();
      return;
    }
    put(info.type_ingredient_names, curr, next_type_ordinal++);
  }
}

:(before "End insert_container Special-cases")
// check for use of type ingredients
else if (!properties->value.empty() && properties->value.at(0) == '_') {
  result->value = get(info.type_ingredient_names, properties->value);
}

:(before "End Container Type Checks")
if (type->value >= START_TYPE_INGREDIENTS
    && (type->value - START_TYPE_INGREDIENTS) < SIZE(get(Type, type->value).type_ingredient_names))
  return;

:(scenario size_of_shape_shifting_exclusive_container)
exclusive-container foo:_t [
  x:_t
  y:number
]
recipe main [
  1:foo:number <- merge 0/x, 34
  3:foo:point <- merge 0/x, 15, 16
  6:foo:point <- merge 1/y, 23
]
+mem: storing 0 in location 1
+mem: storing 34 in location 2
+mem: storing 0 in location 3
+mem: storing 15 in location 4
+mem: storing 16 in location 5
+mem: storing 1 in location 6
+mem: storing 23 in location 7
$mem: 7

:(code)
// shape-shifting version of size_of
long long int size_of_type_ingredient(const type_tree* element_template, const type_tree* rest_of_use) {
  type_tree* element_type = type_ingredient(element_template, rest_of_use);
  if (!element_type) return 0;
  long long int result = size_of(element_type);
  delete element_type;
  return result;
}

type_tree* type_ingredient(const type_tree* element_template, const type_tree* rest_of_use) {
  long long int type_ingredient_index = element_template->value - START_TYPE_INGREDIENTS;
  const type_tree* curr = rest_of_use;
  if (!curr) return NULL;
  while (type_ingredient_index > 0) {
    --type_ingredient_index;
    curr = curr->right;
    if (!curr) return NULL;
  }
  assert(curr);
  if (curr->left) curr = curr->left;
  assert(curr->value > 0);
  trace(9999, "type") << "type deduced to be " << get(Type, curr->value).name << "$" << end();
  return new type_tree(*curr);
}

:(scenario get_on_shape_shifting_container)
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
const type_tree* type = get(Type, base_type).elements.at(i).type;
if (type->value >= START_TYPE_INGREDIENTS) {
  long long int size = size_of_type_ingredient(type, base.type->right);
  if (!size)
    raise_error << "illegal field type '" << debug_string(type) << "' seems to be missing a type ingredient or three\n" << end();
  src += size;
  continue;
}

:(scenario get_on_shape_shifting_container_2)
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

:(scenario get_on_shape_shifting_container_3)
container foo:_t [
  x:_t
  y:number
]
recipe main [
  1:foo:address:point <- merge 34/unsafe, 48
  2:address:point <- get 1:foo:address:point, x:offset
]
+mem: storing 34 in location 2

:(scenario get_on_shape_shifting_container_inside_container)
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

:(scenario get_on_complex_shape_shifting_container)
container foo:_a:_b [
  x:_a
  y:_b
]
recipe main [
  1:address:shared:array:character <- new [abc]
  {2: (foo number (address shared array character))} <- merge 34/x, 1:address:shared:array:character/y
  3:address:shared:array:character <- get {2: (foo number (address shared array character))}, y:offset
  4:boolean <- equal 1:address:shared:array:character, 3:address:shared:array:character
]
+mem: storing 1 in location 4

:(before "End element_type Special-cases")
if (contains_type_ingredient(element)) {
  if (!canonized_base.type->right)
    raise_error << "illegal type '" << debug_string(canonized_base.type) << "' seems to be missing a type ingredient or three\n" << end();
  replace_type_ingredients(element.type, element.properties.at(0).second, canonized_base.type->right, canonized_base.properties.at(0).second ? canonized_base.properties.at(0).second->right : NULL, info);
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

// replace type ingredients in both element_type and element_type_name based on a specific concrete type in 'callsite'
// todo: too complicated and likely incomplete; maybe avoid replacing in place? Maybe process element_type and element_type_name in separate functions?
void replace_type_ingredients(type_tree* element_type, string_tree* element_type_name, const type_tree* callsite_type, const string_tree* callsite_type_name, const type_info& container_info) {
  if (!callsite_type) return;  // error but it's already been raised above
  if (!element_type) return;
  // A. not a type ingredient? recurse
  if (element_type->value < START_TYPE_INGREDIENTS) {
    replace_type_ingredients(element_type->left, element_type_name ? element_type_name->left : NULL, callsite_type, callsite_type_name, container_info);
    replace_type_ingredients(element_type->right, element_type_name ? element_type_name->right : NULL, callsite_type, callsite_type_name, container_info);
    return ;
  }

  // B. type ingredient? replace left/value/right and then recurse just right
  const long long int type_ingredient_index = element_type->value-START_TYPE_INGREDIENTS;
  if (!has_nth_type(callsite_type, type_ingredient_index)) {
    raise_error << "illegal type '" << debug_string(callsite_type) << "' seems to be missing a type ingredient or three\n" << end();
    return;
  }

  // B1. update value/left/right of element_type
  const type_tree* replacement = NULL;
  bool erase_right = false;
  {
    const type_tree* curr = callsite_type;
    for (long long int i = 0; i < type_ingredient_index; ++i)
      curr = curr->right;
    if (curr && curr->left) {
      replacement = curr->left;
    }
    else {
      replacement = curr;
      if (!final_type_ingredient(type_ingredient_index, container_info))
        erase_right = true;
    }
  }
  element_type->value = replacement->value;
  assert(!element_type->left);  // since value is set
  element_type->left = replacement->left ? new type_tree(*replacement->left) : NULL;
  type_tree* old_right = element_type->right;
  if (!erase_right) {
    element_type->right = replacement->right ? new type_tree(*replacement->right) : NULL;
    append(element_type->right, old_right);
  }

  // B2. analogously update value/left/right of element_type_name
  if (!callsite_type_name) {
    replace_type_ingredients(old_right, NULL, callsite_type, callsite_type_name, container_info);
    return;
  }

  const string_tree* replacement_name = NULL;
  // could compute erase_right again here, but why bother
  {
    const string_tree* curr = callsite_type_name;
    for (long long int i = 0; i < type_ingredient_index; ++i)
      curr = curr->right;
    if (curr && curr->left)
      replacement_name = curr->left;
    else
      replacement_name = curr;
  }
  element_type_name->value = replacement_name->value;
  assert(!element_type_name->left);  // since value is set
  element_type_name->left = replacement_name->left ? new string_tree(*replacement_name->left) : NULL;
  string_tree* old_right_name = element_type_name->right;
  if (!erase_right) {
    element_type_name->right = replacement_name->right ? new string_tree(*replacement_name->right) : NULL;
    append(element_type_name->right, old_right_name);
  }

  replace_type_ingredients(old_right, old_right_name, callsite_type, callsite_type_name, container_info);
}

bool final_type_ingredient(long long int type_ingredient_index, const type_info& container_info) {
  for (map<string, type_ordinal>::const_iterator p = container_info.type_ingredient_names.begin();
       p != container_info.type_ingredient_names.end();
       ++p) {
    if (p->second > START_TYPE_INGREDIENTS+type_ingredient_index) return false;
  }
  return true;
}

void append(type_tree*& base, type_tree* extra) {
  if (!base) {
    base = extra;
    return;
  }
  type_tree* curr = base;
  while (curr->right) curr = curr->right;
  curr->right = extra;
}

void append(string_tree*& base, string_tree* extra) {
  if (!base) {
    base = extra;
    return;
  }
  string_tree* curr = base;
  while (curr->right) curr = curr->right;
  curr->right = extra;
}

void test_replace_type_ingredients_entire() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "  y:number\n"
      "]\n");
  reagent callsite("x:foo:point");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "x");
  CHECK_EQ(element.properties.at(0).second->value, "point");
  CHECK(!element.properties.at(0).second->right);
}

void test_replace_type_ingredients_tail() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem\n"
      "]\n");
  reagent callsite("x:bar:point");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "x");
  CHECK_EQ(element.properties.at(0).second->value, "foo");
  CHECK_EQ(element.properties.at(0).second->right->value, "point");
  CHECK(!element.properties.at(0).second->right->right);
}

void test_replace_type_ingredients_head_tail_multiple() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem\n"
      "]\n");
  reagent callsite("x:bar:address:shared:array:character");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "x");
  CHECK_EQ(element.properties.at(0).second->value, "foo");
  CHECK_EQ(element.properties.at(0).second->right->value, "address");
  CHECK_EQ(element.properties.at(0).second->right->right->value, "shared");
  CHECK_EQ(element.properties.at(0).second->right->right->right->value, "array");
  CHECK_EQ(element.properties.at(0).second->right->right->right->right->value, "character");
  CHECK(!element.properties.at(0).second->right->right->right->right->right);
}

void test_replace_type_ingredients_head_middle() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem:number\n"
      "]\n");
  reagent callsite("x:bar:address");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "x");
  CHECK(element.properties.at(0).second)
  CHECK_EQ(element.properties.at(0).second->value, "foo");
  CHECK(element.properties.at(0).second->right)
  CHECK_EQ(element.properties.at(0).second->right->value, "address");
  CHECK(element.properties.at(0).second->right->right)
  CHECK_EQ(element.properties.at(0).second->right->right->value, "number");
  CHECK(!element.properties.at(0).second->right->right->right);
}

void test_replace_last_type_ingredient_with_multiple() {
  run("container foo:_a:_b [\n"
      "  x:_a\n"
      "  y:_b\n"
      "]\n");
  reagent callsite("{f: (foo number (address shared array character))}");
  reagent element1 = element_type(callsite, 0);
  CHECK_EQ(element1.name, "x");
  CHECK_EQ(element1.properties.at(0).second->value, "number");
  CHECK(!element1.properties.at(0).second->right);
  reagent element2 = element_type(callsite, 1);
  CHECK_EQ(element2.name, "y");
  CHECK_EQ(element2.properties.at(0).second->value, "address");
  CHECK_EQ(element2.properties.at(0).second->right->value, "shared");
  CHECK_EQ(element2.properties.at(0).second->right->right->value, "array");
  CHECK_EQ(element2.properties.at(0).second->right->right->right->value, "character");
  CHECK(!element2.properties.at(0).second->right->right->right->right);
}

void test_replace_middle_type_ingredient_with_multiple() {
  run("container foo:_a:_b:_c [\n"
      "  x:_a\n"
      "  y:_b\n"
      "  z:_c\n"
      "]\n");
  reagent callsite("{f: (foo number (address shared array character) boolean)}");
  reagent element1 = element_type(callsite, 0);
  CHECK_EQ(element1.name, "x");
  CHECK_EQ(element1.properties.at(0).second->value, "number");
  CHECK(!element1.properties.at(0).second->right);
  reagent element2 = element_type(callsite, 1);
  CHECK_EQ(element2.name, "y");
  CHECK_EQ(element2.properties.at(0).second->value, "address");
  CHECK_EQ(element2.properties.at(0).second->right->value, "shared");
  CHECK_EQ(element2.properties.at(0).second->right->right->value, "array");
  CHECK_EQ(element2.properties.at(0).second->right->right->right->value, "character");
  CHECK(!element2.properties.at(0).second->right->right->right->right);
  reagent element3 = element_type(callsite, 2);
  CHECK_EQ(element3.name, "z");
  CHECK_EQ(element3.properties.at(0).second->value, "boolean");
  CHECK(!element3.properties.at(0).second->right);
}

bool has_nth_type(const type_tree* base, long long int n) {
  assert(n >= 0);
  if (base == NULL) return false;
  if (n == 0) return true;
  return has_nth_type(base->right, n-1);
}

:(scenario get_on_shape_shifting_container_error)
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

:(scenario get_address_on_shape_shifting_container)
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
const type_tree* type = get(Type, base_type).elements.at(i).type;
if (type->value >= START_TYPE_INGREDIENTS) {
  long long int size = size_of_type_ingredient(type, base.type->right);
  if (!size)
    raise_error << "illegal type '" << debug_string(type) << "' seems to be missing a type ingredient or three\n" << end();
  result += size;
  continue;
}

//: 'merge' on shape-shifting containers

:(scenario merge_check_shape_shifting_container_containing_exclusive_container)
% Hide_errors = true;
container foo:_elem [
  x:number
  y:_elem
]
exclusive-container bar [
  x:number
  y:number
]
recipe main [
  1:foo:bar <- merge 23, 1/y, 34
]
+mem: storing 23 in location 1
+mem: storing 1 in location 2
+mem: storing 34 in location 3
$error: 0

:(scenario merge_check_shape_shifting_container_containing_exclusive_container_2)
% Hide_errors = true;
container foo:_elem [
  x:number
  y:_elem
]
exclusive-container bar [
  x:number
  y:number
]
recipe main [
  1:foo:bar <- merge 23, 1/y, 34, 35
]
+error: main: too many ingredients in '1:foo:bar <- merge 23, 1/y, 34, 35'

:(scenario merge_check_shape_shifting_exclusive_container_containing_container)
% Hide_errors = true;
exclusive-container foo:_elem [
  x:number
  y:_elem
]
container bar [
  x:number
  y:number
]
recipe main [
  1:foo:bar <- merge 1/y, 23, 34
]
+mem: storing 1 in location 1
+mem: storing 23 in location 2
+mem: storing 34 in location 3
$error: 0

:(scenario merge_check_shape_shifting_exclusive_container_containing_container_2)
% Hide_errors = true;
exclusive-container foo:_elem [
  x:number
  y:_elem
]
container bar [
  x:number
  y:number
]
recipe main [
  1:foo:bar <- merge 0/x, 23
]
$error: 0

:(scenario merge_check_shape_shifting_exclusive_container_containing_container_3)
% Hide_errors = true;
exclusive-container foo:_elem [
  x:number
  y:_elem
]
container bar [
  x:number
  y:number
]
recipe main [
  1:foo:bar <- merge 1/y, 23
]
+error: main: too few ingredients in '1:foo:bar <- merge 1/y, 23'

:(before "End variant_type Special-cases")
if (contains_type_ingredient(element)) {
  if (!canonized_base.type->right)
    raise_error << "illegal type '" << debug_string(canonized_base.type) << "' seems to be missing a type ingredient or three\n" << end();
  replace_type_ingredients(element.type, element.properties.at(0).second, canonized_base.type->right, canonized_base.properties.at(0).second ? canonized_base.properties.at(0).second->right : NULL, info);
}

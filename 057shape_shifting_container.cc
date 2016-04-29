//:: Container definitions can contain 'type ingredients'

:(scenario size_of_shape_shifting_container)
container foo:_t [
  x:_t
  y:number
]
def main [
  1:foo:number <- merge 12, 13
  3:foo:point <- merge 14, 15, 16
]
+mem: storing 12 in location 1
+mem: storing 13 in location 2
+mem: storing 14 in location 3
+mem: storing 15 in location 4
+mem: storing 16 in location 5

:(scenario size_of_shape_shifting_container_2)
# multiple type ingredients
container foo:_a:_b [
  x:_a
  y:_b
]
def main [
  1:foo:number:boolean <- merge 34, 1/true
]
$error: 0

:(scenario size_of_shape_shifting_container_3)
container foo:_a:_b [
  x:_a
  y:_b
]
def main [
  1:address:array:character <- new [abc]
  # compound types for type ingredients
  {2: (foo number (address array character))} <- merge 34/x, 1:address:array:character/y
]
$error: 0

:(scenario size_of_shape_shifting_container_4)
container foo:_a:_b [
  x:_a
  y:_b
]
container bar:_a:_b [
  # dilated element
  {data: (foo _a (address _b))}
]
def main [
  1:address:array:character <- new [abc]
  2:bar:number:array:character <- merge 34/x, 1:address:array:character/y
]
$error: 0

:(scenario shape_shifting_container_extend)
container foo:_a [
  x:_a
]
container foo:_a [
  y:_a
]
$error: 0

:(scenario shape_shifting_container_extend_error)
% Hide_errors = true;
container foo:_a [
  x:_a
]
container foo:_b [
  y:_b
]
+error: headers of container 'foo' must use identical type ingredients

:(before "End Globals")
// We'll use large type ordinals to mean "the following type of the variable".
// For example, if we have a generic type called foo:_elem, the type
// ingredient _elem in foo's type_info will have value START_TYPE_INGREDIENTS,
// and we'll handle it by looking in the current reagent for the next type
// that appears after foo.
const int START_TYPE_INGREDIENTS = 2000;
:(before "End Commandline Parsing")  // after loading .mu files
assert(Next_type_ordinal < START_TYPE_INGREDIENTS);

:(before "End type_info Fields")
map<string, type_ordinal> type_ingredient_names;

//: Suppress unknown type checks in shape-shifting containers.

:(before "Check Container Field Types(info)")
if (!info.type_ingredient_names.empty()) continue;

:(before "End container Name Refinements")
if (name.find(':') != string::npos) {
  trace(9999, "parse") << "container has type ingredients; parsing" << end();
  if (!read_type_ingredients(name, command)) {
    // error; skip rest of the container definition and continue
    slurp_balanced_bracket(in);
    return;
  }
}

:(code)
bool read_type_ingredients(string& name, const string& command) {
  string save_name = name;
  istringstream in(save_name);
  name = slurp_until(in, ':');
  map<string, type_ordinal> type_ingredient_names;
  if (!slurp_type_ingredients(in, type_ingredient_names)) {
    return false;
  }
  if (contains_key(Type_ordinal, name)
      && contains_key(Type, get(Type_ordinal, name))) {
    const type_info& info = get(Type, get(Type_ordinal, name));
    // we've already seen this container; make sure type ingredients match
    if (!type_ingredients_match(type_ingredient_names, info.type_ingredient_names)) {
      raise << "headers of " << command << " '" << name << "' must use identical type ingredients\n" << end();
      return false;
    }
    return true;
  }
  // we haven't seen this container before
  if (!contains_key(Type_ordinal, name) || get(Type_ordinal, name) == 0)
    put(Type_ordinal, name, Next_type_ordinal++);
  type_info& info = get_or_insert(Type, get(Type_ordinal, name));
  info.type_ingredient_names.swap(type_ingredient_names);
  return true;
}

bool slurp_type_ingredients(istream& in, map<string, type_ordinal>& out) {
  int next_type_ordinal = START_TYPE_INGREDIENTS;
  while (has_data(in)) {
    string curr = slurp_until(in, ':');
    if (out.find(curr) != out.end()) {
      raise << "can't repeat type ingredient names in a single container definition: " << curr << '\n' << end();
      return false;
    }
    put(out, curr, next_type_ordinal++);
  }
  return true;
}

bool type_ingredients_match(const map<string, type_ordinal>& a, const map<string, type_ordinal>& b) {
  if (SIZE(a) != SIZE(b)) return false;
  for (map<string, type_ordinal>::const_iterator p = a.begin(); p != a.end(); ++p) {
    if (!contains_key(b, p->first)) return false;
    if (p->second != get(b, p->first)) return false;
  }
  return true;
}

:(before "End insert_container Special-cases")
// check for use of type ingredients
else if (is_type_ingredient_name(type->name)) {
  type->value = get(info.type_ingredient_names, type->name);
}
:(code)
bool is_type_ingredient_name(const string& type) {
  return !type.empty() && type.at(0) == '_';
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
def main [
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

:(scenario get_on_shape_shifting_container)
container foo:_t [
  x:_t
  y:number
]
def main [
  1:foo:point <- merge 14, 15, 16
  2:number <- get 1:foo:point, y:offset
]
+mem: storing 16 in location 2

:(scenario get_on_shape_shifting_container_2)
container foo:_t [
  x:_t
  y:number
]
def main [
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
def main [
  1:foo:address:point <- merge 34/unsafe, 48
  3:address:point <- get 1:foo:address:point, x:offset
]
+mem: storing 34 in location 3

:(scenario get_on_shape_shifting_container_inside_container)
container foo:_t [
  x:_t
  y:number
]
container bar [
  x:foo:point
  y:number
]
def main [
  1:bar <- merge 14, 15, 16, 17
  2:number <- get 1:bar, 1:offset
]
+mem: storing 17 in location 2

:(scenario get_on_complex_shape_shifting_container)
container foo:_a:_b [
  x:_a
  y:_b
]
def main [
  1:address:array:character <- new [abc]
  {2: (foo number (address array character))} <- merge 34/x, 1:address:array:character/y
  3:address:array:character <- get {2: (foo number (address array character))}, y:offset
  4:boolean <- equal 1:address:array:character, 3:address:array:character
]
+mem: storing 1 in location 4

:(before "End element_type Special-cases")
if (contains_type_ingredient(element)) {
  if (!base.type->right)
    raise << "illegal type " << names_to_string(base.type) << " seems to be missing a type ingredient or three\n" << end();
  replace_type_ingredients(element.type, base.type->right, info);
}

:(code)
bool contains_type_ingredient(const reagent& x) {
  return contains_type_ingredient(x.type);
}

bool contains_type_ingredient(const type_tree* type) {
  if (!type) return false;
  if (type->value >= START_TYPE_INGREDIENTS) return true;
  assert(!is_type_ingredient_name(type->name));
  return contains_type_ingredient(type->left) || contains_type_ingredient(type->right);
}

// replace all type_ingredients in element_type with corresponding elements of callsite_type
// todo: too complicated and likely incomplete; maybe avoid replacing in place?
void replace_type_ingredients(type_tree* element_type, const type_tree* callsite_type, const type_info& container_info) {
  if (!callsite_type) return;  // error but it's already been raised above
  if (!element_type) return;

  // A. recurse first to avoid nested replaces (which I can't reason about yet)
  replace_type_ingredients(element_type->left, callsite_type, container_info);
  replace_type_ingredients(element_type->right, callsite_type, container_info);
  if (element_type->value < START_TYPE_INGREDIENTS) return;

  const int type_ingredient_index = element_type->value-START_TYPE_INGREDIENTS;
  if (!has_nth_type(callsite_type, type_ingredient_index)) {
    raise << "illegal type " << names_to_string(callsite_type) << " seems to be missing a type ingredient or three\n" << end();
    return;
  }

  // B. replace the current location
  const type_tree* replacement = NULL;
  bool splice_right = true ;
  bool zig_left = false;
  {
    const type_tree* curr = callsite_type;
    for (int i = 0; i < type_ingredient_index; ++i)
      curr = curr->right;
    if (curr && curr->left) {
      replacement = curr->left;
      zig_left = true;
    }
    else {
      // We want foo:_t to be used like foo:number, which expands to {foo: number}
      // rather than {foo: (number)}
      // We'd also like to use it with multiple types: foo:address:number.
      replacement = curr;
      splice_right = final_type_ingredient(type_ingredient_index, container_info);
    }
  }
  if (element_type->right && replacement->right && zig_left) {  // ZERO confidence that this condition is accurate
    element_type->name = "";
    element_type->value = 0;
    element_type->left = new type_tree(*replacement);
  }
  else {
    string old_name = element_type->name;
    element_type->name = replacement->name;
    element_type->value = replacement->value;
    assert(!element_type->left);  // since value is set
    element_type->left = replacement->left ? new type_tree(*replacement->left) : NULL;
    if (splice_right) {
      type_tree* old_right = element_type->right;
      element_type->right = replacement->right ? new type_tree(*replacement->right) : NULL;
      append(element_type->right, old_right);
    }
  }
}

bool final_type_ingredient(int type_ingredient_index, const type_info& container_info) {
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
  CHECK_EQ(element.type->name, "point");
  CHECK(!element.type->right);
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
  CHECK_EQ(element.type->name, "foo");
  CHECK_EQ(element.type->right->name, "point");
  CHECK(!element.type->right->right);
}

void test_replace_type_ingredients_head_tail_multiple() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem\n"
      "]\n");
  reagent callsite("x:bar:address:array:character");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "x");
  CHECK_EQ(element.type->name, "foo");
  CHECK_EQ(element.type->right->name, "address");
  CHECK_EQ(element.type->right->right->name, "array");
  CHECK_EQ(element.type->right->right->right->name, "character");
  CHECK(!element.type->right->right->right->right);
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
  CHECK(element.type)
  CHECK_EQ(element.type->name, "foo");
  CHECK(element.type->right)
  CHECK_EQ(element.type->right->name, "address");
  CHECK(element.type->right->right)
  CHECK_EQ(element.type->right->right->name, "number");
  CHECK(!element.type->right->right->right);
}

void test_replace_last_type_ingredient_with_multiple() {
  run("container foo:_a:_b [\n"
      "  x:_a\n"
      "  y:_b\n"
      "]\n");
  reagent callsite("{f: (foo number (address array character))}");
  reagent element1 = element_type(callsite, 0);
  CHECK_EQ(element1.name, "x");
  CHECK_EQ(element1.type->name, "number");
  CHECK(!element1.type->right);
  reagent element2 = element_type(callsite, 1);
  CHECK_EQ(element2.name, "y");
  CHECK_EQ(element2.type->name, "address");
  CHECK_EQ(element2.type->right->name, "array");
  CHECK_EQ(element2.type->right->right->name, "character");
  CHECK(!element2.type->right->right->right);
}

void test_replace_middle_type_ingredient_with_multiple() {
  run("container foo:_a:_b:_c [\n"
      "  x:_a\n"
      "  y:_b\n"
      "  z:_c\n"
      "]\n");
  reagent callsite("{f: (foo number (address array character) boolean)}");
  reagent element1 = element_type(callsite, 0);
  CHECK_EQ(element1.name, "x");
  CHECK_EQ(element1.type->name, "number");
  CHECK(!element1.type->right);
  reagent element2 = element_type(callsite, 1);
  CHECK_EQ(element2.name, "y");
  CHECK_EQ(element2.type->name, "address");
  CHECK_EQ(element2.type->right->name, "array");
  CHECK_EQ(element2.type->right->right->name, "character");
  CHECK(!element2.type->right->right->right);
  reagent element3 = element_type(callsite, 2);
  CHECK_EQ(element3.name, "z");
  CHECK_EQ(element3.type->name, "boolean");
  CHECK(!element3.type->right);
}

void test_replace_middle_type_ingredient_with_multiple2() {
  run("container foo:_key:_value [\n"
      "  key:_key\n"
      "  value:_value\n"
      "]\n");
  reagent callsite("{f: (foo (address array character) number)}");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "key");
  CHECK_EQ(element.type->name, "address");
  CHECK_EQ(element.type->right->name, "array");
  CHECK_EQ(element.type->right->right->name, "character");
  CHECK(!element.type->right->right->right);
}

void test_replace_middle_type_ingredient_with_multiple3() {
  run("container foo_table:_key:_value [\n"
      "  data:address:array:foo_table_row:_key:_value\n"
      "]\n"
      "\n"
      "container foo_table_row:_key:_value [\n"
      "  key:_key\n"
      "  value:_value\n"
      "]\n");
  reagent callsite("{f: (foo_table (address array character) number)}");
  reagent element = element_type(callsite, 0);
  CHECK_EQ(element.name, "data");
  CHECK_EQ(element.type->name, "address");
  CHECK_EQ(element.type->right->name, "array");
  CHECK_EQ(element.type->right->right->name, "foo_table_row");
    CHECK(element.type->right->right->right->left);
    CHECK_EQ(element.type->right->right->right->left->name, "address");
    CHECK_EQ(element.type->right->right->right->left->right->name, "array");
    CHECK_EQ(element.type->right->right->right->left->right->right->name, "character");
  CHECK_EQ(element.type->right->right->right->right->name, "number");
  CHECK(!element.type->right->right->right->right->right);
}

bool has_nth_type(const type_tree* base, int n) {
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
def main [
  10:foo:point <- merge 14, 15, 16
  1:number <- get 10:foo, 1:offset
]
+error: illegal type "foo" seems to be missing a type ingredient or three

//: 'merge' on shape-shifting containers

:(scenario merge_check_shape_shifting_container_containing_exclusive_container)
container foo:_elem [
  x:number
  y:_elem
]
exclusive-container bar [
  x:number
  y:number
]
def main [
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
def main [
  1:foo:bar <- merge 23, 1/y, 34, 35
]
+error: main: too many ingredients in '1:foo:bar <- merge 23, 1/y, 34, 35'

:(scenario merge_check_shape_shifting_exclusive_container_containing_container)
exclusive-container foo:_elem [
  x:number
  y:_elem
]
container bar [
  x:number
  y:number
]
def main [
  1:foo:bar <- merge 1/y, 23, 34
]
+mem: storing 1 in location 1
+mem: storing 23 in location 2
+mem: storing 34 in location 3
$error: 0

:(scenario merge_check_shape_shifting_exclusive_container_containing_container_2)
exclusive-container foo:_elem [
  x:number
  y:_elem
]
container bar [
  x:number
  y:number
]
def main [
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
def main [
  1:foo:bar <- merge 1/y, 23
]
+error: main: too few ingredients in '1:foo:bar <- merge 1/y, 23'

:(before "End variant_type Special-cases")
if (contains_type_ingredient(element)) {
  if (!base.type->right)
    raise << "illegal type '" << to_string(base.type) << "' seems to be missing a type ingredient or three\n" << end();
  replace_type_ingredients(element.type, base.type->right, info);
}

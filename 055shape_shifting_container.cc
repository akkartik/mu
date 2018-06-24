//:: Container definitions can contain 'type ingredients'

//: pre-requisite: extend our notion of containers to not necessarily be
//: atomic types
:(after "Update GET base_type in Check")
base_type = get_base_type(base_type);
:(after "Update GET base_type in Run")
base_type = get_base_type(base_type);
:(after "Update PUT base_type in Check")
base_type = get_base_type(base_type);
:(after "Update PUT base_type in Run")
base_type = get_base_type(base_type);
:(after "Update MAYBE_CONVERT base_type in Check")
base_type = get_base_type(base_type);
:(after "Update base_type in element_type")
base_type = get_base_type(base_type);
:(after "Update base_type in skip_addresses")
base_type = get_base_type(base_type);
:(replace{} "const type_tree* get_base_type(const type_tree* t)")
const type_tree* get_base_type(const type_tree* t) {
  const type_tree* result = t->atom ? t : t->left;
  if (!result->atom)
    raise << "invalid type " << to_string(t) << '\n' << end();
  return result;
}

:(scenario ill_formed_container)
% Hide_errors = true;
def main [
  {1: ((foo) num)} <- copy 0
]
# no crash

//: update size_of to handle non-atom container types

:(scenario size_of_shape_shifting_container)
container foo:_t [
  x:_t
  y:num
]
def main [
  1:foo:num <- merge 12, 13
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
  1:foo:num:bool <- merge 34, true
]
$error: 0

:(scenario size_of_shape_shifting_container_3)
container foo:_a:_b [
  x:_a
  y:_b
]
def main [
  1:text <- new [abc]
  # compound types for type ingredients
  {3: (foo number (address array character))} <- merge 34/x, 1:text/y
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
  1:text <- new [abc]
  3:bar:num:@:char <- merge 34/x, 1:text/y
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

:(scenario type_ingredient_must_start_with_underscore)
% Hide_errors = true;
container foo:t [
  x:num
]
+error: foo: type ingredient 't' must begin with an underscore

:(before "End Globals")
// We'll use large type ordinals to mean "the following type of the variable".
// For example, if we have a generic type called foo:_elem, the type
// ingredient _elem in foo's type_info will have value START_TYPE_INGREDIENTS,
// and we'll handle it by looking in the current reagent for the next type
// that appears after foo.
extern const int START_TYPE_INGREDIENTS = 2000;
:(before "End Commandline Parsing")  // after loading .mu files
assert(Next_type_ordinal < START_TYPE_INGREDIENTS);

:(before "End type_info Fields")
map<string, type_ordinal> type_ingredient_names;

//: Suppress unknown type checks in shape-shifting containers.

:(before "Check Container Field Types(info)")
if (!info.type_ingredient_names.empty()) continue;

:(before "End container Name Refinements")
if (name.find(':') != string::npos) {
  trace("parse") << "container has type ingredients; parsing" << end();
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
  if (!slurp_type_ingredients(in, type_ingredient_names, name)) {
    return false;
  }
  if (contains_key(Type_ordinal, name)
      && contains_key(Type, get(Type_ordinal, name))) {
    const type_info& previous_info = get(Type, get(Type_ordinal, name));
    // we've already seen this container; make sure type ingredients match
    if (!type_ingredients_match(type_ingredient_names, previous_info.type_ingredient_names)) {
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

bool slurp_type_ingredients(istream& in, map<string, type_ordinal>& out, const string& container_name) {
  int next_type_ordinal = START_TYPE_INGREDIENTS;
  while (has_data(in)) {
    string curr = slurp_until(in, ':');
    if (curr.empty()) {
      raise << container_name << ": empty type ingredients not permitted\n" << end();
      return false;
    }
    if (!starts_with(curr, "_")) {
      raise << container_name << ": type ingredient '" << curr << "' must begin with an underscore\n" << end();
      return false;
    }
    if (out.find(curr) != out.end()) {
      raise << container_name << ": can't repeat type ingredient name'" << curr << "' in a single container definition\n" << end();
      return false;
    }
    put(out, curr, next_type_ordinal++);
  }
  return true;
}

bool type_ingredients_match(const map<string, type_ordinal>& a, const map<string, type_ordinal>& b) {
  if (SIZE(a) != SIZE(b)) return false;
  for (map<string, type_ordinal>::const_iterator p = a.begin();  p != a.end();  ++p) {
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
  return starts_with(type, "_");
}

:(before "End Container Type Checks")
if (type->value >= START_TYPE_INGREDIENTS
    && (type->value - START_TYPE_INGREDIENTS) < SIZE(get(Type, type->value).type_ingredient_names))
  return;

:(scenario size_of_shape_shifting_exclusive_container)
exclusive-container foo:_t [
  x:_t
  y:num
]
def main [
  1:foo:num <- merge 0/x, 34
  3:foo:point <- merge 0/x, 15, 16
  6:foo:point <- merge 1/y, 23
]
+run: {1: ("foo" "number")} <- merge {0: "literal", "x": ()}, {34: "literal"}
+mem: storing 0 in location 1
+mem: storing 34 in location 2
+run: {3: ("foo" "point")} <- merge {0: "literal", "x": ()}, {15: "literal"}, {16: "literal"}
+mem: storing 0 in location 3
+mem: storing 15 in location 4
+mem: storing 16 in location 5
+run: {6: ("foo" "point")} <- merge {1: "literal", "y": ()}, {23: "literal"}
+mem: storing 1 in location 6
+mem: storing 23 in location 7
+run: return
# no other stores
% CHECK_EQ(trace_count_prefix("mem", "storing"), 7);

:(before "End variant_type Special-cases")
if (contains_type_ingredient(element))
  replace_type_ingredients(element.type, type->right, info, " while computing variant type of exclusive-container");

:(scenario get_on_shape_shifting_container)
container foo:_t [
  x:_t
  y:num
]
def main [
  1:foo:point <- merge 14, 15, 16
  4:num <- get 1:foo:point, y:offset
]
+mem: storing 16 in location 4

:(scenario get_on_shape_shifting_container_2)
container foo:_t [
  x:_t
  y:num
]
def main [
  1:foo:point <- merge 14, 15, 16
  4:point <- get 1:foo:point, x:offset
]
+mem: storing 14 in location 4
+mem: storing 15 in location 5

:(scenario get_on_shape_shifting_container_3)
container foo:_t [
  x:_t
  y:num
]
def main [
  1:num/alloc-id, 2:num <- copy 0, 34
  3:foo:&:point <- merge 1:&:point, 48
  6:&:point <- get 1:foo:&:point, x:offset
]
+mem: storing 0 in location 6
+mem: storing 34 in location 7

:(scenario get_on_shape_shifting_container_inside_container)
container foo:_t [
  x:_t
  y:num
]
container bar [
  x:foo:point
  y:num
]
def main [
  1:bar <- merge 14, 15, 16, 17
  5:num <- get 1:bar, 1:offset
]
+mem: storing 17 in location 5

:(scenario get_on_complex_shape_shifting_container)
container foo:_a:_b [
  x:_a
  y:_b
]
def main [
  1:text <- new [abc]
  {3: (foo number (address array character))} <- merge 34/x, 1:text/y
  6:text <- get {3: (foo number (address array character))}, y:offset
  8:bool <- equal 1:text, 6:text
]
+mem: storing 1 in location 8

:(before "End element_type Special-cases")
replace_type_ingredients(element, type, info, " while computing element type of container");

:(before "End size_of(type) Non-atom Special-cases")
assert(type->left->atom);
if (!contains_key(Type, type->left->value)) {
  raise << "no such type " << type->left->value << '\n' << end();
  return 0;
}
type_info t = get(Type, type->left->value);
if (t.kind == CONTAINER) {
  // size of a container is the sum of the sizes of its elements
  int result = 0;
  for (int i = 0; i < SIZE(t.elements); ++i) {
    // todo: strengthen assertion to disallow mutual type recursion
    if (get_base_type(t.elements.at(i).type)->value == get_base_type(type)->value) {
      raise << "container " << t.name << " can't include itself as a member\n" << end();
      return 0;
    }
    result += size_of(element_type(type, i));
  }
  return result;
}
if (t.kind == EXCLUSIVE_CONTAINER) {
  // size of an exclusive container is the size of its largest variant
  // (So like containers, it can't contain arrays.)
  int result = 0;
  for (int i = 0; i < SIZE(t.elements); ++i) {
    reagent tmp;
    tmp.type = new type_tree(*type);
    int size = size_of(variant_type(tmp, i));
    if (size > result) result = size;
  }
  // ...+1 for its tag.
  return result+1;
}

:(scenario complex_shape_shifting_exclusive_container)
exclusive-container foo:_a [
  x:_a
  y:num
]
def main [
  1:text <- new [abc]
  3:foo:point <- merge 0/variant, 34/xx, 35/xy
  10:point, 20:bool <- maybe-convert 3:foo:point, 0/variant
]
+mem: storing 1 in location 20
+mem: storing 35 in location 11

:(code)
bool contains_type_ingredient(const reagent& x) {
  return contains_type_ingredient(x.type);
}

bool contains_type_ingredient(const type_tree* type) {
  if (!type) return false;
  if (type->atom) return type->value >= START_TYPE_INGREDIENTS;
  return contains_type_ingredient(type->left) || contains_type_ingredient(type->right);
}

void replace_type_ingredients(reagent& element, const type_tree* caller_type, const type_info& info, const string& location_for_error_messages) {
  if (contains_type_ingredient(element)) {
    if (!caller_type->right)
      raise << "illegal type " << names_to_string(caller_type) << " seems to be missing a type ingredient or three" << location_for_error_messages << '\n' << end();
    replace_type_ingredients(element.type, caller_type->right, info, location_for_error_messages);
  }
}

// replace all type_ingredients in element_type with corresponding elements of callsite_type
void replace_type_ingredients(type_tree* element_type, const type_tree* callsite_type, const type_info& container_info, const string& location_for_error_messages) {
  if (!callsite_type) return;  // error but it's already been raised above
  if (!element_type) return;
  if (!element_type->atom) {
    if (element_type->right == NULL && is_type_ingredient(element_type->left)) {
      int type_ingredient_index = to_type_ingredient_index(element_type->left);
      if (corresponding(callsite_type, type_ingredient_index, is_final_type_ingredient(type_ingredient_index, container_info))->right) {
        // replacing type ingredient at end of list, and replacement is a non-degenerate compound type -- (a b) but not (a)
        replace_type_ingredient_at(type_ingredient_index, element_type, callsite_type, container_info, location_for_error_messages);
        return;
      }
    }
    replace_type_ingredients(element_type->left, callsite_type, container_info, location_for_error_messages);
    replace_type_ingredients(element_type->right, callsite_type, container_info, location_for_error_messages);
    return;
  }
  if (is_type_ingredient(element_type))
    replace_type_ingredient_at(to_type_ingredient_index(element_type), element_type, callsite_type, container_info, location_for_error_messages);
}

const type_tree* corresponding(const type_tree* type, int index, bool final) {
  for (const type_tree* curr = type;  curr;  curr = curr->right, --index) {
    assert_for_now(!curr->atom);
    if (index == 0)
      return final ? curr : curr->left;
  }
  assert_for_now(false);
}

bool is_type_ingredient(const type_tree* type) {
  return type->atom && type->value >= START_TYPE_INGREDIENTS;
}

int to_type_ingredient_index(const type_tree* type) {
  assert(type->atom);
  return type->value-START_TYPE_INGREDIENTS;
}

void replace_type_ingredient_at(const int type_ingredient_index, type_tree* element_type, const type_tree* callsite_type, const type_info& container_info, const string& location_for_error_messages) {
  if (!has_nth_type(callsite_type, type_ingredient_index)) {
    raise << "illegal type " << names_to_string(callsite_type) << " seems to be missing a type ingredient or three" << location_for_error_messages << '\n' << end();
    return;
  }
  *element_type = *nth_type_ingredient(callsite_type, type_ingredient_index, container_info);
}

const type_tree* nth_type_ingredient(const type_tree* callsite_type, int type_ingredient_index, const type_info& container_info) {
  bool final = is_final_type_ingredient(type_ingredient_index, container_info);
  const type_tree* curr = callsite_type;
  for (int i = 0;  i < type_ingredient_index;  ++i) {
    assert(curr);
    assert(!curr->atom);
//?     cerr << "type ingredient " << i << " is " << to_string(curr->left) << '\n';
    curr = curr->right;
  }
  assert(curr);
  if (curr->atom) return curr;
  if (!final) return curr->left;
  if (!curr->right) return curr->left;
  return curr;
}

bool is_final_type_ingredient(int type_ingredient_index, const type_info& container_info) {
  for (map<string, type_ordinal>::const_iterator p = container_info.type_ingredient_names.begin();
       p != container_info.type_ingredient_names.end();
       ++p) {
    if (p->second > START_TYPE_INGREDIENTS+type_ingredient_index) return false;
  }
  return true;
}

:(before "End Unit Tests")
void test_replace_type_ingredients_entire() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "  y:num\n"
      "]\n");
  reagent callsite("x:foo:point");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element), "{x: \"point\"}");
}

void test_replace_type_ingredients_tail() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem\n"
      "]\n");
  reagent callsite("x:bar:point");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element), "{x: (\"foo\" \"point\")}");
}

void test_replace_type_ingredients_head_tail_multiple() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem\n"
      "]\n");
  reagent callsite("x:bar:address:array:character");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element), "{x: (\"foo\" \"address\" \"array\" \"character\")}");
}

void test_replace_type_ingredients_head_middle() {
  run("container foo:_elem [\n"
      "  x:_elem\n"
      "]\n"
      "container bar:_elem [\n"
      "  x:foo:_elem:num\n"
      "]\n");
  reagent callsite("x:bar:address");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element), "{x: (\"foo\" \"address\" \"number\")}");
}

void test_replace_last_type_ingredient_with_multiple() {
  run("container foo:_a:_b [\n"
      "  x:_a\n"
      "  y:_b\n"
      "]\n");
  reagent callsite("{f: (foo number (address array character))}");
  reagent element1 = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element1), "{x: \"number\"}");
  reagent element2 = element_type(callsite.type, 1);
  CHECK_EQ(to_string(element2), "{y: (\"address\" \"array\" \"character\")}");
}

void test_replace_last_type_ingredient_inside_compound() {
  run("container foo:_a:_b [\n"
      "  {x: (bar _a (address _b))}\n"
      "]\n");
  reagent callsite("f:foo:number:array:character");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(names_to_string_without_quotes(element.type), "(bar number (address array character))");
}

void test_replace_middle_type_ingredient_with_multiple() {
  run("container foo:_a:_b:_c [\n"
      "  x:_a\n"
      "  y:_b\n"
      "  z:_c\n"
      "]\n");
  reagent callsite("{f: (foo number (address array character) boolean)}");
  reagent element1 = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element1), "{x: \"number\"}");
  reagent element2 = element_type(callsite.type, 1);
  CHECK_EQ(to_string(element2), "{y: (\"address\" \"array\" \"character\")}");
  reagent element3 = element_type(callsite.type, 2);
  CHECK_EQ(to_string(element3), "{z: \"boolean\"}");
}

void test_replace_middle_type_ingredient_with_multiple2() {
  run("container foo:_key:_value [\n"
      "  key:_key\n"
      "  value:_value\n"
      "]\n");
  reagent callsite("{f: (foo (address array character) number)}");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element), "{key: (\"address\" \"array\" \"character\")}");
}

void test_replace_middle_type_ingredient_with_multiple3() {
  run("container foo_table:_key:_value [\n"
      "  data:&:@:foo_table_row:_key:_value\n"
      "]\n"
      "\n"
      "container foo_table_row:_key:_value [\n"
      "  key:_key\n"
      "  value:_value\n"
      "]\n");
  reagent callsite("{f: (foo_table (address array character) number)}");
  reagent element = element_type(callsite.type, 0);
  CHECK_EQ(to_string(element), "{data: (\"address\" \"array\" \"foo_table_row\" (\"address\" \"array\" \"character\") \"number\")}");
}

:(code)
bool has_nth_type(const type_tree* base, int n) {
  assert(n >= 0);
  if (!base) return false;
  if (n == 0) return true;
  return has_nth_type(base->right, n-1);
}

:(scenario get_on_shape_shifting_container_error)
% Hide_errors = true;
container foo:_t [
  x:_t
  y:num
]
def main [
  1:foo:point <- merge 14, 15, 16
  10:num <- get 1:foo, 1:offset
]
# todo: improve error message
+error: illegal type "foo" seems to be missing a type ingredient or three while computing element type of container

:(scenario typos_in_container_definitions)
% Hide_errors = true;
container foo:_t [
  x:adress:_t  # typo
]
def main [
  local-scope
  x:address:foo:num <- new {(foo num): type}
]
# no crash

:(scenario typos_in_recipes)
% Hide_errors = true;
def foo [
  local-scope
  x:adress:array:number <- copy null  # typo
]
# shouldn't crash

//:: 'merge' on shape-shifting containers

:(scenario merge_check_shape_shifting_container_containing_exclusive_container)
container foo:_elem [
  x:num
  y:_elem
]
exclusive-container bar [
  x:num
  y:num
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
  x:num
  y:_elem
]
exclusive-container bar [
  x:num
  y:num
]
def main [
  1:foo:bar <- merge 23, 1/y, 34, 35
]
+error: main: too many ingredients in '1:foo:bar <- merge 23, 1/y, 34, 35'

:(scenario merge_check_shape_shifting_exclusive_container_containing_container)
exclusive-container foo:_elem [
  x:num
  y:_elem
]
container bar [
  x:num
  y:num
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
  x:num
  y:_elem
]
container bar [
  x:num
  y:num
]
def main [
  1:foo:bar <- merge 0/x, 23
]
$error: 0

:(scenario merge_check_shape_shifting_exclusive_container_containing_container_3)
% Hide_errors = true;
exclusive-container foo:_elem [
  x:num
  y:_elem
]
container bar [
  x:num
  y:num
]
def main [
  1:foo:bar <- merge 1/y, 23
]
+error: main: too few ingredients in '1:foo:bar <- merge 1/y, 23'

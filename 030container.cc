//: Containers contain a fixed number of elements of different types.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
type_ordinal point = put(Type_ordinal, "point", Next_type_ordinal++);
get_or_insert(Type, point).size = 2;
get(Type, point).kind = CONTAINER;
get(Type, point).name = "point";
get(Type, point).elements.push_back(reagent("x:number"));
get(Type, point).elements.push_back(reagent("y:number"));

//: Containers can be copied around with a single instruction just like
//: numbers, no matter how large they are.

//: Tests in this layer often explicitly setup memory before reading it as a
//: container. Don't do this in general. I'm tagging exceptions with /raw to
//: avoid errors.
:(scenario copy_multiple_locations)
def main [
  1:number <- copy 34
  2:number <- copy 35
  3:point <- copy 1:point/unsafe
]
+mem: storing 34 in location 3
+mem: storing 35 in location 4

//: trying to copy to a differently-typed destination will fail
:(scenario copy_checks_size)
% Hide_errors = true;
def main [
  2:point <- copy 1:number
]
+error: main: can't copy 1:number to 2:point; types don't match

:(before "End Mu Types Initialization")
// A more complex container, containing another container as one of its
// elements.
type_ordinal point_number = put(Type_ordinal, "point-number", Next_type_ordinal++);
get_or_insert(Type, point_number).size = 2;
get(Type, point_number).kind = CONTAINER;
get(Type, point_number).name = "point-number";
get(Type, point_number).elements.push_back(reagent("xy:point"));
get(Type, point_number).elements.push_back(reagent("z:number"));

:(scenario copy_handles_nested_container_elements)
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:point-number <- copy 12:point-number/unsafe
]
+mem: storing 36 in location 17

//: Containers can be checked for equality with a single instruction just like
//: numbers, no matter how large they are.

:(scenario compare_multiple_locations)
def main [
  1:number <- copy 34  # first
  2:number <- copy 35
  3:number <- copy 36
  4:number <- copy 34  # second
  5:number <- copy 35
  6:number <- copy 36
  7:boolean <- equal 1:point-number/raw, 4:point-number/unsafe
]
+mem: storing 1 in location 7

:(scenario compare_multiple_locations_2)
def main [
  1:number <- copy 34  # first
  2:number <- copy 35
  3:number <- copy 36
  4:number <- copy 34  # second
  5:number <- copy 35
  6:number <- copy 37  # different
  7:boolean <- equal 1:point-number/raw, 4:point-number/unsafe
]
+mem: storing 0 in location 7

:(before "End size_of(type) Cases")
if (type->value == -1) {
  // error value, but we'll raise it elsewhere
  return 1;
}
if (type->value == 0) {
  assert(!type->left && !type->right);
  return 1;
}
if (!contains_key(Type, type->value)) {
  raise << "no such type " << type->value << '\n' << end();
  return 0;
}
type_info t = get(Type, type->value);
if (t.kind == CONTAINER) {
  // size of a container is the sum of the sizes of its elements
  int result = 0;
  for (int i = 0; i < SIZE(t.elements); ++i) {
    // todo: strengthen assertion to disallow mutual type recursion
    if (t.elements.at(i).type->value == type->value) {
      raise << "container " << t.name << " can't include itself as a member\n" << end();
      return 0;
    }
    reagent tmp;
    tmp.type = new type_tree(*type);
    result += size_of(element_type(tmp, i));
  }
  return result;
}

:(scenario stash_container)
def main [
  1:number <- copy 34  # first
  2:number <- copy 35
  3:number <- copy 36
  stash [foo:], 1:point-number/raw
]
+app: foo: 34 35 36

//:: To access elements of a container, use 'get'
:(scenario get)
def main [
  12:number <- copy 34
  13:number <- copy 35
  15:number <- get 12:point/raw, 1:offset  # unsafe
]
+mem: storing 35 in location 15

:(before "End Primitive Recipe Declarations")
GET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "get", GET);
:(before "End Primitive Recipe Checks")
case GET: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'get' expects exactly 2 ingredients in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);  // new copy for every invocation
  // Update GET base in Check
  if (!base.type || !base.type->value || !contains_key(Type, base.type->value) || get(Type, base.type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  reagent offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'get' should have type 'offset', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  int offset_value = 0;
  if (is_integer(offset.name))  // later layers permit non-integer offsets
    offset_value = to_integer(offset.name);
  else
    offset_value = offset.value;
  if (offset_value < 0 || offset_value >= SIZE(get(Type, base_type).elements)) {
    raise << maybe(get(Recipe, r).name) << "invalid offset " << offset_value << " for " << get(Type, base_type).name << '\n' << end();
    break;
  }
  if (inst.products.empty()) break;
  reagent product = inst.products.at(0);
  // Update GET product in Check
  const reagent element = element_type(base, offset_value);
  if (!types_coercible(product, element)) {
    raise << maybe(get(Recipe, r).name) << "'get " << base.original_string << ", " << offset.original_string << "' should write to " << names_to_string_without_quotes(element.type) << " but " << product.name << " has type " << names_to_string_without_quotes(product.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET: {
  reagent base = current_instruction().ingredients.at(0);
  // Update GET base in Run
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type).elements)) break;  // copied from Check above
  int src = base_address;
  for (int i = 0; i < offset; ++i) {
    // End GET field Cases
    src += size_of(element_type(base, i));
  }
  trace(9998, "run") << "address to copy is " << src << end();
  reagent tmp = element_type(base, offset);
  tmp.set_value(src);
  trace(9998, "run") << "its type is " << names_to_string(tmp.type) << end();
  products.push_back(read_memory(tmp));
  break;
}

:(code)
const reagent element_type(const reagent& canonized_base, int offset_value) {
  assert(offset_value >= 0);
  assert(contains_key(Type, canonized_base.type->value));
  assert(!get(Type, canonized_base.type->value).name.empty());
  const type_info& info = get(Type, canonized_base.type->value);
  assert(info.kind == CONTAINER);
  reagent element = info.elements.at(offset_value);
  // End element_type Special-cases
  return element;
}

:(scenario get_handles_nested_container_elements)
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:number <- get 12:point-number/raw, 1:offset  # unsafe
]
+mem: storing 36 in location 15

:(scenario get_out_of_bounds)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset 2 for point-number

:(scenario get_out_of_bounds_2)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get 12:point-number/raw, -1:offset
]
+error: main: invalid offset -1 for point-number

:(scenario get_product_type_mismatch)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:address:number <- get 12:point-number/raw, 1:offset
]
+error: main: 'get 12:point-number/raw, 1:offset' should write to number but 15 has type (address number)

//: we might want to call 'get' without saving the results, say in a sandbox

:(scenario get_without_product)
def main [
  12:number <- copy 34
  13:number <- copy 35
  get 12:point/raw, 1:offset  # unsafe
]
# just don't die

//:: To write to elements of containers, you need their address.

:(scenario get_address)
def main [
  12:number <- copy 34
  13:number <- copy 35
  15:address:number <- get-address 12:point/raw, 1:offset  # unsafe
]
+mem: storing 13 in location 15

:(before "End Primitive Recipe Declarations")
GET_ADDRESS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "get-address", GET_ADDRESS);
:(before "End Primitive Recipe Checks")
case GET_ADDRESS: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'get-address' expects exactly 2 ingredients in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  // Update GET_ADDRESS base in Check
  if (!base.type || !base.type->value || !contains_key(Type, base.type->value) || get(Type, base.type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get-address' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  reagent offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'get' should have type 'offset', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  int offset_value = 0;
  if (is_integer(offset.name)) {  // later layers permit non-integer offsets
    offset_value = to_integer(offset.name);
    if (offset_value < 0 || offset_value >= SIZE(get(Type, base_type).elements)) {
      raise << maybe(get(Recipe, r).name) << "invalid offset " << offset_value << " for " << get(Type, base_type).name << '\n' << end();
      break;
    }
  }
  else {
    offset_value = offset.value;
  }
  reagent product = inst.products.at(0);
  // Update GET_ADDRESS product in Check
  // same type as for GET..
  reagent element = element_type(base, offset_value);
  // ..except for an address at the start
  element.type = new type_tree("address", get(Type_ordinal, "address"), element.type);
  if (!types_coercible(product, element)) {
    raise << maybe(get(Recipe, r).name) << "'get-address " << base.original_string << ", " << offset.original_string << "' should write to " << names_to_string_without_quotes(element.type) << " but " << product.name << " has type " << names_to_string_without_quotes(product.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET_ADDRESS: {
  reagent base = current_instruction().ingredients.at(0);
  // Update GET_ADDRESS base in Run
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type).elements)) break;  // copied from Check above
  int result = base_address;
  for (int i = 0; i < offset; ++i) {
    // End GET_ADDRESS field Cases
    result += size_of(element_type(base, i));
  }
  trace(9998, "run") << "address to copy is " << result << end();
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario get_address_out_of_bounds)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-address 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset 2 for point-number

:(scenario get_address_out_of_bounds_2)
% Hide_errors = true;
def main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-address 12:point-number/raw, -1:offset
]
+error: main: invalid offset -1 for point-number

:(scenario get_address_product_type_mismatch)
% Hide_errors = true;
container boolbool [
  x:boolean
  y:boolean
]
def main [
  12:boolean <- copy 1
  13:boolean <- copy 0
  15:boolean <- get-address 12:boolbool, 1:offset
]
+error: main: 'get-address 12:boolbool, 1:offset' should write to (address boolean) but 15 has type boolean

//:: Allow containers to be defined in mu code.

:(scenarios load)
:(scenario container)
container foo [
  x:number
  y:number
]
+parse: --- defining container foo
+parse: element: {x: "number"}
+parse: element: {y: "number"}

:(scenario container_use_before_definition)
container foo [
  x:number
  y:bar
]

container bar [
  x:number
  y:number
]
+parse: --- defining container foo
+parse: type number: 1000
+parse:   element: {x: "number"}
# todo: brittle
# type bar is unknown at this point, but we assign it a number
+parse:   element: {y: "bar"}
# later type bar geon
+parse: --- defining container bar
+parse: type number: 1001
+parse:   element: {x: "number"}
+parse:   element: {y: "number"}

:(before "End Command Handlers")
else if (command == "container") {
  insert_container(command, CONTAINER, in);
}

:(code)
void insert_container(const string& command, kind_of_type kind, istream& in) {
  skip_whitespace_but_not_newline(in);
  string name = next_word(in);
  // End container Name Refinements
  trace(9991, "parse") << "--- defining " << command << ' ' << name << end();
  if (!contains_key(Type_ordinal, name)
      || get(Type_ordinal, name) == 0) {
    put(Type_ordinal, name, Next_type_ordinal++);
  }
  trace(9999, "parse") << "type number: " << get(Type_ordinal, name) << end();
  skip_bracket(in, "'container' must begin with '['");
  type_info& info = get_or_insert(Type, get(Type_ordinal, name));
  info.name = name;
  info.kind = kind;
  while (has_data(in)) {
    skip_whitespace_and_comments(in);
    string element = next_word(in);
    if (element == "]") break;
    info.elements.push_back(reagent(element));
    replace_unknown_types_with_unique_ordinals(info.elements.back().type, info);
    trace(9993, "parse") << "  element: " << to_string(info.elements.back()) << end();
    // End Load Container Element Definition
  }
  info.size = SIZE(info.elements);
}

void replace_unknown_types_with_unique_ordinals(type_tree* type, const type_info& info) {
  if (!type) return;
  if (!type->name.empty()) {
    if (contains_key(Type_ordinal, type->name)) {
      type->value = get(Type_ordinal, type->name);
    }
    else if (is_integer(type->name)) {  // sometimes types will contain non-type tags, like numbers for the size of an array
      type->value = 0;
    }
    // End insert_container Special-cases
    else if (type->name != "->") {  // used in recipe types
      put(Type_ordinal, type->name, Next_type_ordinal++);
      type->value = get(Type_ordinal, type->name);
    }
  }
  replace_unknown_types_with_unique_ordinals(type->left, info);
  replace_unknown_types_with_unique_ordinals(type->right, info);
}

void skip_bracket(istream& in, string message) {
  skip_whitespace_and_comments(in);
  if (in.get() != '[')
    raise << message << '\n' << end();
}

:(scenarios run)
:(scenario container_define_twice)
container foo [
  x:number
]

container foo [
  y:number
]

def main [
  1:number <- copy 34
  2:number <- copy 35
  3:number <- get 1:foo, 0:offset
  4:number <- get 1:foo, 1:offset
]
+mem: storing 34 in location 3
+mem: storing 35 in location 4

//: ensure scenarios are consistent by always starting them at the same type
//: number.
:(before "End Setup")  //: for tests
Next_type_ordinal = 1000;
:(before "End Test Run Initialization")
assert(Next_type_ordinal < 1000);

//:: Allow container definitions anywhere in the codebase, but complain if you
//:: can't find a definition at the end.

:(scenario run_complains_on_unknown_types)
% Hide_errors = true;
def main [
  # integer is not a type
  1:integer <- copy 0
]
+error: main: unknown type integer in '1:integer <- copy 0'

:(scenario run_allows_type_definition_after_use)
def main [
  1:bar <- copy 0/unsafe
]

container bar [
  x:number
]
$error: 0

:(after "Begin Instruction Modifying Transforms")
// Begin Type Modifying Transforms
Transform.push_back(check_or_set_invalid_types);  // idempotent
// End Type Modifying Transforms

:(code)
void check_or_set_invalid_types(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- check for invalid types in recipe " << caller.name << end();
  for (int index = 0; index < SIZE(caller.steps); ++index) {
    instruction& inst = caller.steps.at(index);
    for (int i = 0; i < SIZE(inst.ingredients); ++i)
      check_or_set_invalid_types(inst.ingredients.at(i).type, maybe(caller.name), "'"+to_original_string(inst)+"'");
    for (int i = 0; i < SIZE(inst.products); ++i)
      check_or_set_invalid_types(inst.products.at(i).type, maybe(caller.name), "'"+to_original_string(inst)+"'");
  }
  // End check_or_set_invalid_types
}

void check_or_set_invalid_types(type_tree* type, const string& block, const string& name) {
  if (!type) return;  // will throw a more precise error elsewhere
  // End Container Type Checks
  if (type->value == 0) return;
  if (!contains_key(Type, type->value)) {
    assert(!type->name.empty());
    if (contains_key(Type_ordinal, type->name))
      type->value = get(Type_ordinal, type->name);
    else
      raise << block << "unknown type " << type->name << " in " << name << '\n' << end();
  }
  check_or_set_invalid_types(type->left, block, name);
  check_or_set_invalid_types(type->right, block, name);
}

:(scenario container_unknown_field)
% Hide_errors = true;
container foo [
  x:number
  y:bar
]
+error: foo: unknown type in y

:(scenario read_container_with_bracket_in_comment)
container foo [
  x:number
  # ']' in comment
  y:number
]
+parse: --- defining container foo
+parse: element: {x: "number"}
+parse: element: {y: "number"}

:(before "End Transform All")
check_container_field_types();

:(code)
void check_container_field_types() {
  for (map<type_ordinal, type_info>::iterator p = Type.begin(); p != Type.end(); ++p) {
    const type_info& info = p->second;
    // Check Container Field Types(info)
    for (int i = 0; i < SIZE(info.elements); ++i)
      check_invalid_types(info.elements.at(i).type, maybe(info.name), info.elements.at(i).name);
  }
}

void check_invalid_types(const type_tree* type, const string& block, const string& name) {
  if (!type) return;  // will throw a more precise error elsewhere
  if (type->value == 0) {
    assert(!type->left && !type->right);
    return;
  }
  if (!contains_key(Type, type->value))
    raise << block << "unknown type in " << name << '\n' << end();
  check_invalid_types(type->left, block, name);
  check_invalid_types(type->right, block, name);
}

//:: Construct types out of their constituent fields.

:(scenario merge)
container foo [
  x:number
  y:number
]

def main [
  1:foo <- merge 3, 4
]
+mem: storing 3 in location 1
+mem: storing 4 in location 2

:(before "End Primitive Recipe Declarations")
MERGE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "merge", MERGE);
:(before "End Primitive Recipe Checks")
case MERGE: {
  // type-checking in a separate transform below
  break;
}
:(before "End Primitive Recipe Implementations")
case MERGE: {
  products.resize(1);
  for (int i = 0; i < SIZE(ingredients); ++i)
    for (int j = 0; j < SIZE(ingredients.at(i)); ++j)
      products.at(0).push_back(ingredients.at(i).at(j));
  break;
}

//: type-check 'merge' to avoid interpreting numbers as addresses

:(scenario merge_check)
def main [
  1:point <- merge 3, 4
]
$error: 0

:(scenario merge_check_missing_element)
% Hide_errors = true;
def main [
  1:point <- merge 3
]
+error: main: too few ingredients in '1:point <- merge 3'

:(scenario merge_check_extra_element)
% Hide_errors = true;
def main [
  1:point <- merge 3, 4, 5
]
+error: main: too many ingredients in '1:point <- merge 3, 4, 5'

//: We want to avoid causing memory corruption, but other than that we want to
//: be flexible in how we construct containers of containers. It should be
//: equally easy to define a container out of primitives or intermediate
//: container fields.

:(scenario merge_check_recursive_containers)
def main [
  1:point <- merge 3, 4
  1:point-number <- merge 1:point, 5
]
$error: 0

:(scenario merge_check_recursive_containers_2)
% Hide_errors = true;
def main [
  1:point <- merge 3, 4
  2:point-number <- merge 1:point
]
+error: main: too few ingredients in '2:point-number <- merge 1:point'

:(scenario merge_check_recursive_containers_3)
def main [
  1:point-number <- merge 3, 4, 5
]
$error: 0

:(scenario merge_check_recursive_containers_4)
% Hide_errors = true;
def main [
  1:point-number <- merge 3, 4
]
+error: main: too few ingredients in '1:point-number <- merge 3, 4'

//: Since a container can be merged in several ways, we need to be able to
//: backtrack through different possibilities. Later we'll allow creating
//: exclusive containers which contain just one of rather than all of their
//: elements. That will also require backtracking capabilities. Here's the
//: state we need to maintain for backtracking:

:(before "End Types")
struct merge_check_point {
  reagent container;
  int container_element_index;
  merge_check_point(const reagent& c, int i) :container(c), container_element_index(i) {}
};

struct merge_check_state {
  stack<merge_check_point> data;
};

:(before "End Checks")
Transform.push_back(check_merge_calls);
:(code)
void check_merge_calls(const recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- type-check merge instructions in recipe " << caller.name << end();
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    if (inst.name != "merge") continue;
    if (SIZE(inst.products) != 1) {
      raise << maybe(caller.name) << "'merge' should yield a single product in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    reagent product = inst.products.at(0);
    // Update product While Type-checking Merge
    type_ordinal product_type = product.type->value;
    if (product_type == 0 || !contains_key(Type, product_type)) {
      raise << maybe(caller.name) << "'merge' should yield a container in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    const type_info& info = get(Type, product_type);
    if (info.kind != CONTAINER && info.kind != EXCLUSIVE_CONTAINER) {
      raise << maybe(caller.name) << "'merge' should yield a container in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    check_merge_call(inst.ingredients, product, caller, inst);
  }
}

void check_merge_call(const vector<reagent>& ingredients, const reagent& product, const recipe& caller, const instruction& inst) {
  int ingredient_index = 0;
  merge_check_state state;
  state.data.push(merge_check_point(product, 0));
  while (true) {
    assert(!state.data.empty());
    trace(9999, "transform") << ingredient_index << " vs " << SIZE(ingredients) << end();
    if (ingredient_index >= SIZE(ingredients)) {
      raise << maybe(caller.name) << "too few ingredients in '" << to_original_string(inst) << "'\n" << end();
      return;
    }
    reagent& container = state.data.top().container;
    type_info& container_info = get(Type, container.type->value);
    switch (container_info.kind) {
      case CONTAINER: {
        reagent expected_ingredient = element_type(container, state.data.top().container_element_index);
        trace(9999, "transform") << "checking container " << to_string(container) << " || " << to_string(expected_ingredient) << " vs ingredient " << ingredient_index << end();
        // if the current element is the ingredient we expect, move on to the next element/ingredient
        if (types_coercible(expected_ingredient, ingredients.at(ingredient_index))) {
          ++ingredient_index;
          ++state.data.top().container_element_index;
          while (state.data.top().container_element_index >= SIZE(get(Type, state.data.top().container.type->value).elements)) {
            state.data.pop();
            if (state.data.empty()) {
              if (ingredient_index < SIZE(ingredients))
                raise << maybe(caller.name) << "too many ingredients in '" << to_original_string(inst) << "'\n" << end();
              return;
            }
            ++state.data.top().container_element_index;
          }
        }
        // if not, maybe it's a field of the current element
        else {
          // no change to ingredient_index
          state.data.push(merge_check_point(expected_ingredient, 0));
        }
        break;
      }
      // End valid_merge Cases
      default: {
        if (!types_coercible(container, ingredients.at(ingredient_index))) {
          raise << maybe(caller.name) << "incorrect type of ingredient " << ingredient_index << " in '" << to_original_string(inst) << "'\n" << end();
          cerr << "  expected " << debug_string(container) << '\n';
          cerr << "  got " << debug_string(ingredients.at(ingredient_index)) << '\n';
          return;
        }
        ++ingredient_index;
        // ++state.data.top().container_element_index;  // unnecessary, but wouldn't do any harm
        do {
          state.data.pop();
          if (state.data.empty()) {
            if (ingredient_index < SIZE(ingredients))
              raise << maybe(caller.name) << "too many ingredients in '" << to_original_string(inst) << "'\n" << end();
            return;
          }
          ++state.data.top().container_element_index;
        } while (state.data.top().container_element_index >= SIZE(get(Type, state.data.top().container.type->value).elements));
      }
    }
  }
  // never gets here
  assert(false);
}

:(scenario merge_check_product)
% Hide_errors = true;
def main [
  1:number <- merge 3
]
+error: main: 'merge' should yield a container in '1:number <- merge 3'

:(before "End Includes")
#include <stack>
using std::stack;

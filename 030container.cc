//: Containers contain a fixed number of elements of different types.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
type_ordinal point = put(Type_ordinal, "point", Next_type_ordinal++);
get_or_insert(Type, point);  // initialize
get(Type, point).kind = CONTAINER;
get(Type, point).name = "point";
get(Type, point).elements.push_back(reagent("x:number"));
get(Type, point).elements.push_back(reagent("y:number"));

//: Containers can be copied around with a single instruction just like
//: numbers, no matter how large they are.

//: Tests in this layer often explicitly set up memory before reading it as a
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
get_or_insert(Type, point_number);  // initialize
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

//: products of recipes can include containers
:(scenario return_container)
def main [
  3:point <- f 2
]
def f [
  12:number <- next-ingredient
  13:number <- copy 35
  return 12:point/raw
]
+run: result 0 is [2, 35]
+mem: storing 2 in location 3
+mem: storing 35 in location 4

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

//: Global data structure for container metadata.
//: Can't put this in type_info because later layers will add support for more
//: complex type trees where metadata depends not just on the root of the type tree.

:(after "Types")
struct container_metadata {
  int size;
  vector<int> offset;
  // End container_metadata Fields
  container_metadata() :size(0) {
    // End container_metadata Constructor
  }
};
:(before "End reagent Fields")
container_metadata metadata;  // can't be a pointer into Container_metadata because we keep changing the base storage when we save/restore snapshots
:(before "End reagent Copy Operator")
metadata = old.metadata;
:(before "End reagent Copy Constructor")
metadata = old.metadata;

:(before "End Globals")
// todo: switch to map after figuring out how to consistently compare type trees
vector<pair<type_tree*, container_metadata> > Container_metadata, Container_metadata_snapshot;
:(before "End save_snapshots")
Container_metadata_snapshot = Container_metadata;
:(before "End restore_snapshots")
restore_container_metadata();
:(before "End One-time Setup")
atexit(clear_container_metadata);
:(code)
// invariant: Container_metadata always contains a superset of Container_metadata_snapshot
void restore_container_metadata() {
  for (int i = 0; i < SIZE(Container_metadata); ++i) {
    assert(Container_metadata.at(i).first);
    if (i < SIZE(Container_metadata_snapshot)) {
      assert(Container_metadata.at(i).first == Container_metadata_snapshot.at(i).first);
      continue;
    }
    delete Container_metadata.at(i).first;
    Container_metadata.at(i).first = NULL;
  }
  Container_metadata.resize(SIZE(Container_metadata_snapshot));
}
void clear_container_metadata() {
  Container_metadata_snapshot.clear();
  for (int i = 0; i < SIZE(Container_metadata); ++i) {
    delete Container_metadata.at(i).first;
    Container_metadata.at(i).first = NULL;
  }
  Container_metadata.clear();
}

//: do no work in size_of, simply lookup Container_metadata

:(before "End size_of(reagent r) Cases")
if (r.metadata.size) return r.metadata.size;

:(before "End size_of(type) Cases")
if (type->value == -1) return 1;  // error value, but we'll raise it elsewhere
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
  // Compute size_of Container
  return get(Container_metadata, type).size;
}

//: precompute Container_metadata before we need size_of
//: also store a copy in each reagent in each instruction in each recipe

:(after "Begin Instruction Modifying Transforms")  // needs to happen before transform_names, therefore after "End Type Modifying Transforms" below
Transform.push_back(compute_container_sizes);
:(code)
void compute_container_sizes(recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    for (int i = 0; i < SIZE(inst.ingredients); ++i)
      compute_container_sizes(inst.ingredients.at(i));
    for (int i = 0; i < SIZE(inst.products); ++i)
      compute_container_sizes(inst.products.at(i));
  }
}

void compute_container_sizes(reagent& r) {
  if (is_literal(r) || is_dummy(r)) return;
  reagent rcopy = r;
  // Compute Container Size(reagent rcopy)
  set<type_ordinal> pending_metadata;
  compute_container_sizes(rcopy.type, pending_metadata);
  if (contains_key(Container_metadata, rcopy.type))
    r.metadata = get(Container_metadata, rcopy.type);
}

void compute_container_sizes(const type_tree* type, set<type_ordinal>& pending_metadata) {
  if (!type) return;
  if (contains_key(pending_metadata, type->value)) return;
  if (type->value) pending_metadata.insert(type->value);
  if (contains_key(Container_metadata, type)) return;
  if (type->left) compute_container_sizes(type->left, pending_metadata);
  if (type->right) compute_container_sizes(type->right, pending_metadata);
  if (!contains_key(Type, type->value)) return;  // error raised elsewhere
  type_info& info = get(Type, type->value);
  if (info.kind == CONTAINER) {
    container_metadata metadata;
    for (int i = 0; i < SIZE(info.elements); ++i) {
      reagent/*copy*/ element = info.elements.at(i);
      // Compute Container Size(element)
      compute_container_sizes(element.type, pending_metadata);
      metadata.offset.push_back(metadata.size);  // save previous size as offset
      metadata.size += size_of(element.type);
    }
    Container_metadata.push_back(pair<type_tree*, container_metadata>(new type_tree(*type), metadata));
  }
  // End compute_container_sizes Cases
}

container_metadata& get(vector<pair<type_tree*, container_metadata> >& all, const type_tree* key) {
  for (int i = 0; i < SIZE(all); ++i) {
    if (matches(all.at(i).first, key))
      return all.at(i).second;
  }
  tb_shutdown();
  raise << "unknown size for type " << to_string(key) << '\n' << end();
  assert(false);
}

bool contains_key(const vector<pair<type_tree*, container_metadata> >& all, const type_tree* key) {
  for (int i = 0; i < SIZE(all); ++i) {
    if (matches(all.at(i).first, key))
      return true;
  }
  return false;
}

bool matches(const type_tree* a, const type_tree* b) {
  if (a == b) return true;
  if (!a || !b) return false;
  if (a->value != b->value) return false;
  return matches(a->left, b->left) && matches(a->right, b->right);
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
  reagent/*copy*/ base = inst.ingredients.at(0);  // new copy for every invocation
  // Update GET base in Check
  if (!base.type || !base.type->value || !contains_key(Type, base.type->value) || get(Type, base.type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  const reagent& offset = inst.ingredients.at(1);
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
  reagent/*copy*/ product = inst.products.at(0);
  // Update GET product in Check
  const reagent/*copy*/ element = element_type(base.type, offset_value);
  if (!types_coercible(product, element)) {
    raise << maybe(get(Recipe, r).name) << "'get " << base.original_string << ", " << offset.original_string << "' should write to " << names_to_string_without_quotes(element.type) << " but " << product.name << " has type " << names_to_string_without_quotes(product.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET: {
  reagent/*copy*/ base = current_instruction().ingredients.at(0);
  // Update GET base in Run
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type).elements)) break;  // copied from Check above
  assert(base.metadata.size);
  int src = base_address + base.metadata.offset.at(offset);
  trace(9998, "run") << "address to copy is " << src << end();
  reagent/*copy*/ element = element_type(base.type, offset);
  element.set_value(src);
  trace(9998, "run") << "its type is " << names_to_string(element.type) << end();
  // Read element
  products.push_back(read_memory(element));
  break;
}

:(code)
const reagent element_type(const type_tree* type, int offset_value) {
  assert(offset_value >= 0);
  assert(contains_key(Type, type->value));
  assert(!get(Type, type->value).name.empty());
  const type_info& info = get(Type, type->value);
  assert(info.kind == CONTAINER);
  reagent/*copy*/ element = info.elements.at(offset_value);
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

//:: To write to elements of containers, use 'put'.

:(scenario put)
def main [
  12:number <- copy 34
  13:number <- copy 35
  $clear-trace
  12:point <- put 12:point, 1:offset, 36
]
+mem: storing 36 in location 13
-mem: storing 34 in location 12

:(before "End Primitive Recipe Declarations")
PUT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "put", PUT);
:(before "End Primitive Recipe Checks")
case PUT: {
  if (SIZE(inst.ingredients) != 3) {
    raise << maybe(get(Recipe, r).name) << "'put' expects exactly 3 ingredients in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  reagent/*copy*/ base = inst.ingredients.at(0);
  // Update PUT base in Check
  if (!base.type || !base.type->value || !contains_key(Type, base.type->value) || get(Type, base.type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'put' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  reagent/*copy*/ offset = inst.ingredients.at(1);
  // Update PUT offset in Check
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'put' should have type 'offset', but got " << inst.ingredients.at(1).original_string << '\n' << end();
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
  const reagent& value = inst.ingredients.at(2);
  const reagent& element = element_type(base.type, offset_value);
  if (!types_coercible(element, value)) {
    raise << maybe(get(Recipe, r).name) << "'put " << base.original_string << ", " << offset.original_string << "' should store " << names_to_string_without_quotes(element.type) << " but " << value.name << " has type " << names_to_string_without_quotes(value.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case PUT: {
  reagent/*copy*/ base = current_instruction().ingredients.at(0);
  // Update PUT base in Run
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type).elements)) break;  // copied from Check above
  int address = base_address + base.metadata.offset.at(offset);
  trace(9998, "run") << "address to copy to is " << address << end();
  // optimization: directly write the element rather than updating 'product'
  // and writing the entire container
  // Write Memory in PUT in Run
  for (int i = 0; i < SIZE(ingredients.at(2)); ++i) {
    trace(9999, "mem") << "storing " << no_scientific(ingredients.at(2).at(i)) << " in location " << address+i << end();
    put(Memory, address+i, ingredients.at(2).at(i));
  }
  goto finish_instruction;
}

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

//: if a container is defined again, the new fields add to the original definition
:(scenarios run)
:(scenario container_extend)
container foo [
  x:number
]
# add to previous definition
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

:(before "End Command Handlers")
else if (command == "container") {
  insert_container(command, CONTAINER, in);
}

//: Even though we allow containers to be extended, we don't allow this after
//: a call to transform_all. But we do want to detect this situation and raise
//: an error. This field will help us raise such errors.
:(before "End type_info Fields")
int Num_calls_to_transform_all_at_first_definition;
:(before "End type_info Constructor")
Num_calls_to_transform_all_at_first_definition = -1;

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
  if (info.Num_calls_to_transform_all_at_first_definition == -1) {
    // initial definition of this container
    info.Num_calls_to_transform_all_at_first_definition = Num_calls_to_transform_all;
  }
  else if (info.Num_calls_to_transform_all_at_first_definition != Num_calls_to_transform_all) {
    // extension after transform_all
    raise << "there was a call to transform_all() between the definition of container " << name << " and a subsequent extension. This is not supported, since any recipes that used " << name << " values have already been transformed and 'frozen'.\n" << end();
    return;
  }
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

//: ensure scenarios are consistent by always starting them at the same type
//: number.
:(before "End Setup")  //: for tests
Next_type_ordinal = 1000;
:(before "End Test Run Initialization")
assert(Next_type_ordinal < 1000);

:(code)
void test_error_on_transform_all_between_container_definition_and_extension() {
  // define a container
  run("container foo [\n"
      "  a:number\n"
      "]\n");
  // try to extend the container after transform
  transform_all();
  CHECK_TRACE_DOESNT_CONTAIN_ERROR();
  Hide_errors = true;
  run("container foo [\n"
      "  b:number\n"
      "]\n");
  CHECK_TRACE_CONTAINS_ERROR();
}

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

:(before "End transform_all")
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

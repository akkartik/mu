//: Containers contain a fixed number of elements of different types.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example in scenarios below.
type_ordinal point = put(Type_ordinal, "point", Next_type_ordinal++);
get_or_insert(Type, point);  // initialize
get(Type, point).kind = CONTAINER;
get(Type, point).name = "point";
get(Type, point).elements.push_back(reagent("x:number"));
get(Type, point).elements.push_back(reagent("y:number"));

//: Containers can be copied around with a single instruction just like
//: numbers, no matter how large they are.

//: Tests in this layer often explicitly set up memory before reading it as a
//: container. Don't do this in general. I'm tagging exceptions with /unsafe to
//: skip later checks.
:(scenario copy_multiple_locations)
def main [
  1:num <- copy 34
  2:num <- copy 35
  3:point <- copy 1:point/unsafe
]
+mem: storing 34 in location 3
+mem: storing 35 in location 4

//: trying to copy to a differently-typed destination will fail
:(scenario copy_checks_size)
% Hide_errors = true;
def main [
  2:point <- copy 1:num
]
+error: main: can't copy '1:num' to '2:point'; types don't match

:(before "End Mu Types Initialization")
// A more complex example container, containing another container as one of
// its elements.
type_ordinal point_number = put(Type_ordinal, "point-number", Next_type_ordinal++);
get_or_insert(Type, point_number);  // initialize
get(Type, point_number).kind = CONTAINER;
get(Type, point_number).name = "point-number";
get(Type, point_number).elements.push_back(reagent("xy:point"));
get(Type, point_number).elements.push_back(reagent("z:number"));

:(scenario copy_handles_nested_container_elements)
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  15:point-number <- copy 12:point-number/unsafe
]
+mem: storing 36 in location 17

//: products of recipes can include containers
:(scenario return_container)
def main [
  3:point <- f 2
]
def f [
  12:num <- next-ingredient
  13:num <- copy 35
  return 12:point/raw
]
+run: result 0 is [2, 35]
+mem: storing 2 in location 3
+mem: storing 35 in location 4

//: Containers can be checked for equality with a single instruction just like
//: numbers, no matter how large they are.

:(scenario compare_multiple_locations)
def main [
  1:num <- copy 34  # first
  2:num <- copy 35
  3:num <- copy 36
  4:num <- copy 34  # second
  5:num <- copy 35
  6:num <- copy 36
  7:bool <- equal 1:point-number/raw, 4:point-number/unsafe
]
+mem: storing 1 in location 7

:(scenario compare_multiple_locations_2)
def main [
  1:num <- copy 34  # first
  2:num <- copy 35
  3:num <- copy 36
  4:num <- copy 34  # second
  5:num <- copy 35
  6:num <- copy 37  # different
  7:bool <- equal 1:point-number/raw, 4:point-number/unsafe
]
+mem: storing 0 in location 7

//: Can't put this in type_info because later layers will add support for more
//: complex type trees where metadata depends on *combinations* of types.
:(before "struct reagent")
struct container_metadata {
  int size;
  vector<int> offset;  // not used by exclusive containers
  // End container_metadata Fields
  container_metadata() :size(0) {
    // End container_metadata Constructor
  }
};
:(before "End reagent Fields")
container_metadata metadata;  // can't be a pointer into Container_metadata because we keep changing the base storage when we save/restore snapshots
:(before "End reagent Copy Operator")
metadata = other.metadata;
:(before "End reagent Copy Constructor")
metadata = other.metadata;

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
  for (int i = 0;  i < SIZE(Container_metadata);  ++i) {
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
  for (int i = 0;  i < SIZE(Container_metadata);  ++i) {
    delete Container_metadata.at(i).first;
    Container_metadata.at(i).first = NULL;
  }
  Container_metadata.clear();
}

//: do no work in size_of, simply lookup Container_metadata

:(before "End size_of(reagent r) Special-cases")
if (r.metadata.size) return r.metadata.size;

:(before "End size_of(type) Special-cases")
const type_tree* base_type = type;
// Update base_type in size_of(type)
if (!contains_key(Type, base_type->value)) {
  raise << "no such type " << base_type->value << '\n' << end();
  return 0;
}
type_info t = get(Type, base_type->value);
if (t.kind == CONTAINER) {
  // Compute size_of Container
  if (!contains_key(Container_metadata, type)) {
    raise << "unknown size for container type '" << to_string(type) << "'\n" << end();
//?     DUMP("");
    return 0;
  }
  return get(Container_metadata, type).size;
}

//: precompute Container_metadata before we need size_of
//: also store a copy in each reagent in each instruction in each recipe

:(after "End Type Modifying Transforms")
Transform.push_back(compute_container_sizes);  // idempotent
:(code)
void compute_container_sizes(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9992, "transform") << "--- compute container sizes for " << caller.name << end();
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    instruction& inst = caller.steps.at(i);
    trace(9993, "transform") << "- compute container sizes for " << to_string(inst) << end();
    for (int i = 0;  i < SIZE(inst.ingredients);  ++i)
      compute_container_sizes(inst.ingredients.at(i), " in '"+to_original_string(inst)+"'");
    for (int i = 0;  i < SIZE(inst.products);  ++i)
      compute_container_sizes(inst.products.at(i), " in '"+to_original_string(inst)+"'");
  }
}

void compute_container_sizes(reagent& r, const string& location_for_error_messages) {
  expand_type_abbreviations(r.type);
  if (is_literal(r) || is_dummy(r)) return;
  reagent rcopy = r;
  // Compute Container Size(reagent rcopy)
  set<type_tree> pending_metadata;  // might actually be faster to just convert to string rather than compare type_tree directly; so far the difference is negligible
  compute_container_sizes(rcopy.type, pending_metadata, location_for_error_messages);
  if (contains_key(Container_metadata, rcopy.type))
    r.metadata = get(Container_metadata, rcopy.type);
}

void compute_container_sizes(const type_tree* type, set<type_tree>& pending_metadata, const string& location_for_error_messages) {
  if (!type) return;
  trace(9993, "transform") << "compute container sizes for " << to_string(type) << end();
  if (contains_key(Container_metadata, type)) return;
  if (contains_key(pending_metadata, *type)) return;
  pending_metadata.insert(*type);
  if (!type->atom) {
    if (!type->left->atom) {
      raise << "invalid type " << to_string(type) << location_for_error_messages << '\n' << end();
      return;
    }
    if (type->left->name == "address")
      compute_container_sizes(payload_type(type), pending_metadata, location_for_error_messages);
    // End compute_container_sizes Non-atom Special-cases
    return;
  }
  assert(type->atom);
  if (!contains_key(Type, type->value)) return;  // error raised elsewhere
  type_info& info = get(Type, type->value);
  if (info.kind == CONTAINER)
    compute_container_sizes(info, type, pending_metadata, location_for_error_messages);
  // End compute_container_sizes Atom Special-cases
}

void compute_container_sizes(const type_info& container_info, const type_tree* full_type, set<type_tree>& pending_metadata, const string& location_for_error_messages) {
  assert(container_info.kind == CONTAINER);
  // size of a container is the sum of the sizes of its element
  // (So it can only contain arrays if they're static and include their
  // length in the type.)
  container_metadata metadata;
  for (int i = 0;  i < SIZE(container_info.elements);  ++i) {
    reagent/*copy*/ element = container_info.elements.at(i);
    // Compute Container Size(element, full_type)
    compute_container_sizes(element.type, pending_metadata, location_for_error_messages);
    metadata.offset.push_back(metadata.size);  // save previous size as offset
    metadata.size += size_of(element.type);
  }
  Container_metadata.push_back(pair<type_tree*, container_metadata>(new type_tree(*full_type), metadata));
}

const type_tree* payload_type(const type_tree* type) {
  assert(!type->atom);
  const type_tree* result = type->right;
  assert(!result->atom);
  if (!result->right) return result->left;
  return result;
}

container_metadata& get(vector<pair<type_tree*, container_metadata> >& all, const type_tree* key) {
  for (int i = 0;  i < SIZE(all);  ++i) {
    if (matches(all.at(i).first, key))
      return all.at(i).second;
  }
  tb_shutdown();
  raise << "unknown size for type '" << to_string(key) << "'\n" << end();
  assert(false);
}

bool contains_key(const vector<pair<type_tree*, container_metadata> >& all, const type_tree* key) {
  for (int i = 0;  i < SIZE(all);  ++i) {
    if (matches(all.at(i).first, key))
      return true;
  }
  return false;
}

bool matches(const type_tree* a, const type_tree* b) {
  if (a == b) return true;
  if (!a || !b) return false;
  if (a->atom != b->atom) return false;
  if (a->atom) return a->value == b->value;
  return matches(a->left, b->left) && matches(a->right, b->right);
}

:(scenario stash_container)
def main [
  1:num <- copy 34  # first
  2:num <- copy 35
  3:num <- copy 36
  stash [foo:], 1:point-number/raw
]
+app: foo: 34 35 36

//: for the following unit tests we'll do the work of the transform by hand

:(before "End Unit Tests")
void test_container_sizes() {
  // a container we don't have the size for
  reagent r("x:point");
  CHECK(!contains_key(Container_metadata, r.type));
  // scan
  compute_container_sizes(r, "");
  // the reagent we scanned knows its size
  CHECK_EQ(r.metadata.size, 2);
  // the global table also knows its size
  CHECK(contains_key(Container_metadata, r.type));
  CHECK_EQ(get(Container_metadata, r.type).size, 2);
}

void test_container_sizes_through_aliases() {
  // a new alias for a container
  put(Type_abbreviations, "pt", new_type_tree("point"));
  reagent r("x:pt");
  // scan
  compute_container_sizes(r, "");
  // the reagent we scanned knows its size
  CHECK_EQ(r.metadata.size, 2);
  // the global table also knows its size
  CHECK(contains_key(Container_metadata, r.type));
  CHECK_EQ(get(Container_metadata, r.type).size, 2);
}

void test_container_sizes_nested() {
  // a container we don't have the size for
  reagent r("x:point-number");
  CHECK(!contains_key(Container_metadata, r.type));
  // scan
  compute_container_sizes(r, "");
  // the reagent we scanned knows its size
  CHECK_EQ(r.metadata.size, 3);
  // the global table also knows its size
  CHECK(contains_key(Container_metadata, r.type));
  CHECK_EQ(get(Container_metadata, r.type).size, 3);
}

void test_container_sizes_recursive() {
  // define a container containing an address to itself
  run("container foo [\n"
      "  x:num\n"
      "  y:address:foo\n"
      "]\n");
  reagent r("x:foo");
  compute_container_sizes(r, "");
  CHECK_EQ(r.metadata.size, 2);
}

void test_container_sizes_from_address() {
  // a container we don't have the size for
  reagent container("x:point");
  CHECK(!contains_key(Container_metadata, container.type));
  // scanning an address to the container precomputes the size of the container
  reagent r("x:address:point");
  compute_container_sizes(r, "");
  CHECK(contains_key(Container_metadata, container.type));
  CHECK_EQ(get(Container_metadata, container.type).size, 2);
}

//:: To access elements of a container, use 'get'
//: 'get' takes a 'base' container and an 'offset' into it and returns the
//: appropriate element of the container value.

:(scenario get)
def main [
  12:num <- copy 34
  13:num <- copy 35
  15:num <- get 12:point/raw, 1:offset  # unsafe
]
+mem: storing 35 in location 15

:(before "End Primitive Recipe Declarations")
GET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "get", GET);
:(before "End Primitive Recipe Checks")
case GET: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'get' expects exactly 2 ingredients in '" << inst.original_string << "'\n" << end();
    break;
  }
  reagent/*copy*/ base = inst.ingredients.at(0);  // new copy for every invocation
  // Update GET base in Check
  if (!base.type) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get' should be a container, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  const type_tree* base_type = base.type;
  // Update GET base_type in Check
  if (!base_type->atom || base_type->value == 0 || !contains_key(Type, base_type->value) || get(Type, base_type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'get' should be a container, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  const reagent& offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'get' should have type 'offset', but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  int offset_value = 0;
  //: later layers will permit non-integer offsets
  if (is_integer(offset.name))
    offset_value = to_integer(offset.name);
  else
    offset_value = offset.value;
  if (offset_value < 0 || offset_value >= SIZE(get(Type, base_type->value).elements)) {
    raise << maybe(get(Recipe, r).name) << "invalid offset '" << offset_value << "' for '" << get(Type, base_type->value).name << "'\n" << end();
    break;
  }
  if (inst.products.empty()) break;
  reagent/*copy*/ product = inst.products.at(0);
  // Update GET product in Check
  //: use base.type rather than base_type because later layers will introduce compound types
  const reagent/*copy*/ element = element_type(base.type, offset_value);
  if (!types_coercible(product, element)) {
    raise << maybe(get(Recipe, r).name) << "'get " << base.original_string << ", " << offset.original_string << "' should write to " << names_to_string_without_quotes(element.type) << " but '" << product.name << "' has type " << names_to_string_without_quotes(product.type) << '\n' << end();
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
  const type_tree* base_type = base.type;
  // Update GET base_type in Run
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type->value).elements)) break;  // copied from Check above
  assert(base.metadata.size);
  int src = base_address + base.metadata.offset.at(offset);
  trace(9998, "run") << "address to copy is " << src << end();
  //: use base.type rather than base_type because later layers will introduce compound types
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
  const type_tree* base_type = type;
  // Update base_type in element_type
  assert(contains_key(Type, base_type->value));
  assert(!get(Type, base_type->value).name.empty());
  const type_info& info = get(Type, base_type->value);
  assert(info.kind == CONTAINER);
  if (offset_value >= SIZE(info.elements)) return reagent();  // error handled elsewhere
  reagent/*copy*/ element = info.elements.at(offset_value);
  // End element_type Special-cases
  return element;
}

:(scenario get_handles_nested_container_elements)
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  15:num <- get 12:point-number/raw, 1:offset  # unsafe
]
+mem: storing 36 in location 15

:(scenario get_out_of_bounds)
% Hide_errors = true;
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  get 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset '2' for 'point-number'

:(scenario get_out_of_bounds_2)
% Hide_errors = true;
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  get 12:point-number/raw, -1:offset
]
+error: main: invalid offset '-1' for 'point-number'

:(scenario get_product_type_mismatch)
% Hide_errors = true;
def main [
  12:num <- copy 34
  13:num <- copy 35
  14:num <- copy 36
  15:address:num <- get 12:point-number/raw, 1:offset
]
+error: main: 'get 12:point-number/raw, 1:offset' should write to number but '15' has type (address number)

//: we might want to call 'get' without saving the results, say in a sandbox

:(scenario get_without_product)
def main [
  12:num <- copy 34
  13:num <- copy 35
  get 12:point/raw, 1:offset  # unsafe
]
# just don't die

//:: To write to elements of containers, use 'put'.

:(scenario put)
def main [
  12:num <- copy 34
  13:num <- copy 35
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
    raise << maybe(get(Recipe, r).name) << "'put' expects exactly 3 ingredients in '" << inst.original_string << "'\n" << end();
    break;
  }
  reagent/*copy*/ base = inst.ingredients.at(0);
  // Update PUT base in Check
  if (!base.type) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'put' should be a container, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  const type_tree* base_type = base.type;
  // Update PUT base_type in Check
  if (!base_type->atom || base_type->value == 0 || !contains_key(Type, base_type->value) || get(Type, base_type->value).kind != CONTAINER) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'put' should be a container, but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  reagent/*copy*/ offset = inst.ingredients.at(1);
  // Update PUT offset in Check
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'put' should have type 'offset', but got '" << inst.ingredients.at(1).original_string << "'\n" << end();
    break;
  }
  int offset_value = 0;
  //: later layers will permit non-integer offsets
  if (is_integer(offset.name)) {
    offset_value = to_integer(offset.name);
    if (offset_value < 0 || offset_value >= SIZE(get(Type, base_type->value).elements)) {
      raise << maybe(get(Recipe, r).name) << "invalid offset '" << offset_value << "' for '" << get(Type, base_type->value).name << "'\n" << end();
      break;
    }
  }
  else {
    offset_value = offset.value;
  }
  const reagent& value = inst.ingredients.at(2);
  //: use base.type rather than base_type because later layers will introduce compound types
  const reagent& element = element_type(base.type, offset_value);
  if (!types_coercible(element, value)) {
    raise << maybe(get(Recipe, r).name) << "'put " << base.original_string << ", " << offset.original_string << "' should write to " << names_to_string_without_quotes(element.type) << " but '" << value.name << "' has type " << names_to_string_without_quotes(value.type) << '\n' << end();
    break;
  }
  if (inst.products.empty()) break;  // no more checks necessary
  if (inst.products.at(0).name != inst.ingredients.at(0).name) {
    raise << maybe(get(Recipe, r).name) << "product of 'put' must be first ingredient '" << inst.ingredients.at(0).original_string << "', but got '" << inst.products.at(0).original_string << "'\n" << end();
    break;
  }
  // End PUT Product Checks
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
  const type_tree* base_type = base.type;
  // Update PUT base_type in Run
  int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(get(Type, base_type->value).elements)) break;  // copied from Check above
  int address = base_address + base.metadata.offset.at(offset);
  trace(9998, "run") << "address to copy to is " << address << end();
  // optimization: directly write the element rather than updating 'product'
  // and writing the entire container
  // Write Memory in PUT in Run
  for (int i = 0;  i < SIZE(ingredients.at(2));  ++i) {
    trace(9999, "mem") << "storing " << no_scientific(ingredients.at(2).at(i)) << " in location " << address+i << end();
    put(Memory, address+i, ingredients.at(2).at(i));
  }
  goto finish_instruction;
}

:(scenario put_product_error)
% Hide_errors = true;
def main [
  local-scope
  load-ingredients
  1:point <- merge 34, 35
  3:point <- put 1:point, x:offset, 36
]
+error: main: product of 'put' must be first ingredient '1:point', but got '3:point'

//:: Allow containers to be defined in Mu code.

:(scenarios load)
:(scenario container)
container foo [
  x:num
  y:num
]
+parse: --- defining container foo
+parse: element: {x: "number"}
+parse: element: {y: "number"}

:(scenario container_use_before_definition)
container foo [
  x:num
  y:bar
]
container bar [
  x:num
  y:num
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
  x:num
]
# add to previous definition
container foo [
  y:num
]
def main [
  1:num <- copy 34
  2:num <- copy 35
  3:num <- get 1:foo, 0:offset
  4:num <- get 1:foo, 1:offset
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
  if (name.empty()) {
    assert(!has_data(in));
    raise << "incomplete container definition at end of file (0)\n" << end();
    return;
  }
  // End container Name Refinements
  trace(9991, "parse") << "--- defining " << command << ' ' << name << end();
  if (!contains_key(Type_ordinal, name)
      || get(Type_ordinal, name) == 0) {
    put(Type_ordinal, name, Next_type_ordinal++);
  }
  trace(9999, "parse") << "type number: " << get(Type_ordinal, name) << end();
  skip_bracket(in, "'"+command+"' must begin with '['");
  type_info& info = get_or_insert(Type, get(Type_ordinal, name));
  if (info.Num_calls_to_transform_all_at_first_definition == -1) {
    // initial definition of this container
    info.Num_calls_to_transform_all_at_first_definition = Num_calls_to_transform_all;
  }
  else if (info.Num_calls_to_transform_all_at_first_definition != Num_calls_to_transform_all) {
    // extension after transform_all
    raise << "there was a call to transform_all() between the definition of container '" << name << "' and a subsequent extension. This is not supported, since any recipes that used '" << name << "' values have already been transformed and \"frozen\".\n" << end();
    return;
  }
  info.name = name;
  info.kind = kind;
  while (has_data(in)) {
    skip_whitespace_and_comments(in);
    string element = next_word(in);
    if (element.empty()) {
      assert(!has_data(in));
      raise << "incomplete container definition at end of file (1)\n" << end();
      return;
    }
    if (element == "]") break;
    if (in.peek() != '\n') {
      raise << command << " '" << name << "' contains multiple elements on a single line. Containers and exclusive containers must only contain elements, one to a line, no code.\n" << end();
      // skip rest of container declaration
      while (has_data(in)) {
        skip_whitespace_and_comments(in);
        if (next_word(in) == "]") break;
      }
      break;
    }
    info.elements.push_back(reagent(element));
    expand_type_abbreviations(info.elements.back().type);  // todo: use abbreviation before declaration
    replace_unknown_types_with_unique_ordinals(info.elements.back().type, info);
    trace(9993, "parse") << "  element: " << to_string(info.elements.back()) << end();
    // End Load Container Element Definition
  }
}

void replace_unknown_types_with_unique_ordinals(type_tree* type, const type_info& info) {
  if (!type) return;
  if (!type->atom) {
    replace_unknown_types_with_unique_ordinals(type->left, info);
    replace_unknown_types_with_unique_ordinals(type->right, info);
    return;
  }
  assert(!type->name.empty());
  if (contains_key(Type_ordinal, type->name)) {
    type->value = get(Type_ordinal, type->name);
  }
  // End insert_container Special-cases
  else if (type->name != "->") {  // used in recipe types
    put(Type_ordinal, type->name, Next_type_ordinal++);
    type->value = get(Type_ordinal, type->name);
  }
}

void skip_bracket(istream& in, string message) {
  skip_whitespace_and_comments(in);
  if (in.get() != '[')
    raise << message << '\n' << end();
}

:(scenario multi_word_line_in_container_declaration)
% Hide_errors = true;
container foo [
  x:num y:num
]
+error: container 'foo' contains multiple elements on a single line. Containers and exclusive containers must only contain elements, one to a line, no code.

//: support type abbreviations in container definitions

:(scenario type_abbreviations_in_containers)
type foo = number
container bar [
  x:foo
]
def main [
  1:num <- copy 34
  2:foo <- get 1:bar/unsafe, 0:offset
]
+mem: storing 34 in location 2

:(after "Transform.push_back(expand_type_abbreviations)")
Transform.push_back(expand_type_abbreviations_in_containers);  // idempotent
:(code)
// extremely inefficient; we process all types over and over again, once for every single recipe
// but it doesn't seem to cause any noticeable slowdown
void expand_type_abbreviations_in_containers(unused const recipe_ordinal r) {
  for (map<type_ordinal, type_info>::iterator p = Type.begin();  p != Type.end();  ++p) {
    for (int i = 0;  i < SIZE(p->second.elements);  ++i)
      expand_type_abbreviations(p->second.elements.at(i).type);
  }
}

//: ensure scenarios are consistent by always starting new container
//: declarations at the same type number
:(before "End Setup")  //: for tests
Next_type_ordinal = 1000;
:(before "End Test Run Initialization")
assert(Next_type_ordinal < 1000);

:(code)
void test_error_on_transform_all_between_container_definition_and_extension() {
  // define a container
  run("container foo [\n"
      "  a:num\n"
      "]\n");
  // try to extend the container after transform
  transform_all();
  CHECK_TRACE_DOESNT_CONTAIN_ERRORS();
  Hide_errors = true;
  run("container foo [\n"
      "  b:num\n"
      "]\n");
  CHECK_TRACE_CONTAINS_ERRORS();
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
  x:num
]
$error: 0

:(before "End Type Modifying Transforms")
Transform.push_back(check_or_set_invalid_types);  // idempotent

:(code)
void check_or_set_invalid_types(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- check for invalid types in recipe " << caller.name << end();
  for (int index = 0;  index < SIZE(caller.steps);  ++index) {
    instruction& inst = caller.steps.at(index);
    for (int i = 0;  i < SIZE(inst.ingredients);  ++i)
      check_or_set_invalid_types(inst.ingredients.at(i), caller, inst);
    for (int i = 0;  i < SIZE(inst.products);  ++i)
      check_or_set_invalid_types(inst.products.at(i), caller, inst);
  }
  // End check_or_set_invalid_types
}

void check_or_set_invalid_types(reagent& r, const recipe& caller, const instruction& inst) {
  // Begin check_or_set_invalid_types(r)
  check_or_set_invalid_types(r.type, maybe(caller.name), "'"+inst.original_string+"'");
}

void check_or_set_invalid_types(type_tree* type, const string& location_for_error_messages, const string& name_for_error_messages) {
  if (!type) return;
  // End Container Type Checks
  if (!type->atom) {
    check_or_set_invalid_types(type->left, location_for_error_messages, name_for_error_messages);
    check_or_set_invalid_types(type->right, location_for_error_messages, name_for_error_messages);
    return;
  }
  if (type->value == 0) return;
  if (!contains_key(Type, type->value)) {
    assert(!type->name.empty());
    if (contains_key(Type_ordinal, type->name))
      type->value = get(Type_ordinal, type->name);
    else
      raise << location_for_error_messages << "unknown type " << type->name << " in " << name_for_error_messages << '\n' << end();
  }
}

:(scenario container_unknown_field)
% Hide_errors = true;
container foo [
  x:num
  y:bar
]
+error: foo: unknown type in y

:(scenario read_container_with_bracket_in_comment)
container foo [
  x:num
  # ']' in comment
  y:num
]
+parse: --- defining container foo
+parse: element: {x: "number"}
+parse: element: {y: "number"}

:(scenario container_with_compound_field_type)
container foo [
  {x: (address array (address array character))}
]
$error: 0

:(before "End transform_all")
check_container_field_types();

:(code)
void check_container_field_types() {
  for (map<type_ordinal, type_info>::iterator p = Type.begin();  p != Type.end();  ++p) {
    const type_info& info = p->second;
    // Check Container Field Types(info)
    for (int i = 0;  i < SIZE(info.elements);  ++i)
      check_invalid_types(info.elements.at(i).type, maybe(info.name), info.elements.at(i).name);
  }
}

void check_invalid_types(const type_tree* type, const string& location_for_error_messages, const string& name_for_error_messages) {
  if (!type) return;  // will throw a more precise error elsewhere
  if (!type->atom) {
    check_invalid_types(type->left, location_for_error_messages, name_for_error_messages);
    check_invalid_types(type->right, location_for_error_messages, name_for_error_messages);
    return;
  }
  if (type->value != 0) {  // value 0 = compound types (layer parse_tree) or type ingredients (layer shape_shifting_container)
    if (!contains_key(Type, type->value))
      raise << location_for_error_messages << "unknown type in " << name_for_error_messages << '\n' << end();
  }
}

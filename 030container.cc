//: Containers contain a fixed number of elements of different types.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
type_ordinal point = Type_ordinal["point"] = Next_type_ordinal++;
Type[point].size = 2;
Type[point].kind = CONTAINER;
Type[point].name = "point";
Type[point].elements.push_back(new type_tree(number));
Type[point].element_names.push_back("x");
Type[point].elements.push_back(new type_tree(number));
Type[point].element_names.push_back("y");

//: Containers can be copied around with a single instruction just like
//: numbers, no matter how large they are.

//: Tests in this layer often explicitly setup memory before reading it as a
//: container. Don't do this in general. I'm tagging exceptions with /raw to
//: avoid errors.
:(scenario copy_multiple_locations)
recipe main [
  1:number <- copy 34
  2:number <- copy 35
  3:point <- copy 1:point/raw  # unsafe
]
+mem: storing 34 in location 3
+mem: storing 35 in location 4

//: trying to copy to a differently-typed destination will fail
:(scenario copy_checks_size)
% Hide_errors = true;
recipe main [
  2:point <- copy 1:number
]
+error: main: can't copy 1:number to 2:point; types don't match

:(before "End Mu Types Initialization")
// A more complex container, containing another container as one of its
// elements.
type_ordinal point_number = Type_ordinal["point-number"] = Next_type_ordinal++;
Type[point_number].size = 2;
Type[point_number].kind = CONTAINER;
Type[point_number].name = "point-number";
Type[point_number].elements.push_back(new type_tree(point));
Type[point_number].element_names.push_back("xy");
Type[point_number].elements.push_back(new type_tree(number));
Type[point_number].element_names.push_back("z");

:(scenario copy_handles_nested_container_elements)
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:point-number <- copy 12:point-number/raw  # unsafe
]
+mem: storing 36 in location 17

//: Containers can be checked for equality with a single instruction just like
//: numbers, no matter how large they are.

:(scenario compare_multiple_locations)
recipe main [
  1:number <- copy 34  # first
  2:number <- copy 35
  3:number <- copy 36
  4:number <- copy 34  # second
  5:number <- copy 35
  6:number <- copy 36
  7:boolean <- equal 1:point-number/raw, 4:point-number/raw  # unsafe
]
+mem: storing 1 in location 7

:(scenario compare_multiple_locations_2)
recipe main [
  1:number <- copy 34  # first
  2:number <- copy 35
  3:number <- copy 36
  4:number <- copy 34  # second
  5:number <- copy 35
  6:number <- copy 37  # different
  7:boolean <- equal 1:point-number/raw, 4:point-number/raw  # unsafe
]
+mem: storing 0 in location 7

:(before "End size_of(type) Cases")
if (type->value == 0) {
  assert(!type->left && !type->right);
  return 1;
}
type_info t = Type[type->value];
if (t.kind == CONTAINER) {
  // size of a container is the sum of the sizes of its elements
  long long int result = 0;
  for (long long int i = 0; i < SIZE(t.elements); ++i) {
    // todo: strengthen assertion to disallow mutual type recursion
    if (t.elements.at(i)->value == type->value) {
      raise_error << "container " << t.name << " can't include itself as a member\n" << end();
      return 0;
    }
    // End size_of(type) Container Cases
    result += size_of(t.elements.at(i));
  }
  return result;
}

:(scenario stash_container)
recipe main [
  1:number <- copy 34  # first
  2:number <- copy 35
  3:number <- copy 36
  stash [foo:], 1:point-number/raw
]
+app: foo: 34 35 36

//:: To access elements of a container, use 'get'
:(scenario get)
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  15:number <- get 12:point/raw, 1:offset  # unsafe
]
+mem: storing 35 in location 15

:(before "End Primitive Recipe Declarations")
GET,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["get"] = GET;
:(before "End Primitive Recipe Checks")
case GET: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(Recipe[r].name) << "'get' expects exactly 2 ingredients in '" << inst.to_string() << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  // Update GET base in Check
  if (!base.type || !base.type->value || Type[base.type->value].kind != CONTAINER) {
    raise_error << maybe(Recipe[r].name) << "first ingredient of 'get' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  reagent offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise_error << maybe(Recipe[r].name) << "second ingredient of 'get' should have type 'offset', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  long long int offset_value = 0;
  if (is_integer(offset.name)) {  // later layers permit non-integer offsets
    offset_value = to_integer(offset.name);
    if (offset_value < 0 || offset_value >= SIZE(Type[base_type].elements)) {
      raise_error << maybe(Recipe[r].name) << "invalid offset " << offset_value << " for " << Type[base_type].name << '\n' << end();
      break;
    }
  }
  else {
    offset_value = offset.value;
  }
  reagent product = inst.products.at(0);
  // Update GET product in Check
  reagent element;
  element.type = new type_tree(*Type[base_type].elements.at(offset_value));
  if (!types_match(product, element)) {
    raise_error << maybe(Recipe[r].name) << "'get' " << offset.original_string << " (" << offset_value << ") on " << Type[base_type].name << " can't be saved in " << product.original_string << "; type should be " << dump_types(element) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET: {
  reagent base = current_instruction().ingredients.at(0);
  // Update GET base in Run
  long long int base_address = base.value;
  if (base_address == 0) {
    raise_error << maybe(current_recipe_name()) << "tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  long long int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(Type[base_type].elements)) break;  // copied from Check above
  long long int src = base_address;
  for (long long int i = 0; i < offset; ++i) {
    // End GET field Cases
    src += size_of(Type[base_type].elements.at(i));
  }
  trace(9998, "run") << "address to copy is " << src << end();
  type_ordinal src_type = Type[base_type].elements.at(offset)->value;
  trace(9998, "run") << "its type is " << Type[src_type].name << end();
  reagent tmp;
  tmp.set_value(src);
  tmp.type = new type_tree(src_type);
  products.push_back(read_memory(tmp));
  break;
}

:(scenario get_handles_nested_container_elements)
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:number <- get 12:point-number/raw, 1:offset  # unsafe
]
+mem: storing 36 in location 15

:(scenario get_out_of_bounds)
% Hide_errors = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset 2 for point-number

:(scenario get_out_of_bounds_2)
% Hide_errors = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get 12:point-number/raw, -1:offset
]
+error: main: invalid offset -1 for point-number

:(scenario get_product_type_mismatch)
% Hide_errors = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:address:number <- get 12:point-number/raw, 1:offset
]
+error: main: 'get' 1:offset (1) on point-number can't be saved in 15:address:number; type should be number

//:: To write to elements of containers, you need their address.

:(scenario get_address)
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  15:address:number <- get-address 12:point/raw, 1:offset  # unsafe
]
+mem: storing 13 in location 15

:(before "End Primitive Recipe Declarations")
GET_ADDRESS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["get-address"] = GET_ADDRESS;
:(before "End Primitive Recipe Checks")
case GET_ADDRESS: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(Recipe[r].name) << "'get-address' expects exactly 2 ingredients in '" << inst.to_string() << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  // Update GET_ADDRESS base in Check
  if (!base.type || Type[base.type->value].kind != CONTAINER) {
    raise_error << maybe(Recipe[r].name) << "first ingredient of 'get-address' should be a container, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  reagent offset = inst.ingredients.at(1);
  if (!is_literal(offset) || !is_mu_scalar(offset)) {
    raise_error << maybe(Recipe[r].name) << "second ingredient of 'get' should have type 'offset', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  long long int offset_value = 0;
  if (is_integer(offset.name)) {  // later layers permit non-integer offsets
    offset_value = to_integer(offset.name);
    if (offset_value < 0 || offset_value >= SIZE(Type[base_type].elements)) {
      raise_error << maybe(Recipe[r].name) << "invalid offset " << offset_value << " for " << Type[base_type].name << '\n' << end();
      break;
    }
  }
  else {
    offset_value = offset.value;
  }
  reagent product = inst.products.at(0);
  // Update GET_ADDRESS product in Check
  reagent element;
  // same type as for GET..
  element.type = new type_tree(*Type[base_type].elements.at(offset_value));
  // ..except for an address at the start
  element.type = new type_tree(Type_ordinal["address"], element.type);
  if (!types_match(product, element)) {
    raise_error << maybe(Recipe[r].name) << "'get-address' " << offset.original_string << " (" << offset_value << ") on " << Type[base_type].name << " can't be saved in " << product.original_string << "; type should be " << dump_types(element) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case GET_ADDRESS: {
  reagent base = current_instruction().ingredients.at(0);
  // Update GET_ADDRESS base in Run
  long long int base_address = base.value;
  if (base_address == 0) {
    raise_error << maybe(current_recipe_name()) << "tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.type->value;
  long long int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(Type[base_type].elements)) break;  // copied from Check above
  long long int result = base_address;
  for (long long int i = 0; i < offset; ++i) {
    // End GET_ADDRESS field Cases
    result += size_of(Type[base_type].elements.at(i));
  }
  trace(9998, "run") << "address to copy is " << result << end();
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario get_address_out_of_bounds)
% Hide_errors = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-address 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+error: main: invalid offset 2 for point-number

:(scenario get_address_out_of_bounds_2)
% Hide_errors = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-address 12:point-number/raw, -1:offset
]
+error: main: invalid offset -1 for point-number

:(scenario get_address_product_type_mismatch)
% Hide_errors = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  15:number <- get-address 12:point-number/raw, 1:offset
]
+error: main: 'get-address' 1:offset (1) on point-number can't be saved in 15:number; type should be <address : <number : <>>>

//:: Allow containers to be defined in mu code.

:(scenarios load)
:(scenario container)
container foo [
  x:number
  y:number
]
+parse: --- defining container foo
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1

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
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1001
+parse: --- defining container bar
+parse: type number: 1001

:(before "End Command Handlers")
else if (command == "container") {
  insert_container(command, CONTAINER, in);
}

:(code)
void insert_container(const string& command, kind_of_type kind, istream& in) {
  skip_whitespace(in);
  string name = next_word(in);
  trace(9991, "parse") << "--- defining " << command << ' ' << name << end();
  if (Type_ordinal.find(name) == Type_ordinal.end()
      || Type_ordinal[name] == 0) {
    Type_ordinal[name] = Next_type_ordinal++;
  }
  trace(9999, "parse") << "type number: " << Type_ordinal[name] << end();
  skip_bracket(in, "'container' must begin with '['");
  type_info& info = Type[Type_ordinal[name]];
  recently_added_types.push_back(Type_ordinal[name]);
  info.name = name;
  info.kind = kind;
  while (!in.eof()) {
    skip_whitespace_and_comments(in);
    string element = next_word(in);
    if (element == "]") break;
    // End insert_container Special Definitions(element)
    istringstream inner(element);
    info.element_names.push_back(slurp_until(inner, ':'));
    trace(9993, "parse") << "  element name: " << info.element_names.back() << end();
    type_tree* new_type = NULL;
    type_tree** curr_type = &new_type;
    vector<type_ordinal> types;
    while (!inner.eof()) {
      string type_name = slurp_until(inner, ':');
      // End insert_container Special Uses(type_name)
      if (Type_ordinal.find(type_name) == Type_ordinal.end()
          // types can contain integers, like for array sizes
          && !is_integer(type_name)) {
        Type_ordinal[type_name] = Next_type_ordinal++;
      }
      *curr_type = new type_tree(Type_ordinal[type_name]);
      trace(9993, "parse") << "  type: " << Type_ordinal[type_name] << end();
      curr_type = &(*curr_type)->right;
    }
    info.elements.push_back(new_type);
  }
  assert(SIZE(info.elements) == SIZE(info.element_names));
  info.size = SIZE(info.elements);
}

void skip_bracket(istream& in, string message) {
  skip_whitespace_and_comments(in);
  if (in.get() != '[')
    raise_error << message << '\n' << end();
}

:(scenarios run)
:(scenario container_define_twice)
container foo [
  x:number
]

container foo [
  y:number
]

recipe main [
  1:number <- copy 34
  2:number <- copy 35
  3:number <- get 1:foo, 0:offset
  4:number <- get 1:foo, 1:offset
]
+mem: storing 34 in location 3
+mem: storing 35 in location 4

//: ensure types created in one scenario don't leak outside it.
:(before "End Globals")
vector<type_ordinal> recently_added_types;
:(before "End load_permanently")  //: for non-tests
recently_added_types.clear();
:(before "End Setup")  //: for tests
for (long long int i = 0; i < SIZE(recently_added_types); ++i) {
  Type_ordinal.erase(Type[recently_added_types.at(i)].name);
  // todo: why do I explicitly need to provide this?
  for (long long int j = 0; j < SIZE(Type.at(recently_added_types.at(i)).elements); ++j) {
    delete Type.at(recently_added_types.at(i)).elements.at(j);
  }
  Type.erase(recently_added_types.at(i));
}
recently_added_types.clear();
// delete recent type references
// can't rely on recently_added_types to cleanup Type_ordinal, because of deliberately misbehaving tests with references to undefined types
map<string, type_ordinal>::iterator p = Type_ordinal.begin();
while(p != Type_ordinal.end()) {
  // save current item
  string name = p->first;
  type_ordinal t = p->second;
  // increment iterator
  ++p;
  // now delete current item if necessary
  if (t >= 1000) {
    Type_ordinal.erase(name);
  }
}
//: lastly, ensure scenarios are consistent by always starting them at the
//: same type number.
Next_type_ordinal = 1000;
:(before "End Test Run Initialization")
assert(Next_type_ordinal < 1000);
:(before "End Setup")
Next_type_ordinal = 1000;

//:: Allow container definitions anywhere in the codebase, but complain if you
//:: can't find a definition at the end.

:(scenario run_complains_on_unknown_types)
% Hide_errors = true;
recipe main [
  # integer is not a type
  1:integer <- copy 0
]
+error: main: unknown type in '1:integer <- copy 0'

:(scenario run_allows_type_definition_after_use)
% Hide_errors = true;
recipe main [
  1:bar <- copy 0/raw
]

container bar [
  x:number
]
-error: unknown type: bar
$error: 0

:(after "int main")
  Transform.push_back(check_invalid_types);

:(code)
void check_invalid_types(const recipe_ordinal r) {
  for (long long int index = 0; index < SIZE(Recipe[r].steps); ++index) {
    const instruction& inst = Recipe[r].steps.at(index);
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
      check_invalid_types(inst.ingredients.at(i).type, maybe(Recipe[r].name), "'"+inst.to_string()+"'");
    }
    for (long long int i = 0; i < SIZE(inst.products); ++i) {
      check_invalid_types(inst.products.at(i).type, maybe(Recipe[r].name), "'"+inst.to_string()+"'");
    }
  }
}

void check_invalid_types(const type_tree* type, const string& block, const string& name) {
  if (!type) return;  // will throw a more precise error elsewhere
  if (type->value && Type.find(type->value) == Type.end()) {
    raise_error << block << "unknown type in " << name << '\n' << end();
  }
  if (type->left) check_invalid_types(type->left, block, name);
  if (type->right) check_invalid_types(type->right, block, name);
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
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1

:(before "End Transform")
check_container_field_types();

:(code)
void check_container_field_types() {
  for (map<type_ordinal, type_info>::iterator p = Type.begin(); p != Type.end(); ++p) {
    const type_info& info = p->second;
    for (long long int i = 0; i < SIZE(info.elements); ++i) {
      check_invalid_types(info.elements.at(i), maybe(info.name), info.element_names.at(i));
    }
  }
}

//:: Construct types out of their constituent fields. Doesn't currently do
//:: type-checking but *does* match sizes.
:(before "End Primitive Recipe Declarations")
MERGE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["merge"] = MERGE;
:(before "End Primitive Recipe Checks")
case MERGE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MERGE: {
  products.resize(1);
  for (long long int i = 0; i < SIZE(ingredients); ++i)
    for (long long int j = 0; j < SIZE(ingredients.at(i)); ++j)
      products.at(0).push_back(ingredients.at(i).at(j));
  break;
}

:(scenario merge)
container foo [
  x:number
  y:number
]

recipe main [
  1:foo <- merge 3, 4
]
+mem: storing 3 in location 1
+mem: storing 4 in location 2

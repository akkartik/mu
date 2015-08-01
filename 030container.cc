//: Containers contain a fixed number of elements of different types.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
type_ordinal point = Type_ordinal["point"] = Next_type_ordinal++;
Type[point].size = 2;
Type[point].kind = container;
Type[point].name = "point";
vector<type_ordinal> i;
i.push_back(number);
Type[point].elements.push_back(i);
Type[point].elements.push_back(i);

//: Containers can be copied around with a single instruction just like
//: numbers, no matter how large they are.

//: Tests in this layer often explicitly setup memory before reading it as a
//: container. Don't do this in general. I'm tagging exceptions with /raw to
//: avoid warnings.
:(scenario copy_multiple_locations)
recipe main [
  1:number <- copy 34
  2:number <- copy 35
  3:point <- copy 1:point/raw  # unsafe
]
+mem: storing 34 in location 3
+mem: storing 35 in location 4

:(before "End Mu Types Initialization")
// A more complex container, containing another container as one of its
// elements.
type_ordinal point_number = Type_ordinal["point-number"] = Next_type_ordinal++;
Type[point_number].size = 2;
Type[point_number].kind = container;
Type[point_number].name = "point-number";
vector<type_ordinal> p2;
p2.push_back(point);
Type[point_number].elements.push_back(p2);
vector<type_ordinal> i2;
i2.push_back(number);
Type[point_number].elements.push_back(i2);

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

:(scenario compare_multiple_locations2)
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

:(before "End size_of(types) Cases")
type_info t = Type[types.at(0)];
if (t.kind == container) {
  // size of a container is the sum of the sizes of its elements
  long long int result = 0;
  for (long long int i = 0; i < SIZE(t.elements); ++i) {
    // todo: strengthen assertion to disallow mutual type recursion
    if (types.at(0) == t.elements.at(i).at(0)) {
      raise << "container " << t.name << " can't include itself as a member\n" << end();
      return 0;
    }
    result += size_of(t.elements.at(i));
  }
  return result;
}

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
:(before "End Primitive Recipe Implementations")
case GET: {
  products.resize(1);
  if (SIZE(ingredients) != 2) {
    raise << current_recipe_name() << ": 'get' expects exactly 2 ingredients in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  reagent base = current_instruction().ingredients.at(0);
  long long int base_address = base.value;
  if (base_address == 0) {
    raise << current_recipe_name() << ": tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.types.at(0);
  if (Type[base_type].kind != container) {
    raise << current_recipe_name () << ": first ingredient of 'get' should be a container, but got " << base.original_string << '\n' << end();
    break;
  }
  if (!is_literal(current_instruction().ingredients.at(1))) {
    raise << current_recipe_name() << ": second ingredient of 'get' should have type 'offset', but got " << current_instruction().ingredients.at(1).original_string << '\n' << end();
    break;
  }
  assert(scalar(ingredients.at(1)));
  long long int offset = ingredients.at(1).at(0);
  long long int src = base_address;
  for (long long int i = 0; i < offset; ++i) {
    src += size_of(Type[base_type].elements.at(i));
  }
  trace(Primitive_recipe_depth, "run") << "address to copy is " << src << end();
  if (offset < 0 || offset >= SIZE(Type[base_type].elements)) {
    raise << current_recipe_name() << ": invalid offset " << offset << " for " << Type[base_type].name << '\n' << end();
    break;
  }
  type_ordinal src_type = Type[base_type].elements.at(offset).at(0);
  trace(Primitive_recipe_depth, "run") << "its type is " << Type[src_type].name << end();
  reagent tmp;
  tmp.set_value(src);
  tmp.types.push_back(src_type);
  products.at(0) = read_memory(tmp);
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

//:: To write to elements of containers, you need their address.

:(scenario get_address)
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  15:address:number <- get-address 12:point/raw, 1:offset  # unsafe
]
+mem: storing 13 in location 15

:(scenario get_out_of_bounds)
% Hide_warnings = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+warn: main: invalid offset 2 for point-number

:(scenario get_out_of_bounds2)
% Hide_warnings = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get 12:point-number/raw, -1:offset
]
+warn: main: invalid offset -1 for point-number

:(before "End Primitive Recipe Declarations")
GET_ADDRESS,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["get-address"] = GET_ADDRESS;
:(before "End Primitive Recipe Implementations")
case GET_ADDRESS: {
  products.resize(1);
  reagent base = current_instruction().ingredients.at(0);
  long long int base_address = base.value;
  if (base_address == 0) {
    raise << current_recipe_name() << ": tried to access location 0 in '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  type_ordinal base_type = base.types.at(0);
  if (Type[base_type].kind != container) {
    raise << current_recipe_name () << ": first ingredient of 'get-address' should be a container, but got " << base.original_string << '\n' << end();
    break;
  }
  if (!is_literal(current_instruction().ingredients.at(1))) {
    raise << current_recipe_name() << ": second ingredient of 'get-address' should have type 'offset', but got " << current_instruction().ingredients.at(1).original_string << '\n' << end();
    break;
  }
  assert(scalar(ingredients.at(1)));
  long long int offset = ingredients.at(1).at(0);
  if (offset < 0 || offset >= SIZE(Type[base_type].elements)) {
    raise << "invalid offset " << offset << " for " << Type[base_type].name << '\n' << end();
    break;
  }
  long long int result = base_address;
  for (long long int i = 0; i < offset; ++i) {
    result += size_of(Type[base_type].elements.at(i));
  }
  trace(Primitive_recipe_depth, "run") << "address to copy is " << result << end();
  products.at(0).push_back(result);
  break;
}

:(scenario get_address_out_of_bounds)
% Hide_warnings = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-address 12:point-number/raw, 2:offset  # point-number occupies 3 locations but has only 2 fields; out of bounds
]
+warn: invalid offset 2 for point-number

:(scenario get_address_out_of_bounds2)
% Hide_warnings = true;
recipe main [
  12:number <- copy 34
  13:number <- copy 35
  14:number <- copy 36
  get-address 12:point-number/raw, -1:offset
]
+warn: invalid offset -1 for point-number

//:: Allow containers to be defined in mu code.

:(scenarios load)
:(scenario container)
container foo [
  x:number
  y:number
]
+parse: reading container foo
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
+parse: reading container foo
+parse: type number: 1000
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1001
+parse: reading container bar
+parse: type number: 1001

:(before "End Command Handlers")
else if (command == "container") {
  insert_container(command, container, in);
}

:(code)
void insert_container(const string& command, kind_of_type kind, istream& in) {
  skip_whitespace(in);
  string name = next_word(in);
  trace("parse") << "reading " << command << ' ' << name << end();
//?   cout << name << '\n'; //? 2
//?   if (Type_ordinal.find(name) != Type_ordinal.end()) //? 1
//?     cerr << Type_ordinal[name] << '\n'; //? 1
  if (Type_ordinal.find(name) == Type_ordinal.end()
      || Type_ordinal[name] == 0) {
    Type_ordinal[name] = Next_type_ordinal++;
  }
  trace("parse") << "type number: " << Type_ordinal[name] << end();
  skip_bracket(in, "'container' must begin with '['");
  type_info& t = Type[Type_ordinal[name]];
  recently_added_types.push_back(Type_ordinal[name]);
  t.name = name;
  t.kind = kind;
  while (!in.eof()) {
    skip_whitespace_and_comments(in);
    string element = next_word(in);
    if (element == "]") break;
    istringstream inner(element);
    t.element_names.push_back(slurp_until(inner, ':'));
    trace("parse") << "  element name: " << t.element_names.back() << end();
    vector<type_ordinal> types;
    while (!inner.eof()) {
      string type_name = slurp_until(inner, ':');
      if (Type_ordinal.find(type_name) == Type_ordinal.end()) {
//?         cerr << type_name << " is " << Next_type_ordinal << '\n'; //? 1
        Type_ordinal[type_name] = Next_type_ordinal++;
      }
      types.push_back(Type_ordinal[type_name]);
      trace("parse") << "  type: " << types.back() << end();
    }
    t.elements.push_back(types);
  }
  assert(SIZE(t.elements) == SIZE(t.element_names));
  t.size = SIZE(t.elements);
}

//: ensure types created in one scenario don't leak outside it.
:(before "End Globals")
vector<type_ordinal> recently_added_types;
:(before "End load_permanently")  //: for non-tests
recently_added_types.clear();
:(before "End Setup")  //: for tests
for (long long int i = 0; i < SIZE(recently_added_types); ++i) {
//?   cout << "erasing " << Type[recently_added_types.at(i)].name << '\n'; //? 1
  Type_ordinal.erase(Type[recently_added_types.at(i)].name);
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
//?     cerr << "AAA " << name << " " << t << '\n'; //? 1
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

//:: Allow container definitions anywhere in the codebase, but warn if you
//:: can't find a definition.

:(scenarios run)
:(scenario run_warns_on_unknown_types)
% Hide_warnings = true;
#? % Trace_stream->dump_layer = "run";
recipe main [
  # integer is not a type
  1:integer <- copy 0
]
+warn: unknown type: integer

:(scenario run_allows_type_definition_after_use)
% Hide_warnings = true;
recipe main [
  1:bar <- copy 0
]

container bar [
  x:number
]
-warn: unknown type: bar
$warn: 0

:(after "int main")
  Transform.push_back(check_invalid_types);

:(code)
void check_invalid_types(const recipe_ordinal r) {
  for (long long int index = 0; index < SIZE(Recipe[r].steps); ++index) {
    const instruction& inst = Recipe[r].steps.at(index);
    for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
      check_invalid_types(inst.ingredients.at(i));
    }
    for (long long int i = 0; i < SIZE(inst.products); ++i) {
      check_invalid_types(inst.products.at(i));
    }
  }
}

void check_invalid_types(const reagent& r) {
  for (long long int i = 0; i < SIZE(r.types); ++i) {
    if (r.types.at(i) == 0) continue;
    if (Type.find(r.types.at(i)) == Type.end())
      raise << "unknown type: " << r.properties.at(0).second.at(i) << '\n' << end();
  }
}

:(scenario container_unknown_field)
% Hide_warnings = true;
container foo [
  x:number
  y:bar
]
+warn: unknown type for field y in foo

:(scenario read_container_with_bracket_in_comment)
container foo [
  x:number
  # ']' in comment
  y:number
]
+parse: reading container foo
+parse:   element name: x
+parse:   type: 1
+parse:   element name: y
+parse:   type: 1

:(before "End Load Sanity Checks")
check_container_field_types();

:(code)
void check_container_field_types() {
  for (map<type_ordinal, type_info>::iterator p = Type.begin(); p != Type.end(); ++p) {
    const type_info& info = p->second;
//?     cerr << "checking " << p->first << '\n'; //? 1
    for (long long int i = 0; i < SIZE(info.elements); ++i) {
      for (long long int j = 0; j < SIZE(info.elements.at(i)); ++j) {
        if (info.elements.at(i).at(j) == 0) continue;
        if (Type.find(info.elements.at(i).at(j)) == Type.end())
          raise << "unknown type for field " << info.element_names.at(i) << " in " << info.name << '\n' << end();
      }
    }
  }
}

//:: Construct types out of their constituent fields. Doesn't currently do
//:: type-checking but *does* match sizes.
:(before "End Primitive Recipe Declarations")
MERGE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["merge"] = MERGE;
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

//:: helpers

:(code)
void skip_bracket(istream& in, string message) {
  skip_whitespace_and_comments(in);
  if (in.get() != '[')
    raise << message << '\n' << end();
}

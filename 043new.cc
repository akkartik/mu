//: A simple memory allocator to create space for new variables at runtime.

:(scenarios run)
:(scenario new)
# call new two times with identical arguments; you should get back different results
recipe main [
  1:address:number/raw <- new number:type
  2:address:number/raw <- new number:type
  3:boolean/raw <- equal 1:address:number/raw, 2:address:number/raw
]
+mem: storing 0 in location 3

:(before "End Globals")
long long int Memory_allocated_until = Reserved_for_tests;
long long int Initial_memory_per_routine = 100000;
:(before "End Setup")
Memory_allocated_until = Reserved_for_tests;
Initial_memory_per_routine = 100000;
:(before "End routine Fields")
long long int alloc, alloc_max;
:(before "End routine Constructor")
alloc = Memory_allocated_until;
Memory_allocated_until += Initial_memory_per_routine;
alloc_max = Memory_allocated_until;
trace(9999, "new") << "routine allocated memory from " << alloc << " to " << alloc_max << end();

//:: 'new' takes a weird 'type' as its first ingredient; don't error on it
:(before "End Mu Types Initialization")
put(Type_ordinal, "type", 0);

//:: typecheck 'new' instructions
:(before "End Primitive Recipe Declarations")
NEW,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "new", NEW);
:(before "End Primitive Recipe Checks")
case NEW: {
  if (inst.ingredients.empty() || SIZE(inst.ingredients) > 2) {
    raise_error << maybe(get(Recipe, r).name) << "'new' requires one or two ingredients, but got " << inst.to_string() << '\n' << end();
    break;
  }
  // End NEW Check Special-cases
  reagent type = inst.ingredients.at(0);
  if (!is_mu_type_literal(type)) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'new' should be a type, but got " << type.original_string << '\n' << end();
    break;
  }
  break;
}

//:: translate 'new' to 'allocate' instructions that take a size instead of a type
:(after "Transform.push_back(check_instruction)")  // check_instruction will guard against direct 'allocate' instructions below
Transform.push_back(transform_new_to_allocate);  // idempotent

:(code)
void transform_new_to_allocate(const recipe_ordinal r) {
  trace(9991, "transform") << "--- convert 'new' to 'allocate' for recipe " << get(Recipe, r).name << end();
//?   cerr << "--- convert 'new' to 'allocate' for recipe " << get(Recipe, r).name << '\n';
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    // Convert 'new' To 'allocate'
    if (inst.name == "new") {
      inst.operation = ALLOCATE;
      string_tree* type_name = new string_tree(inst.ingredients.at(0).name);
      // End Post-processing(type_name) When Converting 'new'
      type_tree* type = new_type_tree(type_name);
      inst.ingredients.at(0).set_value(size_of(type));
      trace(9992, "new") << "size of " << debug_string(type_name) << " is " << inst.ingredients.at(0).value << end();
      delete type;
      delete type_name;
    }
  }
}

//:: implement 'allocate' based on size

:(before "End Primitive Recipe Declarations")
ALLOCATE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "allocate", ALLOCATE);
:(before "End Primitive Recipe Implementations")
case ALLOCATE: {
  // compute the space we need
  long long int size = ingredients.at(0).at(0);
  if (SIZE(ingredients) > 1) {
    // array
    trace(9999, "mem") << "array size is " << ingredients.at(1).at(0) << end();
    size = /*space for length*/1 + size*ingredients.at(1).at(0);
  }
//?   Total_alloc += size;
//?   Num_alloc++;
  // compute the region of memory to return
  // really crappy at the moment
  ensure_space(size);
  const long long int result = Current_routine->alloc;
  trace(9999, "mem") << "new alloc: " << result << end();
  // save result
  products.resize(1);
  products.at(0).push_back(result);
  // initialize allocated space
  for (long long int address = result; address < result+size; ++address)
    put(Memory, address, 0);
  // initialize array length
  if (SIZE(current_instruction().ingredients) > 1)
    put(Memory, result, ingredients.at(1).at(0));
  // bump
  Current_routine->alloc += size;
  // no support for reclaiming memory
  assert(Current_routine->alloc <= Current_routine->alloc_max);
  break;
}

//:: ensure we never call 'allocate' directly; its types are not checked
:(before "End Primitive Recipe Checks")
case ALLOCATE: {
  raise << "never call 'allocate' directly'; always use 'new'\n" << end();
  break;
}

//:: ensure we never call 'new' without translating it (unless we add special-cases later)
:(before "End Primitive Recipe Implementations")
case NEW: {
  raise << "no implementation for 'new'; why wasn't it translated to 'allocate'?\n" << end();
  break;
}

//? :(before "End Globals")
//? long long int Total_alloc = 0;
//? long long int Num_alloc = 0;
//? long long int Total_free = 0;
//? long long int Num_free = 0;
//? :(before "End Setup")
//? Total_alloc = Num_alloc = Total_free = Num_free = 0;
//? :(before "End Teardown")
//? cerr << Total_alloc << "/" << Num_alloc
//?      << " vs " << Total_free << "/" << Num_free << '\n';
//? cerr << SIZE(Memory) << '\n';

:(code)
void ensure_space(long long int size) {
  if (size > Initial_memory_per_routine) {
    tb_shutdown();
    cerr << "can't allocate " << size << " locations, that's too much.\n";
    exit(0);
  }
  if (Current_routine->alloc + size > Current_routine->alloc_max) {
    // waste the remaining space and create a new chunk
    Current_routine->alloc = Memory_allocated_until;
    Memory_allocated_until += Initial_memory_per_routine;
    Current_routine->alloc_max = Memory_allocated_until;
    trace(9999, "new") << "routine allocated memory from " << Current_routine->alloc << " to " << Current_routine->alloc_max << end();
  }
}

:(scenario new_initializes)
% Memory_allocated_until = 10;
% put(Memory, Memory_allocated_until, 1);
recipe main [
  1:address:number <- new number:type
  2:number <- copy *1:address:number
]
+mem: storing 0 in location 2

:(scenario new_array)
recipe main [
  1:address:array:number/raw <- new number:type, 5
  2:address:number/raw <- new number:type
  3:number/raw <- subtract 2:address:number/raw, 1:address:array:number/raw
]
+run: 1:address:array:number/raw <- new number:type, 5
+mem: array size is 5
# don't forget the extra location for array size
+mem: storing 6 in location 3

:(scenario new_empty_array)
recipe main [
  1:address:array:number/raw <- new number:type, 0
  2:address:number/raw <- new number:type
  3:number/raw <- subtract 2:address:number/raw, 1:address:array:number/raw
]
+run: 1:address:array:number/raw <- new number:type, 0
+mem: array size is 0
+mem: storing 1 in location 3

//: If a routine runs out of its initial allocation, it should allocate more.
:(scenario new_overflow)
% Initial_memory_per_routine = 2;
recipe main [
  1:address:number/raw <- new number:type
  2:address:point/raw <- new point:type  # not enough room in initial page
]
+new: routine allocated memory from 1000 to 1002
+new: routine allocated memory from 1002 to 1004

//: We also provide a way to return memory, and to reuse reclaimed memory.
//: todo: custodians, etc. Following malloc/free is a temporary hack.

:(scenario new_reclaim)
recipe main [
  1:address:number <- new number:type
  abandon 1:address:number
  2:address:number <- new number:type  # must be same size as abandoned memory to reuse
  3:boolean <- equal 1:address:number, 2:address:number
]
# both allocations should have returned the same address
+mem: storing 1 in location 3

:(before "End Globals")
map<long long int, long long int> Free_list;
:(before "End Setup")
Free_list.clear();

:(before "End Primitive Recipe Declarations")
ABANDON,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "abandon", ABANDON);
:(before "End Primitive Recipe Checks")
case ABANDON: {
  if (SIZE(inst.ingredients) != 1) {
    raise_error << maybe(get(Recipe, r).name) << "'abandon' requires one ingredient, but got '" << inst.to_string() << "'\n" << end();
    break;
  }
  reagent types = inst.ingredients.at(0);
  canonize_type(types);
  if (!types.type || types.type->value != get(Type_ordinal, "address")) {
    raise_error << maybe(get(Recipe, r).name) << "first ingredient of 'abandon' should be an address, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ABANDON: {
  long long int address = ingredients.at(0).at(0);
  reagent types = current_instruction().ingredients.at(0);
  canonize(types);
  // lookup_memory without drop_one_lookup {
  types.set_value(get_or_insert(Memory, types.value));
  drop_address_from_type(types);
  // }
  abandon(address, size_of(types));
  break;
}

:(code)
void abandon(long long int address, long long int size) {
//?   Total_free += size;
//?   Num_free++;
//?   cerr << "abandon: " << size << '\n';
  // clear memory
  for (long long int curr = address; curr < address+size; ++curr)
    put(Memory, curr, 0);
  // append existing free list to address
  put(Memory, address, Free_list[size]);
  Free_list[size] = address;
}

:(before "ensure_space(size)" following "case ALLOCATE")
if (Free_list[size]) {
  long long int result = Free_list[size];
  Free_list[size] = get_or_insert(Memory, result);
  for (long long int curr = result+1; curr < result+size; ++curr) {
    if (get_or_insert(Memory, curr) != 0) {
      raise_error << maybe(current_recipe_name()) << "memory in free list was not zeroed out: " << curr << '/' << result << "; somebody wrote to us after free!!!\n" << end();
      break;  // always fatal
    }
  }
  if (SIZE(current_instruction().ingredients) > 1)
    put(Memory, result, ingredients.at(1).at(0));
  else
    put(Memory, result, 0);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario new_differing_size_no_reclaim)
recipe main [
  1:address:number <- new number:type
  abandon 1:address:number
  2:address:number <- new number:type, 2  # different size
  3:boolean <- equal 1:address:number, 2:address:number
]
# no reuse
+mem: storing 0 in location 3

:(scenario new_reclaim_array)
recipe main [
  1:address:array:number <- new number:type, 2
  abandon 1:address:array:number
  2:address:array:number <- new number:type, 2
  3:boolean <- equal 1:address:array:number, 2:address:array:number
]
# reuse
+mem: storing 1 in location 3

//:: Next, extend 'new' to handle a unicode string literal argument.

:(scenario new_string)
recipe main [
  1:address:array:character <- new [abc def]
  2:character <- index *1:address:array:character, 5
]
# number code for 'e'
+mem: storing 101 in location 2

:(scenario new_string_handles_unicode)
recipe main [
  1:address:array:character <- new [a«c]
  2:number <- length *1:address:array:character
  3:character <- index *1:address:array:character, 1
]
+mem: storing 3 in location 2
# unicode for '«'
+mem: storing 171 in location 3

:(before "End NEW Check Special-cases")
if (is_literal_string(inst.ingredients.at(0))) break;
:(before "Convert 'new' To 'allocate'")
if (inst.name == "new" && is_literal_string(inst.ingredients.at(0))) continue;
:(after "case NEW" following "Primitive Recipe Implementations")
  if (is_literal_string(current_instruction().ingredients.at(0))) {
    products.resize(1);
    products.at(0).push_back(new_mu_string(current_instruction().ingredients.at(0).name));
    break;
  }

:(code)
long long int new_mu_string(const string& contents) {
  // allocate an array just large enough for it
  long long int string_length = unicode_length(contents);
//?   Total_alloc += string_length+1;
//?   Num_alloc++;
  ensure_space(string_length+1);  // don't forget the extra location for array size
  // initialize string
  long long int result = Current_routine->alloc;
  put(Memory, Current_routine->alloc++, string_length);
  long long int curr = 0;
  const char* raw_contents = contents.c_str();
  for (long long int i = 0; i < string_length; ++i) {
    uint32_t curr_character;
    assert(curr < SIZE(contents));
    tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
    put(Memory, Current_routine->alloc, curr_character);
    curr += tb_utf8_char_length(raw_contents[curr]);
    ++Current_routine->alloc;
  }
  // mu strings are not null-terminated in memory
  return result;
}

//: stash recognizes strings

:(scenario stash_string)
recipe main [
  x:address:array:character <- new [abc]
  stash [foo:], x:address:array:character
]
+app: foo: abc

:(before "End print Special-cases(reagent r, data)")
if (is_mu_string(r)) {
  assert(scalar(data));
  return read_mu_string(data.at(0))+' ';
}

:(scenario unicode_string)
recipe main [
  x:address:array:character <- new [♠]
  stash [foo:], x:address:array:character
]
+app: foo: ♠

:(scenario stash_space_after_string)
recipe main [
  1:address:array:character <- new [abc]
  stash 1:address:array:character [foo]
]
+app: abc foo

//: Allocate more to routine when initializing a literal string
:(scenario new_string_overflow)
% Initial_memory_per_routine = 2;
recipe main [
  1:address:number/raw <- new number:type
  2:address:array:character/raw <- new [a]  # not enough room in initial page, if you take the array size into account
]
+new: routine allocated memory from 1000 to 1002
+new: routine allocated memory from 1002 to 1004

//: helpers
:(code)
long long int unicode_length(const string& s) {
  const char* in = s.c_str();
  long long int result = 0;
  long long int curr = 0;
  while (curr < SIZE(s)) {  // carefully bounds-check on the string
    // before accessing its raw pointer
    ++result;
    curr += tb_utf8_char_length(in[curr]);
  }
  return result;
}

string read_mu_string(long long int address) {
  long long int size = get_or_insert(Memory, address);
  if (size == 0) return "";
  ostringstream tmp;
  for (long long int curr = address+1; curr <= address+size; ++curr) {
    tmp << to_unicode(static_cast<uint32_t>(get_or_insert(Memory, curr)));
  }
  return tmp.str();
}

bool is_mu_type_literal(reagent r) {
//?   if (!r.properties.empty())
//?     dump_property(r.properties.at(0).second, cerr);
  return is_literal(r) && !r.properties.empty() && r.properties.at(0).second && r.properties.at(0).second->value == "type";
}

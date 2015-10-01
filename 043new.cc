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
trace(Primitive_recipe_depth, "new") << "routine allocated memory from " << alloc << " to " << alloc_max << end();

//:: First handle 'type' operands.

:(before "End Mu Types Initialization")
Type_ordinal["type"] = 0;
:(after "Per-recipe Transforms")
// replace type names with type_ordinals
if (inst.operation == Recipe_ordinal["new"]) {
  // End NEW Transform Special-cases
  // first arg must be of type 'type'
  if (inst.ingredients.empty())
    raise << maybe(Recipe[r].name) << "'new' expects one or two ingredients\n" << end();
  if (inst.ingredients.at(0).properties.empty()
      || inst.ingredients.at(0).properties.at(0).second.empty()
      || inst.ingredients.at(0).properties.at(0).second.at(0) != "type")
    raise << maybe(Recipe[r].name) << "first ingredient of 'new' should be a type, but got " << inst.ingredients.at(0).original_string << '\n' << end();
  if (Type_ordinal.find(inst.ingredients.at(0).name) == Type_ordinal.end())
    raise << maybe(Recipe[r].name) << "unknown type " << inst.ingredients.at(0).name << '\n' << end();
  inst.ingredients.at(0).set_value(Type_ordinal[inst.ingredients.at(0).name]);
  trace(Primitive_recipe_depth, "new") << inst.ingredients.at(0).name << " -> " << inst.ingredients.at(0).name << end();
  end_new_transform:;
}

//:: Now implement the primitive recipe.
//: todo: build 'new' in mu itself

:(before "End Primitive Recipe Declarations")
NEW,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["new"] = NEW;
:(before "End Primitive Recipe Implementations")
case NEW: {
  if (ingredients.empty() || SIZE(ingredients) > 2) {
    raise << maybe(current_recipe_name()) << "'new' requires one or two ingredients, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << maybe(current_recipe_name()) << "first ingredient of 'new' should be a type, but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
  // compute the space we need
  long long int size = 0;
  long long int array_length = 0;
  {
    vector<type_ordinal> type;
    type.push_back(current_instruction().ingredients.at(0).value);
    if (SIZE(current_instruction().ingredients) > 1) {
      // array
      array_length = ingredients.at(1).at(0);
      trace(Primitive_recipe_depth, "mem") << "array size is " << array_length << end();
      size = array_length*size_of(type) + /*space for length*/1;
    }
    else {
      // scalar
      size = size_of(type);
    }
  }
//?   Total_alloc += size;
//?   Num_alloc++;
  // compute the region of memory to return
  // really crappy at the moment
  ensure_space(size);
  const long long int result = Current_routine->alloc;
  trace(Primitive_recipe_depth, "mem") << "new alloc: " << result << end();
  // save result
  products.resize(1);
  products.at(0).push_back(result);
  // initialize allocated space
  for (long long int address = result; address < result+size; ++address) {
    Memory[address] = 0;
  }
  if (SIZE(current_instruction().ingredients) > 1) {
    Memory[result] = array_length;
  }
  // bump
  Current_routine->alloc += size;
  // no support for reclaiming memory
  assert(Current_routine->alloc <= Current_routine->alloc_max);
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
    trace(Primitive_recipe_depth, "new") << "routine allocated memory from " << Current_routine->alloc << " to " << Current_routine->alloc_max << end();
  }
}

:(scenario new_initializes)
% Memory_allocated_until = 10;
% Memory[Memory_allocated_until] = 1;
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

//: Make sure that each routine gets a different alloc to start.
:(scenario new_concurrent)
recipe f1 [
  start-running f2:recipe
  1:address:number/raw <- new number:type
  # wait for f2 to complete
  {
    loop-unless 4:number/raw
  }
]
recipe f2 [
  2:address:number/raw <- new number:type
  # hack: assumes scheduler implementation
  3:boolean/raw <- equal 1:address:number/raw, 2:address:number/raw
  # signal f2 complete
  4:number/raw <- copy 1
]
+mem: storing 0 in location 3

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
Recipe_ordinal["abandon"] = ABANDON;
:(before "End Primitive Recipe Implementations")
case ABANDON: {
  if (SIZE(ingredients) != 1) {
    raise << maybe(current_recipe_name()) << "'abandon' requires one ingredient, but got '" << current_instruction().to_string() << "'\n" << end();
    break;
  }
  if (!scalar(ingredients.at(0))) {
    raise << maybe(current_recipe_name()) << "first ingredient of 'abandon' should be an address, but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
  long long int address = ingredients.at(0).at(0);
  reagent types = canonize(current_instruction().ingredients.at(0));
  if (types.types.empty() || types.types.at(0) != Type_ordinal["address"]) {
    raise << maybe(current_recipe_name()) << "first ingredient of 'abandon' should be an address, but got " << current_instruction().ingredients.at(0).original_string << '\n' << end();
    break;
  }
  reagent target_type = lookup_memory(types);
  abandon(address, size_of(target_type));
  break;
}

:(code)
void abandon(long long int address, long long int size) {
//?   Total_free += size;
//?   Num_free++;
//?   cerr << "abandon: " << size << '\n';
  // clear memory
  for (long long int curr = address; curr < address+size; ++curr)
    Memory[curr] = 0;
  // append existing free list to address
  Memory[address] = Free_list[size];
  Free_list[size] = address;
}

:(before "ensure_space(size)" following "case NEW")
if (Free_list[size]) {
  long long int result = Free_list[size];
  Free_list[size] = Memory[result];
  for (long long int curr = result+1; curr < result+size; ++curr) {
    if (Memory[curr] != 0) {
      raise << maybe(current_recipe_name()) << "memory in free list was not zeroed out: " << curr << '/' << result << "; somebody wrote to us after free!!!\n" << end();
      break;  // always fatal
    }
  }
  if (SIZE(current_instruction().ingredients) > 1)
    Memory[result] = array_length;
  else
    Memory[result] = 0;
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

:(before "End NEW Transform Special-cases")
  if (!inst.ingredients.empty()
      && !inst.ingredients.at(0).properties.empty()
      && !inst.ingredients.at(0).properties.at(0).second.empty()
      && inst.ingredients.at(0).properties.at(0).second.at(0) == "literal-string") {
    // skip transform
    inst.ingredients.at(0).initialized = true;
    goto end_new_transform;
  }

:(after "case NEW" following "Primitive Recipe Implementations")
if (is_literal(current_instruction().ingredients.at(0))
    && current_instruction().ingredients.at(0).properties.at(0).second.at(0) == "literal-string") {
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
  Memory[Current_routine->alloc++] = string_length;
  long long int curr = 0;
  const char* raw_contents = contents.c_str();
  for (long long int i = 0; i < string_length; ++i) {
    uint32_t curr_character;
    assert(curr < SIZE(contents));
    tb_utf8_char_to_unicode(&curr_character, &raw_contents[curr]);
    Memory[Current_routine->alloc] = curr_character;
    curr += tb_utf8_char_length(raw_contents[curr]);
    ++Current_routine->alloc;
  }
  // mu strings are not null-terminated in memory
  return result;
}

//: pass in commandline args as ingredients to main
//: todo: test this

:(after "Update main_routine")
Current_routine = main_routine;
for (long long int i = 1; i < argc; ++i) {
  vector<double> arg;
  arg.push_back(new_mu_string(argv[i]));
  Current_routine->calls.front().ingredient_atoms.push_back(arg);
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
  return read_mu_string(data.at(0));
}

:(scenario unicode_string)
recipe main [
  x:address:array:character <- new [♠]
  stash [foo:], x:address:array:character
]
+app: foo: ♠

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

bool is_mu_string(const reagent& x) {
  return SIZE(x.types) == 3
      && x.types.at(0) == Type_ordinal["address"]
      && x.types.at(1) == Type_ordinal["array"]
      && x.types.at(2) == Type_ordinal["character"];
}

string read_mu_string(long long int address) {
  long long int size = Memory[address];
  if (size == 0) return "";
  ostringstream tmp;
  for (long long int curr = address+1; curr <= address+size; ++curr) {
    tmp << to_unicode(static_cast<uint32_t>(Memory[curr]));
  }
  return tmp.str();
}

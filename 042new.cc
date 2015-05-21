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
long long int Reserved_for_tests = 1000;
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
trace("new") << "routine allocated memory from " << alloc << " to " << alloc_max;

//:: First handle 'type' operands.

:(before "End Mu Types Initialization")
Type_number["type"] = 0;
:(after "Per-recipe Transforms")
// replace type names with type_numbers
if (inst.operation == Recipe_number["new"]) {
  // first arg must be of type 'type'
  assert(SIZE(inst.ingredients) >= 1);
//?   cout << inst.ingredients.at(0).to_string() << '\n'; //? 1
  assert(isa_literal(inst.ingredients.at(0)));
  if (inst.ingredients.at(0).properties.at(0).second.at(0) == "type") {
    inst.ingredients.at(0).set_value(Type_number[inst.ingredients.at(0).name]);
  }
  trace("new") << inst.ingredients.at(0).name << " -> " << inst.ingredients.at(0).value;
}

//:: Now implement the primitive recipe.
//: todo: build 'new' in mu itself

:(before "End Primitive Recipe Declarations")
NEW,
:(before "End Primitive Recipe Numbers")
Recipe_number["new"] = NEW;
:(before "End Primitive Recipe Implementations")
case NEW: {
  // compute the space we need
  long long int size = 0;
  long long int array_length = 0;
  {
    vector<type_number> type;
    assert(isa_literal(current_instruction().ingredients.at(0)));
    type.push_back(current_instruction().ingredients.at(0).value);
    if (SIZE(current_instruction().ingredients) > 1) {
      // array
      array_length = ingredients.at(1).at(0);
      trace("mem") << "array size is " << array_length;
      size = array_length*size_of(type) + /*space for length*/1;
    }
    else {
      // scalar
      size = size_of(type);
    }
  }
  // compute the region of memory to return
  // really crappy at the moment
  ensure_space(size);
  const long long int result = Current_routine->alloc;
  trace("mem") << "new alloc: " << result;
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

:(code)
void ensure_space(long long int size) {
  assert(size <= Initial_memory_per_routine);
//?   cout << Current_routine->alloc << " " << Current_routine->alloc_max << " " << size << '\n'; //? 1
  if (Current_routine->alloc + size > Current_routine->alloc_max) {
    // waste the remaining space and create a new chunk
    Current_routine->alloc = Memory_allocated_until;
    Memory_allocated_until += Initial_memory_per_routine;
    Current_routine->alloc_max = Memory_allocated_until;
    trace("new") << "routine allocated memory from " << Current_routine->alloc << " to " << Current_routine->alloc_max;
  }
}

:(scenario new_initializes)
% Memory_allocated_until = 10;
% Memory[Memory_allocated_until] = 1;
recipe main [
  1:address:number <- new number:type
  2:number <- copy 1:address:number/deref
]
+mem: storing 0 in location 2

:(scenario new_array)
recipe main [
  1:address:array:number/raw <- new number:type, 5:literal
  2:address:number/raw <- new number:type
  3:number/raw <- subtract 2:address:number/raw, 1:address:array:number/raw
]
+run: 1:address:array:number/raw <- new number:type, 5:literal
+mem: array size is 5
# don't forget the extra location for array size
+mem: storing 6 in location 3

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
  4:number/raw <- copy 1:literal
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

//:: Next, extend 'new' to handle a string literal argument.

:(scenario new_string)
recipe main [
  1:address:array:character <- new [abc def]
  2:character <- index 1:address:array:character/deref, 5:literal
]
# number code for 'e'
+mem: storing 101 in location 2

:(after "case NEW" following "Primitive Recipe Implementations")
if (isa_literal(current_instruction().ingredients.at(0))
    && current_instruction().ingredients.at(0).properties.at(0).second.at(0) == "literal-string") {
  // allocate an array just large enough for it
  long long int string_length = SIZE(current_instruction().ingredients.at(0).name);
//?   cout << "string_length is " << string_length << '\n'; //? 1
  ensure_space(string_length+1);  // don't forget the extra location for array size
  products.resize(1);
  products.at(0).push_back(Current_routine->alloc);
  // initialize string
//?   cout << "new string literal: " << current_instruction().ingredients.at(0).name << '\n'; //? 1
  Memory[Current_routine->alloc++] = string_length;
  for (long long int i = 0; i < string_length; ++i) {
    Memory[Current_routine->alloc++] = current_instruction().ingredients.at(0).name.at(i);
  }
  // mu strings are not null-terminated in memory
  break;
}

//: Allocate more to routine when initializing a literal string
:(scenario new_string_overflow)
% Initial_memory_per_routine = 2;
recipe main [
  1:address:number/raw <- new number:type
  2:address:array:character/raw <- new [a]  # not enough room in initial page, if you take the array size into account
]
+new: routine allocated memory from 1000 to 1002
+new: routine allocated memory from 1002 to 1004

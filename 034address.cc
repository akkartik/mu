//: Addresses help us spend less time copying data around.

//: So far we've been operating on primitives like numbers and characters, and
//: we've started combining these primitives together into larger logical
//: units (containers or arrays) that may contain many different primitives at
//: once. Containers and arrays can grow quite large in complex programs, and
//: we'd like some way to efficiently share them between recipes without
//: constantly having to make copies. Right now 'next-ingredient' and 'return'
//: copy data across recipe boundaries. To avoid copying large quantities of
//: data around, we'll use *addresses*. An address is a bookmark to some
//: arbitrary quantity of data (the *payload*). It's a primitive, so it's as
//: efficient to copy as a number. To read or modify the payload 'pointed to'
//: by an address, we'll perform a *lookup*.
//:
//: The notion of 'lookup' isn't an instruction like 'add' or 'subtract'.
//: Instead it's an operation that can be performed when reading any of the
//: ingredients of an instruction, and when writing to any of the products. To
//: write to the payload of an ingredient rather than its value, simply add
//: the /lookup property to it. Modern computers provide efficient support for
//: addresses and lookups, making this a realistic feature.

//: todo: give 'new' a custodian ingredient. Following malloc/free is a temporary hack.

:(scenario new)
# call 'new' two times with identical types without modifying the results; you
# should get back different results
def main [
  1:&:num/raw <- new num:type
  2:&:num/raw <- new num:type
  3:bool/raw <- equal 1:&:num/raw, 2:&:num/raw
]
+mem: storing 0 in location 3

:(scenario new_array)
# call 'new' with a second ingredient to allocate an array of some type rather than a single copy
def main [
  1:&:@:num/raw <- new num:type, 5
  2:&:num/raw <- new num:type
  3:num/raw <- subtract 2:&:num/raw, 1:&:@:num/raw
]
+run: {1: ("address" "array" "number"), "raw": ()} <- new {num: "type"}, {5: "literal"}
+mem: array length is 5
# don't forget the extra location for array length
+mem: storing 6 in location 3

:(scenario dilated_reagent_with_new)
def main [
  1:&:&:num <- new {(& num): type}
]
+new: size of '(& num)' is 1

//: 'new' takes a weird 'type' as its first ingredient; don't error on it
:(before "End Mu Types Initialization")
put(Type_ordinal, "type", 0);
:(code)
bool is_mu_type_literal(const reagent& r) {
  return is_literal(r) && r.type && r.type->name == "type";
}

:(before "End Primitive Recipe Declarations")
NEW,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "new", NEW);
:(before "End Primitive Recipe Checks")
case NEW: {
  const recipe& caller = get(Recipe, r);
  if (inst.ingredients.empty() || SIZE(inst.ingredients) > 2) {
    raise << maybe(caller.name) << "'new' requires one or two ingredients, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  // End NEW Check Special-cases
  const reagent& type = inst.ingredients.at(0);
  if (!is_mu_type_literal(type)) {
    raise << maybe(caller.name) << "first ingredient of 'new' should be a type, but got '" << type.original_string << "'\n" << end();
    break;
  }
  if (SIZE(inst.ingredients) > 1 && !is_mu_number(inst.ingredients.at(1))) {
    raise << maybe(caller.name) << "second ingredient of 'new' should be a number (array length), but got '" << type.original_string << "'\n" << end();
    break;
  }
  if (inst.products.empty()) {
    raise << maybe(caller.name) << "result of 'new' should never be ignored\n" << end();
    break;
  }
  if (!product_of_new_is_valid(inst)) {
    raise << maybe(caller.name) << "product of 'new' has incorrect type: '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(code)
bool product_of_new_is_valid(const instruction& inst) {
  reagent/*copy*/ product = inst.products.at(0);
  // Update NEW product in Check
  if (!product.type || product.type->atom || product.type->left->value != Address_type_ordinal)
    return false;
  drop_from_type(product, "address");
  if (SIZE(inst.ingredients) > 1) {
    // array allocation
    if (!product.type || product.type->atom || product.type->left->value != Array_type_ordinal)
      return false;
    drop_from_type(product, "array");
  }
  reagent/*local*/ expected_product(new_type_tree(inst.ingredients.at(0).name));
  return types_strictly_match(product, expected_product);
}

void drop_from_type(reagent& r, string expected_type) {
  assert(!r.type->atom);
  if (r.type->left->name != expected_type) {
    raise << "can't drop2 " << expected_type << " from '" << to_string(r) << "'\n" << end();
    return;
  }
  // r.type = r.type->right
  type_tree* tmp = r.type;
  r.type = tmp->right;
  tmp->right = NULL;
  delete tmp;
  // if (!r.type->right) r.type = r.type->left
  assert(!r.type->atom);
  if (r.type->right) return;
  tmp = r.type;
  r.type = tmp->left;
  tmp->left = NULL;
  delete tmp;
}

:(scenario new_returns_incorrect_type)
% Hide_errors = true;
def main [
  1:bool <- new num:type
]
+error: main: product of 'new' has incorrect type: '1:bool <- new num:type'

:(scenario new_discerns_singleton_list_from_atom_container)
% Hide_errors = true;
def main [
  1:&:num/raw <- new {(num): type}  # should be '{num: type}'
]
+error: main: product of 'new' has incorrect type: '1:&:num/raw <- new {(num): type}'

:(scenario new_with_type_abbreviation)
def main [
  1:&:num/raw <- new num:type
]
$error: 0

:(scenario new_with_type_abbreviation_inside_compound)
def main [
  {1: (& & num), raw: ()} <- new {(& num): type}
]
$error: 0

//: To implement 'new', a Mu transform turns all 'new' instructions into
//: 'allocate' instructions that precompute the amount of memory they want to
//: allocate.

//: Ensure that we never call 'allocate' directly, and that there's no 'new'
//: instructions left after the transforms have run.
:(before "End Primitive Recipe Checks")
case ALLOCATE: {
  raise << "never call 'allocate' directly'; always use 'new'\n" << end();
  break;
}
:(before "End Primitive Recipe Implementations")
case NEW: {
  raise << "no implementation for 'new'; why wasn't it translated to 'allocate'? Please save a copy of your program and send it to Kartik.\n" << end();
  break;
}

:(after "Transform.push_back(check_instruction)")  // check_instruction will guard against direct 'allocate' instructions below
Transform.push_back(transform_new_to_allocate);  // idempotent

:(code)
void transform_new_to_allocate(const recipe_ordinal r) {
  trace(9991, "transform") << "--- convert 'new' to 'allocate' for recipe " << get(Recipe, r).name << end();
  for (int i = 0;  i < SIZE(get(Recipe, r).steps);  ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    // Convert 'new' To 'allocate'
    if (inst.name == "new") {
      if (inst.ingredients.empty()) return;  // error raised elsewhere
      inst.operation = ALLOCATE;
      type_tree* type = new_type_tree(inst.ingredients.at(0).name);
      inst.ingredients.at(0).set_value(size_of(type));
      trace(9992, "new") << "size of '" << inst.ingredients.at(0).name << "' is " << inst.ingredients.at(0).value << end();
      delete type;
    }
  }
}

//: implement 'allocate' based on size

:(before "End Globals")
extern const int Reserved_for_tests = 1000;
int Memory_allocated_until = Reserved_for_tests;
int Initial_memory_per_routine = 100000;
:(before "End Reset")
Memory_allocated_until = Reserved_for_tests;
Initial_memory_per_routine = 100000;
:(before "End routine Fields")
int alloc, alloc_max;
:(before "End routine Constructor")
alloc = Memory_allocated_until;
Memory_allocated_until += Initial_memory_per_routine;
alloc_max = Memory_allocated_until;
trace("new") << "routine allocated memory from " << alloc << " to " << alloc_max << end();

:(before "End Primitive Recipe Declarations")
ALLOCATE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "allocate", ALLOCATE);
:(before "End Primitive Recipe Implementations")
case ALLOCATE: {
  // compute the space we need
  int size = ingredients.at(0).at(0);
  if (SIZE(ingredients) > 1) {
    // array allocation
    trace("mem") << "array length is " << ingredients.at(1).at(0) << end();
    size = /*space for length*/1 + size*ingredients.at(1).at(0);
  }
  int result = allocate(size);
  if (SIZE(current_instruction().ingredients) > 1) {
    // initialize array length
    trace("mem") << "storing " << ingredients.at(1).at(0) << " in location " << result << end();
    put(Memory, result, ingredients.at(1).at(0));
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}
:(code)
int allocate(int size) {
  trace("mem") << "allocating size " << size << end();
//?   Total_alloc += size;
//?   ++Num_alloc;
  // Allocate Special-cases
  // compute the region of memory to return
  // really crappy at the moment
  ensure_space(size);
  const int result = Current_routine->alloc;
  trace("mem") << "new alloc: " << result << end();
  // initialize allocated space
  for (int address = result;  address < result+size;  ++address) {
    trace("mem") << "storing 0 in location " << address << end();
    put(Memory, address, 0);
  }
  Current_routine->alloc += size;
  // no support yet for reclaiming memory between routines
  assert(Current_routine->alloc <= Current_routine->alloc_max);
  return result;
}

//: statistics for debugging
//? :(before "End Globals")
//? int Total_alloc = 0;
//? int Num_alloc = 0;
//? int Total_free = 0;
//? int Num_free = 0;
//? :(before "End Reset")
//? if (!Memory.empty()) {
//?   cerr << Total_alloc << "/" << Num_alloc
//?        << " vs " << Total_free << "/" << Num_free << '\n';
//?   cerr << SIZE(Memory) << '\n';
//? }
//? Total_alloc = Num_alloc = Total_free = Num_free = 0;

:(code)
void ensure_space(int size) {
  if (size > Initial_memory_per_routine) {
    cerr << "can't allocate " << size << " locations, that's too much compared to " << Initial_memory_per_routine << ".\n";
    exit(1);
  }
  if (Current_routine->alloc + size > Current_routine->alloc_max) {
    // waste the remaining space and create a new chunk
    Current_routine->alloc = Memory_allocated_until;
    Memory_allocated_until += Initial_memory_per_routine;
    Current_routine->alloc_max = Memory_allocated_until;
    trace("new") << "routine allocated memory from " << Current_routine->alloc << " to " << Current_routine->alloc_max << end();
  }
}

:(scenario new_initializes)
% Memory_allocated_until = 10;
% put(Memory, Memory_allocated_until, 1);
def main [
  1:&:num <- new num:type
]
+mem: storing 0 in location 10

:(scenario new_size)
def main [
  11:&:num/raw <- new num:type
  12:&:num/raw <- new num:type
  13:num/raw <- subtract 12:&:num/raw, 11:&:num/raw
]
# size of number
+mem: storing 1 in location 13

:(scenario new_array_size)
def main [
  1:&:@:num/raw <- new num:type, 5
  2:&:num/raw <- new num:type
  3:num/raw <- subtract 2:&:num/raw, 1:&:@:num/raw
]
# 5 locations for array contents + array length
+mem: storing 6 in location 3

:(scenario new_empty_array)
def main [
  1:&:@:num/raw <- new num:type, 0
  2:&:num/raw <- new num:type
  3:num/raw <- subtract 2:&:num/raw, 1:&:@:num/raw
]
+run: {1: ("address" "array" "number"), "raw": ()} <- new {num: "type"}, {0: "literal"}
+mem: array length is 0
# one location for array length
+mem: storing 1 in location 3

//: If a routine runs out of its initial allocation, it should allocate more.
:(scenario new_overflow)
% Initial_memory_per_routine = 2;  // barely enough room for point allocation below
def main [
  1:&:num/raw <- new num:type
  2:&:point/raw <- new point:type  # not enough room in initial page
]
+new: routine allocated memory from 1000 to 1002
+new: routine allocated memory from 1002 to 1004

:(scenario new_without_ingredient)
% Hide_errors = true;
def main [
  1:&:num <- new  # missing ingredient
]
+error: main: 'new' requires one or two ingredients, but got '1:&:num <- new'

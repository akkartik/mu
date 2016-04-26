//: Addresses help us spend less time copying data around.

//: So far we've been operating on primitives like numbers and characters, and
//: we've started combining these primitives together into larger logical
//: units (containers or arrays) that may contain many different primitives at
//: once. Containers and arrays can grow quite large in complex programs, and
//: we'd like some way to efficiently share them between recipes without
//: constantly having to make copies. Right now 'next-ingredient' and 'reply'
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
//:
//: To recap: an address is a bookmark to some potentially large payload, and
//: you can replace any ingredient or product with a lookup to an address of
//: the appropriate type. But how do we get addresses to begin with? That
//: requires a little more explanation. Once we introduce the notion of
//: bookmarks to data, we have to think about the life cycle of a piece of
//: data and its bookmarks (because remember, bookmarks can be copied around
//: just like anything else). Otherwise several bad outcomes can result (and
//: indeed *have* resulted in past languages like C):
//:
//:   a) You can run out of memory if you don't have a way to reclaim
//:   data.
//:   b) If you allow data to be reclaimed, you have to be careful not to
//:   leave any stale addresses pointing at it. Otherwise your program might
//:   try to lookup such an address and find something unexpected. Such
//:   problems can be very hard to track down, and they can also be exploited
//:   to break into your computer over the network, etc.
//:
//: To avoid these problems, we introduce the notion of a *reference count* or
//: refcount. The life cycle of a bit of data accessed through addresses looks
//: like this.
//:
//:    We create space in computer memory for it using the 'new' instruction.
//:    The 'new' instruction takes a type as an ingredient, allocates
//:    sufficient space to hold that type, and returns an address (bookmark)
//:    to the allocated space.
//:
//:      x:address:number <- new number:type
//:
//:                     +------------+
//:          x -------> |  number    |
//:                     +------------+
//:
//:    That isn't entirely accurate. Under the hood, 'new' allocates an extra
//:    number -- the refcount:
//:
//:                     +------------+------------+
//:          x -------> | refcount   |  number    |
//:                     +------------+------------+
//:
//:    This probably seems like a waste of space. In practice it isn't worth
//:    allocating individual numbers and our payload will tend to be larger,
//:    so the picture would look more like this (zooming out a bit):
//:
//:                         +-------------------------+
//:                     +---+                         |
//:          x -------> | r |                         |
//:                     +---+        DATA             |
//:                         |                         |
//:                         |                         |
//:                         +-------------------------+
//:
//:    (Here 'r' denotes the refcount. It occupies a tiny amount of space
//:    compared to the payload.)
//:
//:    Anyways, back to our example where the data is just a single number.
//:    After the call to 'new', Mu's map of memory looks like this:
//:
//:                     +---+------------+
//:          x -------> | 1 |  number    |
//:                     +---+------------+
//:
//:    The refcount of 1 here indicates that this number has one bookmark
//:    outstanding. If you then make a copy of x, the refcount increments:
//:
//:      y:address:number <- copy x
//:
//:          x ---+     +---+------------+
//:               +---> | 2 |  number    |
//:          y ---+     +---+------------+
//:
//:    Whether you access the payload through x or y, Mu knows how many
//:    bookmarks are outstanding to it. When you change x or y, the refcount
//:    transparently decrements:
//:
//:      x <- copy 0  # an address is just a number, you can always write 0 to it
//:
//:                     +---+------------+
//:          y -------> | 1 |  number    |
//:                     +---+------------+
//:
//:    The final flourish is what happens when the refcount goes down to 0: Mu
//:    reclaims the space occupied by both refcount and payload in memory, and
//:    they're ready to be reused by later calls to 'new'.
//:
//:      y <- copy 0
//:
//:                     +---+------------+
//:                     | 0 |  XXXXXXX   |
//:                     +---+------------+
//:
//: Using refcounts fixes both our problems a) and b) above: you can use
//: memory for many different purposes as many times as you want without
//: running out of memory, and you don't have to worry about ever leaving a
//: dangling bookmark when you reclaim memory.
//:
//: Ok, let's rewind the clock back to this situation where we have an
//: address:
//:
//:                     +---+------------+
//:          x -------> | 1 |  number    |
//:                     +---+------------+
//:
//: Once you have an address you can read or modify its payload by performing
//: a lookup:
//:
//:     x/lookup <- copy 34
//:
//: or more concisely:
//:
//:     *x <- copy 34
//:
//: This modifies not x, but the payload x points to:
//:
//:                     +---+------------+
//:          x -------> | 1 |         34 |
//:                     +---+------------+
//:
//: You can also read from the payload in instructions like this:
//:
//:     z:number <- add *x, 1
//:
//: After this instruction runs the value of z will be 35.
//:
//: The rest of this (long) layer is divided up into 4 sections:
//:   the implementation of the 'new' instruction
//:   how instructions lookup addresses
//:   how instructions update refcounts when modifying address variables
//:   how instructions abandon and reclaim memory when refcounts drop to 0

//:: the 'new' instruction allocates unique memory including a refcount
//: todo: give 'new' a custodian ingredient. Following malloc/free is a temporary hack.

:(scenario new)
# call 'new' two times with identical types without modifying the results; you
# should get back different results
def main [
  1:address:number/raw <- new number:type
  2:address:number/raw <- new number:type
  3:boolean/raw <- equal 1:address:number/raw, 2:address:number/raw
]
+mem: storing 0 in location 3

//: 'new' takes a weird 'type' as its first ingredient; don't error on it
:(before "End Mu Types Initialization")
put(Type_ordinal, "type", 0);
:(code)
bool is_mu_type_literal(reagent r) {
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
    raise << maybe(caller.name) << "'new' requires one or two ingredients, but got " << to_original_string(inst) << '\n' << end();
    break;
  }
  // End NEW Check Special-cases
  reagent type = inst.ingredients.at(0);
  if (!is_mu_type_literal(type)) {
    raise << maybe(caller.name) << "first ingredient of 'new' should be a type, but got " << type.original_string << '\n' << end();
    break;
  }
  if (inst.products.empty()) {
    raise << maybe(caller.name) << "result of 'new' should never be ignored\n" << end();
    break;
  }
  if (!product_of_new_is_valid(inst)) {
    raise << maybe(caller.name) << "product of 'new' has incorrect type: " << to_original_string(inst) << '\n' << end();
    break;
  }
  break;
}
:(code)
bool product_of_new_is_valid(const instruction& inst) {
  reagent product = inst.products.at(0);
  canonize_type(product);
  if (!product.type || product.type->value != get(Type_ordinal, "address"))
    return false;
  drop_from_type(product, "address");
  if (SIZE(inst.ingredients) > 1) {
    // array allocation
    if (!product.type || product.type->value != get(Type_ordinal, "array")) return false;
    drop_from_type(product, "array");
  }
  reagent expected_product("x:"+inst.ingredients.at(0).name);
  // End Post-processing(expected_product) When Checking 'new'
  return types_strictly_match(product, expected_product);
}

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
  for (int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    // Convert 'new' To 'allocate'
    if (inst.name == "new") {
      inst.operation = ALLOCATE;
      string_tree* type_name = new string_tree(inst.ingredients.at(0).name);
      // End Post-processing(type_name) When Converting 'new'
      type_tree* type = new_type_tree(type_name);
      inst.ingredients.at(0).set_value(size_of(type));
      trace(9992, "new") << "size of " << to_string(type_name) << " is " << inst.ingredients.at(0).value << end();
      delete type;
      delete type_name;
    }
  }
}

//: implement 'allocate' based on size

:(before "End Globals")
const int Reserved_for_tests = 1000;
int Memory_allocated_until = Reserved_for_tests;
int Initial_memory_per_routine = 100000;
:(before "End Setup")
Memory_allocated_until = Reserved_for_tests;
Initial_memory_per_routine = 100000;
:(before "End routine Fields")
int alloc, alloc_max;
:(before "End routine Constructor")
alloc = Memory_allocated_until;
Memory_allocated_until += Initial_memory_per_routine;
alloc_max = Memory_allocated_until;
trace(9999, "new") << "routine allocated memory from " << alloc << " to " << alloc_max << end();

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
    trace(9999, "mem") << "array size is " << ingredients.at(1).at(0) << end();
    size = /*space for length*/1 + size*ingredients.at(1).at(0);
  }
  // include space for refcount
  size++;
  trace(9999, "mem") << "allocating size " << size << end();
//?   Total_alloc += size;
//?   Num_alloc++;
  // compute the region of memory to return
  // really crappy at the moment
  ensure_space(size);
  const int result = Current_routine->alloc;
  trace(9999, "mem") << "new alloc: " << result << end();
  // save result
  products.resize(1);
  products.at(0).push_back(result);
  // initialize allocated space
  for (int address = result; address < result+size; ++address)
    put(Memory, address, 0);
  if (SIZE(current_instruction().ingredients) > 1) {
    // initialize array length
    trace(9999, "mem") << "storing " << ingredients.at(1).at(0) << " in location " << result+/*skip refcount*/1 << end();
    put(Memory, result+/*skip refcount*/1, ingredients.at(1).at(0));
  }
  Current_routine->alloc += size;
  // no support yet for reclaiming memory between routines
  assert(Current_routine->alloc <= Current_routine->alloc_max);
  break;
}

//: statistics for debugging
//? :(before "End Globals")
//? int Total_alloc = 0;
//? int Num_alloc = 0;
//? int Total_free = 0;
//? int Num_free = 0;
//? :(before "End Setup")
//? Total_alloc = Num_alloc = Total_free = Num_free = 0;
//? :(before "End Teardown")
//? cerr << Total_alloc << "/" << Num_alloc
//?      << " vs " << Total_free << "/" << Num_free << '\n';
//? cerr << SIZE(Memory) << '\n';

:(code)
void ensure_space(int size) {
  if (size > Initial_memory_per_routine) {
    tb_shutdown();
    cerr << "can't allocate " << size << " locations, that's too much compared to " << Initial_memory_per_routine << ".\n";
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
def main [
  1:address:number <- new number:type
  2:number <- copy 1:address:number/lookup
]
+mem: storing 0 in location 2

:(scenario new_error)
% Hide_errors = true;
def main [
  1:number/raw <- new number:type
]
+error: main: product of 'new' has incorrect type: 1:number/raw <- new number:type

:(scenario new_array)
def main [
  1:address:array:number/raw <- new number:type, 5
  2:address:number/raw <- new number:type
  3:number/raw <- subtract 2:address:number/raw, 1:address:array:number/raw
]
+run: {1: ("address" "array" "number"), "raw": ()} <- new {number: "type"}, {5: "literal"}
+mem: array size is 5
# don't forget the extra location for array size, and the second extra location for the refcount
+mem: storing 7 in location 3

:(scenario new_empty_array)
def main [
  1:address:array:number/raw <- new number:type, 0
  2:address:number/raw <- new number:type
  3:number/raw <- subtract 2:address:number/raw, 1:address:array:number/raw
]
+run: {1: ("address" "array" "number"), "raw": ()} <- new {number: "type"}, {0: "literal"}
+mem: array size is 0
# one location for array size, and one for the refcount
+mem: storing 2 in location 3

//: If a routine runs out of its initial allocation, it should allocate more.
:(scenario new_overflow)
% Initial_memory_per_routine = 3;  // barely enough room for point allocation below
def main [
  1:address:number/raw <- new number:type
  2:address:point/raw <- new point:type  # not enough room in initial page
]
+new: routine allocated memory from 1000 to 1003
+new: routine allocated memory from 1003 to 1006

//:: /lookup can go from an address to the payload it points at, skipping the refcount
//: the tests in this section use unsafe operations so as to stay decoupled from 'new'

:(scenario copy_indirect)
def main [
  1:address:number <- copy 10/unsafe
  11:number <- copy 34
  # This loads location 1 as an address and looks up *that* location.
  2:number <- copy 1:address:number/lookup
]
# 1 contains 10. Skip refcount and lookup location 11.
+mem: storing 34 in location 2

:(before "End Preprocess read_memory(x)")
canonize(x);

//: similarly, write to addresses pointing at other locations using the
//: 'lookup' property
:(scenario store_indirect)
def main [
  1:address:number <- copy 10/unsafe
  1:address:number/lookup <- copy 34
]
+mem: storing 34 in location 11

:(before "End Preprocess write_memory(x)")
canonize(x);
if (x.value == 0) {
  raise << "can't write to location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
  return;
}

//: writes to address 0 always loudly fail
:(scenario store_to_0_fails)
% Hide_errors = true;
def main [
  1:address:number <- copy 0
  1:address:number/lookup <- copy 34
]
-mem: storing 34 in location 0
+error: can't write to location 0 in '1:address:number/lookup <- copy 34'

:(code)
void canonize(reagent& x) {
  if (is_literal(x)) return;
  // End canonize(x) Special-cases
  while (has_property(x, "lookup"))
    lookup_memory(x);
}

void lookup_memory(reagent& x) {
  if (!x.type || x.type->value != get(Type_ordinal, "address")) {
    raise << maybe(current_recipe_name()) << "tried to /lookup " << x.original_string << " but it isn't an address\n" << end();
    return;
  }
  // compute value
  if (x.value == 0) {
    raise << maybe(current_recipe_name()) << "tried to /lookup 0\n" << end();
    return;
  }
  trace(9999, "mem") << "location " << x.value << " is " << no_scientific(get_or_insert(Memory, x.value)) << end();
  x.set_value(get_or_insert(Memory, x.value));
  drop_from_type(x, "address");
  if (x.value != 0) {
    trace(9999, "mem") << "skipping refcount at " << x.value << end();
    x.set_value(x.value+1);  // skip refcount
  }
  drop_one_lookup(x);
}

void test_lookup_address_skips_refcount() {
  reagent x("*x:address:number");
  x.set_value(34);  // unsafe
  put(Memory, 34, 1000);
  lookup_memory(x);
  CHECK_TRACE_CONTENTS("mem: skipping refcount at 1000");
  CHECK_EQ(x.value, 1001);
}

void test_lookup_zero_address_does_not_skip_refcount() {
  reagent x("*x:address:number");
  x.set_value(34);  // unsafe
  put(Memory, 34, 0);
  lookup_memory(x);
  CHECK_TRACE_DOESNT_CONTAIN("mem: skipping refcount at 0");
  CHECK_EQ(x.value, 0);
}

:(after "bool types_strictly_match(reagent to, reagent from)")
  if (!canonize_type(to)) return false;
  if (!canonize_type(from)) return false;

:(after "bool is_mu_array(reagent r)")
  if (!canonize_type(r)) return false;

:(after "bool is_mu_address(reagent r)")
  if (!canonize_type(r)) return false;

:(after "bool is_mu_number(reagent r)")
  if (!canonize_type(r)) return false;
:(after "bool is_mu_boolean(reagent r)")
  if (!canonize_type(r)) return false;

:(after "Update product While Type-checking Merge")
if (!canonize_type(product)) continue;

:(before "End Compute Call Ingredient")
canonize_type(ingredient);
:(before "End Preprocess NEXT_INGREDIENT product")
canonize_type(product);
:(before "End Check REPLY Copy(lhs, rhs)
canonize_type(lhs);
canonize_type(rhs);

:(code)
bool canonize_type(reagent& r) {
  while (has_property(r, "lookup")) {
    if (!r.type || r.type->value != get(Type_ordinal, "address")) {
      raise << "can't lookup non-address: " << to_string(r) << ": " << to_string(r.type) << '\n' << end();
      return false;
    }
    drop_from_type(r, "address");
    drop_one_lookup(r);
  }
  return true;
}

void drop_from_type(reagent& r, string expected_type) {
  if (r.type->name != expected_type) {
    raise << "can't drop2 " << expected_type << " from " << to_string(r) << '\n' << end();
    return;
  }
  type_tree* tmp = r.type;
  r.type = tmp->right;
  tmp->right = NULL;
  delete tmp;
}

void drop_one_lookup(reagent& r) {
  for (vector<pair<string, string_tree*> >::iterator p = r.properties.begin(); p != r.properties.end(); ++p) {
    if (p->first == "lookup") {
      r.properties.erase(p);
      return;
    }
  }
  assert(false);
}

//: Tedious fixup to support addresses in container/array instructions of previous layers.
//: Most instructions don't require fixup if they use the 'ingredients' and
//: 'products' variables in run_current_routine().

:(scenario get_indirect)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  2:number <- get 1:address:point/lookup, 0:offset
]
+mem: storing 34 in location 2

:(scenario get_indirect2)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  2:address:number <- copy 20/unsafe
  2:address:number/lookup <- get 1:address:point/lookup, 0:offset
]
+mem: storing 34 in location 21

:(scenario include_nonlookup_properties)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  2:number <- get 1:address:point/lookup/foo, 0:offset
]
+mem: storing 34 in location 2

:(after "Update GET base in Check")
if (!canonize_type(base)) break;
:(after "Update GET product in Check")
if (!canonize_type(product)) break;
:(after "Update GET base in Run")
canonize(base);

:(scenario put_indirect)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  1:address:point/lookup <- put 1:address:point/lookup, 0:offset, 36
]
+mem: storing 36 in location 11

:(after "Update PUT base in Check")
if (!canonize_type(base)) break;
:(after "Update PUT offset in Check")
if (!canonize_type(offset)) break;
:(after "Update PUT base in Run")
canonize(base);

:(scenario copy_array_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  2:array:number <- copy 1:address:array:number/lookup
]
+mem: storing 3 in location 2
+mem: storing 14 in location 3
+mem: storing 15 in location 4
+mem: storing 16 in location 5

:(before "Update CREATE_ARRAY product in Check")
// 'create-array' does not support indirection. Static arrays are meant to be
// allocated on the 'stack'.
assert(!has_property(product, "lookup"));
:(before "Update CREATE_ARRAY product in Run")
// 'create-array' does not support indirection. Static arrays are meant to be
// allocated on the 'stack'.
assert(!has_property(product, "lookup"));

:(scenario index_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  2:number <- index 1:address:array:number/lookup, 1
]
+mem: storing 15 in location 2

:(before "Update INDEX base in Check")
if (!canonize_type(base)) break;
:(before "Update INDEX index in Check")
if (!canonize_type(index)) break;
:(before "Update INDEX product in Check")
if (!canonize_type(product)) break;

:(before "Update INDEX base in Run")
canonize(base);
:(before "Update INDEX index in Run")
canonize(index);

:(scenario put_index_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  1:address:array:number/lookup <- put-index 1:address:array:number/lookup, 1, 34
]
+mem: storing 34 in location 13

:(scenario put_index_indirect_2)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:number <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 1
  5:address:array:number/lookup <- put-index 1:array:number:3, 5:address:number/lookup, 34
]
+mem: storing 34 in location 3

:(before "Update PUT_INDEX base in Check")
if (!canonize_type(base)) break;
:(before "Update PUT_INDEX index in Check")
if (!canonize_type(index)) break;
:(before "Update PUT_INDEX value in Check")
if (!canonize_type(value)) break;

:(before "Update PUT_INDEX base in Run")
canonize(base);
:(before "Update PUT_INDEX index in Run")
canonize(index);

:(scenario length_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  2:number <- length 1:address:array:number/lookup
]
+mem: storing 3 in location 2

:(before "Update LENGTH array in Check")
if (!canonize_type(array)) break;
:(before "Update LENGTH array in Run")
canonize(array);

:(scenario maybe_convert_indirect)
def main [
  # 10 reserved for refcount
  11:number-or-point <- merge 0/number, 34
  1:address:number-or-point <- copy 10/unsafe
  2:number, 3:boolean <- maybe-convert 1:address:number-or-point/lookup, i:variant
]
+mem: storing 34 in location 2
+mem: storing 1 in location 3

:(scenario maybe_convert_indirect_2)
def main [
  # 10 reserved for refcount
  11:number-or-point <- merge 0/number, 34
  1:address:number-or-point <- copy 10/unsafe
  2:address:number <- copy 20/unsafe
  2:address:number/lookup, 3:boolean <- maybe-convert 1:address:number-or-point/lookup, i:variant
]
+mem: storing 34 in location 21
+mem: storing 1 in location 3

:(scenario maybe_convert_indirect_3)
def main [
  # 10 reserved for refcount
  11:number-or-point <- merge 0/number, 34
  1:address:number-or-point <- copy 10/unsafe
  2:address:boolean <- copy 20/unsafe
  3:number, 2:address:boolean/lookup <- maybe-convert 1:address:number-or-point/lookup, i:variant
]
+mem: storing 34 in location 3
+mem: storing 1 in location 21

:(before "Update MAYBE_CONVERT base in Check")
if (!canonize_type(base)) break;
:(before "Update MAYBE_CONVERT product in Check")
if (!canonize_type(product)) break;
:(before "Update MAYBE_CONVERT status in Check")
if (!canonize_type(status)) break;

:(before "Update MAYBE_CONVERT base in Run")
canonize(base);
:(before "Update MAYBE_CONVERT product in Run")
canonize(product);
:(before "Update MAYBE_CONVERT status in Run")
canonize(status);

:(scenario merge_exclusive_container_indirect)
def main [
  1:address:number-or-point <- copy 10/unsafe
  1:address:number-or-point/lookup <- merge 0/number, 34
]
# skip 10 for refcount
+mem: storing 0 in location 11
+mem: storing 34 in location 12

:(before "Update size_mismatch Check for MERGE(x)
canonize(x);

//: abbreviation for '/lookup': a prefix '*'

:(scenario lookup_abbreviation)
def main [
  1:address:number <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  3:number <- copy *1:address:number
]
+parse: ingredient: {1: ("address" "number"), "lookup": ()}
+mem: storing 34 in location 3

:(before "End Parsing reagent")
{
  while (!name.empty() && name.at(0) == '*') {
    name.erase(0, 1);
    properties.push_back(pair<string, string_tree*>("lookup", NULL));
  }
  if (name.empty())
    raise << "illegal name " << original_string << '\n' << end();
}

//:: update refcounts when copying addresses

:(scenario refcounts)
def main [
  1:address:number <- copy 1000/unsafe
  2:address:number <- copy 1:address:number
  1:address:number <- copy 0
  2:address:number <- copy 0
]
+run: {1: ("address" "number")} <- copy {1000: "literal", "unsafe": ()}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "number")} <- copy {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {2: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 1 -> 0
# the /unsafe corrupts memory but fortunately we won't be running any more 'new' in this scenario
+mem: automatically abandoning 1000

:(before "End write_memory(reagent x) Special-cases")
if (x.type->value == get(Type_ordinal, "address")) {
  // compute old address of x, as well as new address we want to write in
  int old_address = get_or_insert(Memory, x.value);
  assert(scalar(data));
  int new_address = data.at(0);
  // decrement refcount of old address
  if (old_address) {
    int old_refcount = get_or_insert(Memory, old_address);
    trace(9999, "mem") << "decrementing refcount of " << old_address << ": " << old_refcount << " -> " << (old_refcount-1) << end();
    put(Memory, old_address, old_refcount-1);
  }
  // perform the write
  trace(9999, "mem") << "storing " << no_scientific(data.at(0)) << " in location " << x.value << end();
  put(Memory, x.value, new_address);
  // increment refcount of new address
  if (new_address) {
    int new_refcount = get_or_insert(Memory, new_address);
    assert(new_refcount >= 0);  // == 0 only when new_address == old_address
    trace(9999, "mem") << "incrementing refcount of " << new_address << ": " << new_refcount << " -> " << (new_refcount+1) << end();
    put(Memory, new_address, new_refcount+1);
  }
  // abandon old address if necessary
  // do this after all refcount updates are done just in case old and new are identical
  assert(old_address >= 0);
  if (old_address == 0) return;
  if (get_or_insert(Memory, old_address) < 0) {
    DUMP("");
    cerr << old_address << ' ' << get_or_insert(Memory, old_address) << '\n';
  }
  assert(get_or_insert(Memory, old_address) >= 0);
  if (get_or_insert(Memory, old_address) > 0) return;
  // lookup_memory without drop_one_lookup {
  trace(9999, "mem") << "automatically abandoning " << old_address << end();
  trace(9999, "mem") << "computing size to abandon at " << x.value << end();
  x.set_value(old_address+/*skip refcount*/1);
  drop_from_type(x, "address");
  // }
  abandon(old_address, size_of(x)+/*refcount*/1);
  return;
}

:(scenario refcounts_2)
def main [
  1:address:number <- new number:type
  # over-writing one allocation with another
  1:address:number <- new number:type
  1:address:number <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: automatically abandoning 1000

:(scenario refcounts_3)
def main [
  1:address:number <- new number:type
  # passing in addresses to recipes increments refcount
  foo 1:address:number
  1:address:number <- copy 0
]
def foo [
  2:address:number <- next-ingredient
  # return does NOT yet decrement refcount; memory must be explicitly managed
  2:address:number <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "number")} <- next-ingredient
+mem: incrementing refcount of 1000: 1 -> 2
+run: {2: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 1 -> 0
+mem: automatically abandoning 1000

:(scenario refcounts_4)
def main [
  1:address:number <- new number:type
  # idempotent copies leave refcount unchanged
  1:address:number <- copy 1:address:number
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {1: ("address" "number")} <- copy {1: ("address" "number")}
+mem: decrementing refcount of 1000: 1 -> 0
+mem: incrementing refcount of 1000: 0 -> 1

:(scenario refcounts_5)
def main [
  1:address:number <- new number:type
  # passing in addresses to recipes increments refcount
  foo 1:address:number
  # return does NOT yet decrement refcount; memory must be explicitly managed
  1:address:number <- new number:type
]
def foo [
  2:address:number <- next-ingredient
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "number")} <- next-ingredient
+mem: incrementing refcount of 1000: 1 -> 2
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: decrementing refcount of 1000: 2 -> 1

:(scenario refcounts_array)
def main [
  1:number <- copy 30
  # allocate an array
  10:address:array:number <- new number:type, 20
  11:number <- copy 10:address:array:number
  # allocate another array in its place, implicitly freeing the previous allocation
  10:address:array:number <- new number:type, 25
]
+run: {10: ("address" "array" "number")} <- new {number: "type"}, {20: "literal"}
# abandoned array is of old size (20, not 25)
+abandon: saving in free-list of size 22

//:: abandon and reclaim memory when refcount drops to 0

:(scenario new_reclaim)
def main [
  1:address:number <- new number:type
  2:number <- copy 1:address:number  # because 1 will get reset during abandon below
  1:address:number <- copy 0  # abandon
  3:address:number <- new number:type  # must be same size as abandoned memory to reuse
  4:boolean <- equal 2:number, 3:address:number
]
# both allocations should have returned the same address
+mem: storing 1 in location 4

//: When abandoning addresses we'll save them to a 'free list', segregated by size.

:(before "End routine Fields")
map<int, int> free_list;

:(code)
void abandon(int address, int size) {
  trace(9999, "abandon") << "saving in free-list of size " << size << end();
//?   Total_free += size;
//?   Num_free++;
//?   cerr << "abandon: " << size << '\n';
  // clear memory
  for (int curr = address; curr < address+size; ++curr)
    put(Memory, curr, 0);
  // append existing free list to address
  put(Memory, address, get_or_insert(Current_routine->free_list, size));
  put(Current_routine->free_list, size, address);
}

:(before "ensure_space(size)" following "case ALLOCATE")
if (get_or_insert(Current_routine->free_list, size)) {
  trace(9999, "abandon") << "picking up space from free-list of size " << size << end();
  int result = get_or_insert(Current_routine->free_list, size);
  trace(9999, "mem") << "new alloc from free list: " << result << end();
  put(Current_routine->free_list, size, get_or_insert(Memory, result));
  for (int curr = result+1; curr < result+size; ++curr) {
    if (get_or_insert(Memory, curr) != 0) {
      raise << maybe(current_recipe_name()) << "memory in free list was not zeroed out: " << curr << '/' << result << "; somebody wrote to us after free!!!\n" << end();
      break;  // always fatal
    }
  }
  if (SIZE(current_instruction().ingredients) > 1)
    put(Memory, result+/*skip refcount*/1, ingredients.at(1).at(0));
  else
    put(Memory, result, 0);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario new_differing_size_no_reclaim)
def main [
  1:address:number <- new number:type
  2:number <- copy 1:address:number
  1:address:number <- copy 0  # abandon
  3:address:array:number <- new number:type, 2  # different size
  4:boolean <- equal 2:number, 3:address:array:number
]
# no reuse
+mem: storing 0 in location 4

:(scenario new_reclaim_array)
def main [
  1:address:array:number <- new number:type, 2
  2:number <- copy 1:address:array:number
  1:address:array:number <- copy 0  # abandon
  3:address:array:number <- new number:type, 2  # same size
  4:boolean <- equal 2:number, 3:address:array:number
]
# reuse
+mem: storing 1 in location 4

//:: helpers for debugging

:(before "End Primitive Recipe Declarations")
_DUMP,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$dump", _DUMP);
:(before "End Primitive Recipe Implementations")
case _DUMP: {
  reagent after_canonize = current_instruction().ingredients.at(0);
  canonize(after_canonize);
  cerr << maybe(current_recipe_name()) << current_instruction().ingredients.at(0).name << ' ' << no_scientific(current_instruction().ingredients.at(0).value) << " => " << no_scientific(after_canonize.value) << " => " << no_scientific(get_or_insert(Memory, after_canonize.value)) << '\n';
  break;
}

//: grab an address, and then dump its value at intervals
//: useful for tracking down memory corruption (writing to an out-of-bounds address)
:(before "End Globals")
int Bar = -1;
:(before "End Primitive Recipe Declarations")
_BAR,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$bar", _BAR);
:(before "End Primitive Recipe Implementations")
case _BAR: {
  if (current_instruction().ingredients.empty()) {
    if (Bar != -1) cerr << Bar << ": " << no_scientific(get_or_insert(Memory, Bar)) << '\n';
    else cerr << '\n';
  }
  else {
    reagent tmp = current_instruction().ingredients.at(0);
    canonize(tmp);
    Bar = tmp.value;
  }
  break;
}

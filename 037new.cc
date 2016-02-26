//: Creating space for new variables at runtime.

//: Mu has two primitives for managing allocations:
//: - 'allocate' reserves a specified amount of space
//: - 'abandon' returns allocated space to be reused by future calls to 'allocate'
//:
//: In practice it's useful to let programs copy addresses anywhere they want,
//: but a prime source of (particularly security) bugs is accessing memory
//: after it's been abandoned. To avoid this, mu programs use a safer
//: primitive called 'new', which adds two features:
//:
//: - it takes a type rather than a size, to save you the trouble of
//: calculating sizes of different variables.
//: - it allocates an extra location where it tracks so-called 'reference
//: counts' or refcounts: the number of address variables in your program that
//: point to this allocation. The initial refcount of an allocation starts out
//: at 1 (the product of the 'new' instruction). When other variables are
//: copied from it the refcount is incremented. When a variable stops pointing
//: at it the refcount is decremented. When the refcount goes to 0 the
//: allocation is automatically abandoned.
//:
//: Mu programs guarantee you'll have no memory corruption bugs as long as you
//: use 'new' and never use 'allocate' or 'abandon'. However, they don't help
//: you at all to remember to abandon memory after you're done with it. To
//: minimize memory use, be sure to reset allocated addresses to 0 when you're
//: done with them.

//: To help you distinguish addresses that point at allocations, 'new' returns
//: type address:shared:___. Think of 'shared' as a generic container that
//: contains one extra field: the refcount. However, lookup operations will
//: transparently drop the 'shared' and access to the refcount. Copying
//: between shared and non-shared addresses is forbidden.
:(before "End Mu Types Initialization")
type_ordinal shared = put(Type_ordinal, "shared", Next_type_ordinal++);
get_or_insert(Type, shared).name = "shared";
:(before "End Drop Address In lookup_memory(x)")
if (x.type->name == "shared") {
  trace(9999, "mem") << "skipping refcount at " << x.value << end();
  x.set_value(x.value+1);  // skip refcount
  drop_from_type(x, "shared");
}
:(before "End Drop Address In canonize_type(r)")
if (r.type->name == "shared") {
  drop_from_type(r, "shared");
}

:(scenarios run)
:(scenario new)
# call new two times with identical arguments; you should get back different results
recipe main [
  1:address:shared:number/raw <- new number:type
  2:address:shared:number/raw <- new number:type
  3:boolean/raw <- equal 1:address:shared:number/raw, 2:address:shared:number/raw
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
  const recipe& caller = get(Recipe, r);
  if (inst.ingredients.empty() || SIZE(inst.ingredients) > 2) {
    raise << maybe(caller.name) << "'new' requires one or two ingredients, but got " << to_string(inst) << '\n' << end();
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
    raise << maybe(caller.name) << "product of 'new' has incorrect type: " << to_string(inst) << '\n' << end();
    break;
  }
  break;
}
:(code)
bool product_of_new_is_valid(const instruction& inst) {
  reagent product = inst.products.at(0);
  canonize_type(product);
  if (!product.type || product.type->value != get(Type_ordinal, "address")) return false;
  drop_from_type(product, "address");
  if (!product.type || product.type->value != get(Type_ordinal, "shared")) return false;
  drop_from_type(product, "shared");
  if (SIZE(inst.ingredients) > 1) {
    // array allocation
    if (!product.type || product.type->value != get(Type_ordinal, "array")) return false;
    drop_from_type(product, "array");
  }
  reagent expected_product("x:"+inst.ingredients.at(0).name);
  // End Post-processing(expected_product) When Checking 'new'
  return types_strictly_match(product, expected_product);
}

//:: translate 'new' to 'allocate' instructions that take a size instead of a type
:(after "Transform.push_back(check_instruction)")  // check_instruction will guard against direct 'allocate' instructions below
Transform.push_back(transform_new_to_allocate);  // idempotent

:(code)
void transform_new_to_allocate(const recipe_ordinal r) {
  trace(9991, "transform") << "--- convert 'new' to 'allocate' for recipe " << get(Recipe, r).name << end();
  for (long long int i = 0; i < SIZE(get(Recipe, r).steps); ++i) {
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
  // include space for refcount
  size++;
  trace(9999, "mem") << "allocating size " << size << end();
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
  if (SIZE(current_instruction().ingredients) > 1) {
    trace(9999, "mem") << "storing " << ingredients.at(1).at(0) << " in location " << result+/*skip refcount*/1 << end();
    put(Memory, result+/*skip refcount*/1, ingredients.at(1).at(0));
  }
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
  raise << "no implementation for 'new'; why wasn't it translated to 'allocate'? Please save a copy of your program and send it to Kartik.\n" << end();
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
recipe main [
  1:address:shared:number <- new number:type
  2:number <- copy *1:address:shared:number
]
+mem: storing 0 in location 2

:(scenario new_error)
% Hide_errors = true;
recipe main [
  1:address:number/raw <- new number:type
]
+error: main: product of 'new' has incorrect type: 1:address:number/raw <- new number:type

:(scenario new_array)
recipe main [
  1:address:shared:array:number/raw <- new number:type, 5
  2:address:shared:number/raw <- new number:type
  3:number/raw <- subtract 2:address:shared:number/raw, 1:address:shared:array:number/raw
]
+run: 1:address:shared:array:number/raw <- new number:type, 5
+mem: array size is 5
# don't forget the extra location for array size, and the second extra location for the refcount
+mem: storing 7 in location 3

:(scenario new_empty_array)
recipe main [
  1:address:shared:array:number/raw <- new number:type, 0
  2:address:shared:number/raw <- new number:type
  3:number/raw <- subtract 2:address:shared:number/raw, 1:address:shared:array:number/raw
]
+run: 1:address:shared:array:number/raw <- new number:type, 0
+mem: array size is 0
# one location for array size, and one for the refcount
+mem: storing 2 in location 3

//: If a routine runs out of its initial allocation, it should allocate more.
:(scenario new_overflow)
% Initial_memory_per_routine = 3;  // barely enough room for point allocation below
recipe main [
  1:address:shared:number/raw <- new number:type
  2:address:shared:point/raw <- new point:type  # not enough room in initial page
]
+new: routine allocated memory from 1000 to 1003
+new: routine allocated memory from 1003 to 1006

//:: A way to return memory, and to reuse reclaimed memory.
//: todo: custodians, etc. Following malloc/free is a temporary hack.

:(scenario new_reclaim)
recipe main [
  1:address:shared:number <- new number:type
  2:address:shared:number <- copy 1:address:shared:number  # because 1 will get reset during abandon below
  abandon 1:address:shared:number  # unsafe
  3:address:shared:number <- new number:type  # must be same size as abandoned memory to reuse
  4:boolean <- equal 2:address:shared:number, 3:address:shared:number
]
# both allocations should have returned the same address
+mem: storing 1 in location 4

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
    raise << maybe(get(Recipe, r).name) << "'abandon' requires one ingredient, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  reagent types = inst.ingredients.at(0);
  canonize_type(types);
  if (!types.type || types.type->value != get(Type_ordinal, "address") || types.type->right->value != get(Type_ordinal, "shared")) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'abandon' should be an address:shared:___, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ABANDON: {
  long long int address = ingredients.at(0).at(0);
  trace(9999, "abandon") << "address to abandon is " << address << end();
  reagent types = current_instruction().ingredients.at(0);
  trace(9999, "abandon") << "value of ingredient is " << types.value << end();
  canonize(types);
  // lookup_memory without drop_one_lookup {
  trace(9999, "abandon") << "value of ingredient after canonization is " << types.value << end();
  long long int address_location = types.value;
  types.set_value(get_or_insert(Memory, types.value)+/*skip refcount*/1);
  drop_from_type(types, "address");
  drop_from_type(types, "shared");
  // }
  abandon(address, size_of(types)+/*refcount*/1);
  // clear the address
  trace(9999, "mem") << "resetting location " << address_location << end();
  put(Memory, address_location, 0);
  break;
}

:(code)
void abandon(long long int address, long long int size) {
  trace(9999, "abandon") << "saving in free-list of size " << size << end();
//?   Total_free += size;
//?   Num_free++;
//?   cerr << "abandon: " << size << '\n';
  // clear memory
  for (long long int curr = address; curr < address+size; ++curr)
    put(Memory, curr, 0);
  // append existing free list to address
  put(Memory, address, get_or_insert(Free_list, size));
  put(Free_list, size, address);
}

:(before "ensure_space(size)" following "case ALLOCATE")
if (get_or_insert(Free_list, size)) {
  trace(9999, "abandon") << "picking up space from free-list of size " << size << end();
  long long int result = get_or_insert(Free_list, size);
  put(Free_list, size, get_or_insert(Memory, result));
  for (long long int curr = result+1; curr < result+size; ++curr) {
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
recipe main [
  1:address:shared:number <- new number:type
  2:address:shared:number <- copy 1:address:shared:number
  abandon 1:address:shared:number
  3:address:shared:array:number <- new number:type, 2  # different size
  4:boolean <- equal 2:address:shared:number, 3:address:shared:array:number
]
# no reuse
+mem: storing 0 in location 4

:(scenario new_reclaim_array)
recipe main [
  1:address:shared:array:number <- new number:type, 2
  2:address:shared:array:number <- copy 1:address:shared:array:number
  abandon 1:address:shared:array:number  # unsafe
  3:address:shared:array:number <- new number:type, 2
  4:boolean <- equal 2:address:shared:array:number, 3:address:shared:array:number
]
# reuse
+mem: storing 1 in location 4

:(scenario reset_on_abandon)
recipe main [
  1:address:shared:number <- new number:type
  abandon 1:address:shared:number
]
# reuse
+run: abandon 1:address:shared:number
+mem: resetting location 1

//:: Manage refcounts when copying addresses.

:(scenario refcounts)
recipe main [
  1:address:shared:number <- copy 1000/unsafe
  2:address:shared:number <- copy 1:address:shared:number
  1:address:shared:number <- copy 0
  2:address:shared:number <- copy 0
]
+run: 1:address:shared:number <- copy 1000/unsafe
+mem: incrementing refcount of 1000: 0 -> 1
+run: 2:address:shared:number <- copy 1:address:shared:number
+mem: incrementing refcount of 1000: 1 -> 2
+run: 1:address:shared:number <- copy 0
+mem: decrementing refcount of 1000: 2 -> 1
+run: 2:address:shared:number <- copy 0
+mem: decrementing refcount of 1000: 1 -> 0
# the /unsafe corrupts memory but fortunately we won't be running any more 'new' in this scenario
+mem: automatically abandoning 1000

:(before "End write_memory(reagent x, long long int base) Special-cases")
if (x.type->value == get(Type_ordinal, "address")
    && x.type->right
    && x.type->right->value == get(Type_ordinal, "shared")) {
  // compute old address of x, as well as new address we want to write in
  long long int old_address = get_or_insert(Memory, x.value);
  assert(scalar(data));
  long long int new_address = data.at(0);
  // decrement refcount of old address
  if (old_address) {
    long long int old_refcount = get_or_insert(Memory, old_address);
    trace(9999, "mem") << "decrementing refcount of " << old_address << ": " << old_refcount << " -> " << (old_refcount-1) << end();
    put(Memory, old_address, old_refcount-1);
  }
  // perform the write
  trace(9999, "mem") << "storing " << no_scientific(data.at(0)) << " in location " << base << end();
  put(Memory, base, new_address);
  // increment refcount of new address
  if (new_address) {
    long long int new_refcount = get_or_insert(Memory, new_address);
    assert(new_refcount >= 0);  // == 0 only when new_address == old_address
    trace(9999, "mem") << "incrementing refcount of " << new_address << ": " << new_refcount << " -> " << (new_refcount+1) << end();
    put(Memory, new_address, new_refcount+1);
  }
  // abandon old address if necessary
  // do this after all refcount updates are done just in case old and new are identical
  assert(get_or_insert(Memory, old_address) >= 0);
  if (old_address && get_or_insert(Memory, old_address) == 0) {
    // lookup_memory without drop_one_lookup {
    trace(9999, "mem") << "automatically abandoning " << old_address << end();
    trace(9999, "mem") << "computing size to abandon at " << x.value << end();
    x.set_value(get_or_insert(Memory, x.value)+/*skip refcount*/1);
    drop_from_type(x, "address");
    drop_from_type(x, "shared");
    // }
    abandon(old_address, size_of(x)+/*refcount*/1);
  }
  return;
}

:(scenario refcounts_2)
recipe main [
  1:address:shared:number <- new number:type
  # over-writing one allocation with another
  1:address:shared:number <- new number:type
  1:address:shared:number <- copy 0
]
+run: 1:address:shared:number <- new number:type
+mem: incrementing refcount of 1000: 0 -> 1
+run: 1:address:shared:number <- new number:type
+mem: automatically abandoning 1000

:(scenario refcounts_3)
recipe main [
  1:address:shared:number <- new number:type
  # passing in addresses to recipes increments refcount
  foo 1:address:shared:number
  1:address:shared:number <- copy 0
]
recipe foo [
  2:address:shared:number <- next-ingredient
  # return does NOT yet decrement refcount; memory must be explicitly managed
  2:address:shared:number <- copy 0
]
+run: 1:address:shared:number <- new number:type
+mem: incrementing refcount of 1000: 0 -> 1
+run: 2:address:shared:number <- next-ingredient
+mem: incrementing refcount of 1000: 1 -> 2
+run: 2:address:shared:number <- copy 0
+mem: decrementing refcount of 1000: 2 -> 1
+run: 1:address:shared:number <- copy 0
+mem: decrementing refcount of 1000: 1 -> 0
+mem: automatically abandoning 1000

:(scenario refcounts_4)
recipe main [
  1:address:shared:number <- new number:type
  # idempotent copies leave refcount unchanged
  1:address:shared:number <- copy 1:address:shared:number
]
+run: 1:address:shared:number <- new number:type
+mem: incrementing refcount of 1000: 0 -> 1
+run: 1:address:shared:number <- copy 1:address:shared:number
+mem: decrementing refcount of 1000: 1 -> 0
+mem: incrementing refcount of 1000: 0 -> 1

:(scenario refcounts_5)
recipe main [
  1:address:shared:number <- new number:type
  # passing in addresses to recipes increments refcount
  foo 1:address:shared:number
  # return does NOT yet decrement refcount; memory must be explicitly managed
  1:address:shared:number <- new number:type
]
recipe foo [
  2:address:shared:number <- next-ingredient
]
+run: 1:address:shared:number <- new number:type
+mem: incrementing refcount of 1000: 0 -> 1
+run: 2:address:shared:number <- next-ingredient
+mem: incrementing refcount of 1000: 1 -> 2
+run: 1:address:shared:number <- new number:type
+mem: decrementing refcount of 1000: 2 -> 1

//:: Extend 'new' to handle a unicode string literal argument.

:(scenario new_string)
recipe main [
  1:address:shared:array:character <- new [abc def]
  2:character <- index *1:address:shared:array:character, 5
]
# number code for 'e'
+mem: storing 101 in location 2

:(scenario new_string_handles_unicode)
recipe main [
  1:address:shared:array:character <- new [a«c]
  2:number <- length *1:address:shared:array:character
  3:character <- index *1:address:shared:array:character, 1
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
  // initialize refcount
  put(Memory, Current_routine->alloc++, 0);
  // store length
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
  1:address:shared:array:character <- new [abc]
  stash [foo:], 1:address:shared:array:character
]
+app: foo: abc

:(before "End print Special-cases(reagent r, data)")
if (is_mu_string(r)) {
  assert(scalar(data));
  return read_mu_string(data.at(0))+' ';
}

:(scenario unicode_string)
recipe main [
  1:address:shared:array:character <- new [♠]
  stash [foo:], 1:address:shared:array:character
]
+app: foo: ♠

:(scenario stash_space_after_string)
recipe main [
  1:address:shared:array:character <- new [abc]
  stash 1:address:shared:array:character, [foo]
]
+app: abc foo

//: Allocate more to routine when initializing a literal string
:(scenario new_string_overflow)
% Initial_memory_per_routine = 2;
recipe main [
  1:address:shared:number/raw <- new number:type
  2:address:shared:array:character/raw <- new [a]  # not enough room in initial page, if you take the array size into account
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
  if (address == 0) return "";
  address++;  // skip refcount
  long long int size = get_or_insert(Memory, address);
  if (size == 0) return "";
  ostringstream tmp;
  for (long long int curr = address+1; curr <= address+size; ++curr) {
    tmp << to_unicode(static_cast<uint32_t>(get_or_insert(Memory, curr)));
  }
  return tmp.str();
}

bool is_mu_type_literal(reagent r) {
  return is_literal(r) && r.type && r.type->name == "type";
}

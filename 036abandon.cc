//: Reclaiming memory when it's no longer used.

void test_new_reclaim() {
  run(
      "def main [\n"
      "  10:&:num <- new number:type\n"
      "  20:num <- deaddress 10:&:num\n"
      "  abandon 10:&:num\n"
      "  30:&:num <- new number:type\n"  // must be same size as abandoned memory to reuse
      "  40:num <- deaddress 30:&:num\n"
      "  50:bool <- equal 20:num, 40:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // both allocations should have returned the same address
      "mem: storing 1 in location 50\n"
  );
}

//: When abandoning addresses we'll save them to a 'free list', segregated by size.

//: Before, suppose variable V contains address A which points to payload P:
//:   location V contains an alloc-id N
//:   location V+1 contains A
//:   location A contains alloc-id N
//:   location A+1 onwards contains P
//: Additionally, suppose the head of the free list is initially F.
//: After abandoning:
//:   location V contains invalid alloc-id -1
//:   location V+1 contains 0
//:   location A contains invalid alloc-id N
//:   location A+1 contains the previous head of free-list F

:(before "End routine Fields")
map<int, int> free_list;

:(before "End Primitive Recipe Declarations")
ABANDON,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "abandon", ABANDON);
:(before "End Primitive Recipe Checks")
case ABANDON: {
  if (!inst.products.empty()) {
    raise << maybe(get(Recipe, r).name) << "'abandon' shouldn't write to any products in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
    if (!is_mu_address(inst.ingredients.at(i)))
      raise << maybe(get(Recipe, r).name) << "ingredients of 'abandon' should be addresses, but ingredient " << i << " is '" << to_string(inst.ingredients.at(i)) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ABANDON: {
  for (int i = 0;  i < SIZE(current_instruction().ingredients);  ++i) {
    reagent/*copy*/ ingredient = current_instruction().ingredients.at(i);
    canonize(ingredient);
    abandon(get_or_insert(Memory, ingredient.value+/*skip alloc id*/1), payload_size(ingredient));
//?     cerr << "clear after abandon: " << ingredient.value << '\n';
    put(Memory, /*alloc id*/ingredient.value, /*invalid*/-1);
    put(Memory, /*address*/ingredient.value+1, 0);
  }
  break;
}

:(code)
void abandon(int address, int payload_size) {
  put(Memory, address, /*invalid alloc-id*/-1);
//?   cerr << "abandon: " << address << '\n';
  // clear rest of payload
  for (int curr = address+1;  curr < address+payload_size;  ++curr)
    put(Memory, curr, 0);
  // append existing free list to address
  trace(Callstack_depth+1, "abandon") << "saving " << address << " in free-list of size " << payload_size << end();
  put(Memory, address+/*skip invalid alloc-id*/1, get_or_insert(Current_routine->free_list, payload_size));
  put(Current_routine->free_list, payload_size, address);
}

int payload_size(reagent/*copy*/ x) {
  x.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  lookup_memory_core(x, /*check_for_null*/false);
  return size_of(x)+/*alloc id*/1;
}

:(after "Allocate Special-cases")
if (get_or_insert(Current_routine->free_list, size)) {
  trace(Callstack_depth+1, "abandon") << "picking up space from free-list of size " << size << end();
  int result = get_or_insert(Current_routine->free_list, size);
  trace(Callstack_depth+1, "mem") << "new alloc from free list: " << result << end();
  put(Current_routine->free_list, size, get_or_insert(Memory, result+/*skip alloc id*/1));
  // clear 'deleted' tag
  put(Memory, result, 0);
  // clear next pointer
  put(Memory, result+/*skip alloc id*/1, 0);
  for (int curr = result;  curr < result+size;  ++curr) {
    if (get_or_insert(Memory, curr) != 0) {
      raise << maybe(current_recipe_name()) << "memory in free list was not zeroed out: " << curr << '/' << result << "; somebody wrote to us after free!!!\n" << end();
      break;  // always fatal
    }
  }
  return result;
}

:(code)
void test_new_differing_size_no_reclaim() {
  run(
      "def main [\n"
      "  1:&:num <- new number:type\n"
      "  2:num <- deaddress 1:&:num\n"
      "  abandon 1:&:num\n"
      "  3:&:@:num <- new number:type, 2\n"  // different size
      "  4:num <- deaddress 3:&:@:num\n"
      "  5:bool <- equal 2:num, 4:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // no reuse
      "mem: storing 0 in location 5\n"
  );
}

void test_new_reclaim_array() {
  run(
      "def main [\n"
      "  10:&:@:num <- new number:type, 2\n"
      "  20:num <- deaddress 10:&:@:num\n"
      "  abandon 10:&:@:num\n"
      "  30:&:@:num <- new number:type, 2\n"  // same size
      "  40:num <- deaddress 30:&:@:num\n"
      "  50:bool <- equal 20:num, 40:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // both calls to new returned identical addresses
      "mem: storing 1 in location 50\n"
  );
}

void test_lookup_of_abandoned_address_raises_error() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:&:num <- new num:type\n"
      "  3:&:num <- copy 1:&:num\n"
      "  abandon 1:&:num\n"
      "  5:num/raw <- copy *3:&:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: address is already abandoned in '5:num/raw <- copy *3:&:num'\n"
  );
}

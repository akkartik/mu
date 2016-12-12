//: Reclaiming memory when it's no longer used.
//: The top of the address layer has the complete life cycle of memory.

:(scenario new_reclaim)
def main [
  1:address:num <- new number:type
  2:num <- copy 1:address:num  # because 1 will get reset during abandon below
  1:address:num <- copy 0  # abandon
  3:address:num <- new number:type  # must be same size as abandoned memory to reuse
  4:num <- copy 3:address:num
  5:bool <- equal 2:num, 4:num
]
# both allocations should have returned the same address
+mem: storing 1 in location 5

:(before "End Decrement Refcount(old_address, payload_type, payload_size)")
if (old_refcount == 0) {
  trace(9999, "mem") << "automatically abandoning " << old_address << end();
  abandon(old_address, payload_type, payload_size);
}

//: When abandoning addresses we'll save them to a 'free list', segregated by size.

:(before "End routine Fields")
map<int, int> free_list;

:(code)
void abandon(int address, const type_tree* payload_type, int payload_size) {
  trace(9999, "abandon") << "updating refcounts inside " << address << ": " << to_string(payload_type) << end();
//?   Total_free += size;
//?   ++Num_free;
//?   cerr << "abandon: " << size << '\n';
  // decrement any contained refcounts
  if (is_mu_array(payload_type)) {
    reagent/*local*/ element;
    element.type = copy_array_element(payload_type);
    int array_length = get_or_insert(Memory, address+/*skip refcount*/1);
    assert(element.type->name != "array");
    int element_size = size_of(element);
    for (int i = 0;  i < array_length;  ++i) {
      element.set_value(address + /*skip refcount and length*/2 + i*element_size);
      decrement_any_refcounts(element);
    }
  }
  else if (is_mu_container(payload_type) || is_mu_exclusive_container(payload_type)) {
    reagent tmp;
    tmp.type = new type_tree(*payload_type);
    tmp.set_value(address + /*skip refcount*/1);
    decrement_any_refcounts(tmp);
  }
  // clear memory
  for (int curr = address;  curr < address+payload_size;  ++curr)
    put(Memory, curr, 0);
  // append existing free list to address
  trace(9999, "abandon") << "saving " << address << " in free-list of size " << payload_size << end();
  put(Memory, address, get_or_insert(Current_routine->free_list, payload_size));
  put(Current_routine->free_list, payload_size, address);
}

:(after "Allocate Special-cases")
if (get_or_insert(Current_routine->free_list, size)) {
  trace(9999, "abandon") << "picking up space from free-list of size " << size << end();
  int result = get_or_insert(Current_routine->free_list, size);
  trace(9999, "mem") << "new alloc from free list: " << result << end();
  put(Current_routine->free_list, size, get_or_insert(Memory, result));
  put(Memory, result, 0);
  for (int curr = result;  curr < result+size;  ++curr) {
    if (get_or_insert(Memory, curr) != 0) {
      raise << maybe(current_recipe_name()) << "memory in free list was not zeroed out: " << curr << '/' << result << "; somebody wrote to us after free!!!\n" << end();
      break;  // always fatal
    }
  }
  return result;
}

:(scenario new_differing_size_no_reclaim)
def main [
  1:address:num <- new number:type
  2:num <- copy 1:address:num
  1:address:num <- copy 0  # abandon
  3:address:array:num <- new number:type, 2  # different size
  4:num <- copy 3:address:array:num
  5:bool <- equal 2:num, 4:num
]
# no reuse
+mem: storing 0 in location 5

:(scenario new_reclaim_array)
def main [
  1:address:array:num <- new number:type, 2
  2:num <- copy 1:address:array:num
  1:address:array:num <- copy 0  # abandon
  3:address:array:num <- new number:type, 2  # same size
  4:num <- copy 3:address:array:num
  5:bool <- equal 2:num, 4:num
]
# both calls to new returned identical addresses
+mem: storing 1 in location 5

:(scenario abandon_on_overwrite)
def main [
  1:address:num <- new number:type
  # over-writing one allocation with another
  1:address:num <- new number:type
  1:address:num <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: automatically abandoning 1000

:(scenario abandon_after_call)
def main [
  1:address:num <- new number:type
  # passing in addresses to recipes increments refcount
  foo 1:address:num
  1:address:num <- copy 0
]
def foo [
  2:address:num <- next-ingredient
  # return does NOT yet decrement refcount; memory must be explicitly managed
  2:address:num <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: foo {1: ("address" "number")}
# leave ambiguous precisely when the next increment happens
+mem: incrementing refcount of 1000: 1 -> 2
+run: {2: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 1 -> 0
+mem: automatically abandoning 1000

:(scenario abandon_on_overwrite_array)
def main [
  1:num <- copy 30
  # allocate an array
  10:address:array:num <- new number:type, 20
  11:num <- copy 10:address:array:num  # doesn't increment refcount
  # allocate another array in its place, implicitly freeing the previous allocation
  10:address:array:num <- new number:type, 25
]
+run: {10: ("address" "array" "number")} <- new {number: "type"}, {25: "literal"}
# abandoned array is of old size (20, not 25)
+abandon: saving 1000 in free-list of size 22

:(scenario refcounts_abandon_address_in_container)
# container containing an address
container foo [
  x:address:num
]
def main [
  1:address:num <- new number:type
  2:address:foo <- new foo:type
  *2:address:foo <- put *2:address:foo, x:offset, 1:address:num
  1:address:num <- copy 0
  2:address:foo <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "foo")} <- new {foo: "type"}
+mem: incrementing refcount of 1002: 0 -> 1
+run: {2: ("address" "foo"), "lookup": ()} <- put {2: ("address" "foo"), "lookup": ()}, {x: "offset"}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {2: ("address" "foo")} <- copy {0: "literal"}
# start abandoning container containing address
+mem: decrementing refcount of 1002: 1 -> 0
# nested abandon
+mem: decrementing refcount of 1000: 1 -> 0
+abandon: saving 1000 in free-list of size 2
# actually abandon the container containing address
+abandon: saving 1002 in free-list of size 2

# todo: move past dilated reagent
:(scenario refcounts_abandon_address_in_array)
def main [
  1:address:num <- new number:type
  2:address:array:address:num <- new {(address number): type}, 3
  *2:address:array:address:num <- put-index *2:address:array:address:num, 1, 1:address:num
  1:address:num <- copy 0
  2:address:array:address:num <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "array" "address" "number"), "lookup": ()} <- put-index {2: ("address" "array" "address" "number"), "lookup": ()}, {1: "literal"}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {2: ("address" "array" "address" "number")} <- copy {0: "literal"}
# nested abandon
+mem: decrementing refcount of 1000: 1 -> 0
+abandon: saving 1000 in free-list of size 2

:(scenario refcounts_abandon_address_in_container_in_array)
# container containing an address
container foo [
  x:address:num
]
def main [
  1:address:num <- new number:type
  2:address:array:foo <- new foo:type, 3
  3:foo <- merge 1:address:num
  *2:address:array:foo <- put-index *2:address:array:foo, 1, 3:foo
  1:address:num <- copy 0
  3:foo <- merge 0
  2:address:array:foo <- copy 0
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {3: "foo"} <- merge {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {2: ("address" "array" "foo"), "lookup": ()} <- put-index {2: ("address" "array" "foo"), "lookup": ()}, {1: "literal"}, {3: "foo"}
+mem: incrementing refcount of 1000: 2 -> 3
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 3 -> 2
+run: {3: "foo"} <- merge {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {2: ("address" "array" "foo")} <- copy {0: "literal"}
# nested abandon
+mem: decrementing refcount of 1000: 1 -> 0
+abandon: saving 1000 in free-list of size 2

:(scenario refcounts_abandon_array_within_container)
container foo [
  x:address:array:num
]
def main [
  1:address:array:num <- new number:type, 3
  2:foo <- merge 1:address:array:num
  1:address:array:num <- copy 0
  2:foo <- copy 0
]
+run: {1: ("address" "array" "number")} <- new {number: "type"}, {3: "literal"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "foo"} <- merge {1: ("address" "array" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {1: ("address" "array" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 2 -> 1
+run: {2: "foo"} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 1 -> 0
+mem: automatically abandoning 1000
# make sure we save it in a free-list of the appropriate size
+abandon: saving 1000 in free-list of size 5

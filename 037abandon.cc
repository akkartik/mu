//: Reclaiming memory when it's no longer used.
//: The top of the address layer has the complete life cycle of memory.

:(scenario new_reclaim)
def main [
  1:address:number <- new number:type
  2:number <- copy 1:address:number  # because 1 will get reset during abandon below
  1:address:number <- copy 0  # abandon
  3:address:number <- new number:type  # must be same size as abandoned memory to reuse
  4:number <- copy 3:address:number
  5:boolean <- equal 2:number, 4:number
]
# both allocations should have returned the same address
+mem: storing 1 in location 5

:(before "End Decrement Reference Count(old_address, payload_type, payload_size)")
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
//?   Num_free++;
//?   cerr << "abandon: " << size << '\n';
  // decrement any contained refcounts
  if (payload_type->name == "array") {
    reagent element;
    element.type = copy_array_element(payload_type);
    int array_length = get_or_insert(Memory, address+/*skip refcount*/1);
    assert(element.type->name != "array");
    if (is_mu_address(element)) {
      for (element.value = address+/*skip refcount*/1+/*skip length*/1; element.value < address+/*skip refcount*/1+/*skip length*/1+array_length; ++element.value)
        update_refcounts(element, 0);
    }
    else if (is_mu_container(element) || is_mu_exclusive_container(element)) {
      int element_size = size_of(element);
      vector<double> zeros;
      zeros.resize(element_size);
      for (int i = 0; i < array_length; ++i) {
        element.value = address + /*skip refcount*/1 + /*skip array length*/1 + i*element_size;
        update_container_refcounts(element, zeros);
      }
    }
  }
  else if (is_mu_container(payload_type) || is_mu_exclusive_container(payload_type)) {
    reagent tmp;
    tmp.value = address + /*skip refcount*/1;
    tmp.type = new type_tree(*payload_type);
    vector<double> zeros;
    zeros.resize(size_of(payload_type));
    update_container_refcounts(tmp, zeros);
  }
  // clear memory
  for (int curr = address; curr < address+payload_size; ++curr)
    put(Memory, curr, 0);
  // append existing free list to address
  trace(9999, "abandon") << "saving " << address << " in free-list of size " << payload_size << end();
  put(Memory, address, get_or_insert(Current_routine->free_list, payload_size));
  put(Current_routine->free_list, payload_size, address);
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
  4:number <- copy 3:address:array:number
  5:boolean <- equal 2:number, 4:number
]
# no reuse
+mem: storing 0 in location 5

:(scenario new_reclaim_array)
def main [
  1:address:array:number <- new number:type, 2
  2:number <- copy 1:address:array:number
  1:address:array:number <- copy 0  # abandon
  3:address:array:number <- new number:type, 2  # same size
  4:number <- copy 3:address:array:number
  5:boolean <- equal 2:number, 4:number
]
# both calls to new returned identical addresses
+mem: storing 1 in location 5

:(scenario abandon_on_overwrite)
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

:(scenario abandon_after_call)
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

:(scenario abandon_on_overwrite_array)
def main [
  1:number <- copy 30
  # allocate an array
  10:address:array:number <- new number:type, 20
  11:number <- copy 10:address:array:number  # doesn't increment refcount
  # allocate another array in its place, implicitly freeing the previous allocation
  10:address:array:number <- new number:type, 25
]
+run: {10: ("address" "array" "number")} <- new {number: "type"}, {25: "literal"}
# abandoned array is of old size (20, not 25)
+abandon: saving 1000 in free-list of size 22

:(scenario refcounts_abandon_address_in_container)
# container containing an address
container foo [
  x:address:number
]
def main [
  1:address:number <- new number:type
  2:address:foo <- new foo:type
  *2:address:foo <- put *2:address:foo, x:offset, 1:address:number
  1:address:number <- copy 0
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
  1:address:number <- new number:type
  2:address:array:address:number <- new {(address number): type}, 3
  *2:address:array:address:number <- put-index *2:address:array:address:number, 1, 1:address:number
  1:address:number <- copy 0
  2:address:array:address:number <- copy 0
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
  x:address:number
]
def main [
  1:address:number <- new number:type
  2:address:array:foo <- new foo:type, 3
  3:foo <- merge 1:address:number
  *2:address:array:foo <- put-index *2:address:array:foo, 1, 3:foo
  1:address:number <- copy 0
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

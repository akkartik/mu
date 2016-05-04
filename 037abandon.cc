//: Reclaiming memory when it's no longer used.
//: The top of layer 34 has the complete life cycle of memory.

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

:(before "End Decrement Reference Count(old_address, size)")
if (old_refcount == 0) {
  trace(9999, "mem") << "automatically abandoning " << old_address << end();
  abandon(old_address, size);
}

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

:(scenario refcounts_overwrite)
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

:(scenario refcounts_call_2)
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

:(scenario refcounts_array)
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
+abandon: saving in free-list of size 22

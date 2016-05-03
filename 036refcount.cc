//: Update refcounts when copying addresses.
//: The top of layer 34 has more on refcounts.

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
  // End Update Reference Count
  return;
}

:(scenario refcounts_reflexive)
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

:(scenario refcounts_call)
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

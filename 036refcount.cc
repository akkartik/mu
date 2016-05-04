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
if (is_mu_address(x)) {
  // compute old address of x, as well as new address we want to write in
  assert(scalar(data));
  assert(x.value);
  update_refcounts(get_or_insert(Memory, x.value), data.at(0), payload_size(x));
}
:(code)
// variant of write_memory for addresses
void update_refcounts(int old_address, int new_address, int size) {
  if (old_address == new_address) {
    trace(9999, "mem") << "copying address to itself; refcount unchanged" << end();
    return;
  }
  // decrement refcount of old address
  assert(old_address >= 0);
  if (old_address) {
    int old_refcount = get_or_insert(Memory, old_address);
    trace(9999, "mem") << "decrementing refcount of " << old_address << ": " << old_refcount << " -> " << (old_refcount-1) << end();
    --old_refcount;
    put(Memory, old_address, old_refcount);
    if (old_refcount < 0) {
      tb_shutdown();
      DUMP("");
      cerr << "Negative refcount: " << old_address << ' ' << old_refcount << '\n';
      exit(0);
    }
    // End Decrement Reference Count(old_address, size)
  }
  // increment refcount of new address
  if (new_address) {
    int new_refcount = get_or_insert(Memory, new_address);
    assert(new_refcount >= 0);  // == 0 only when new_address == old_address
    trace(9999, "mem") << "incrementing refcount of " << new_address << ": " << new_refcount << " -> " << (new_refcount+1) << end();
    put(Memory, new_address, new_refcount+1);
  }
}

int payload_size(/*copy*/ reagent x) {
  // lookup_memory without drop_one_lookup
  if (x.value)
    x.set_value(get_or_insert(Memory, x.value)+/*skip refcount*/1);
  drop_from_type(x, "address");
  return size_of(x)+/*refcount*/1;
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
+mem: copying address to itself; refcount unchanged

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

//: fix up any instructions that don't follow the usual flow of read_memory
//: before the RUN switch, and write_memory after

:(scenario refcounts_put)
container foo [
  x:address:number
]
def main [
  1:address:number <- new number:type
  2:address:foo <- new foo:type
  *2:address:foo <- put *2:address:foo, x:offset, 1:address:number
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "foo")} <- new {foo: "type"}
+mem: incrementing refcount of 1002: 0 -> 1
+run: {2: ("address" "foo"), "lookup": ()} <- put {2: ("address" "foo"), "lookup": ()}, {x: "offset"}, {1: ("address" "number")}
# put increments refcount
+mem: incrementing refcount of 1000: 1 -> 2

:(after "Write Memory in PUT in Run")
reagent element = element_type(base.type, offset);
assert(!has_property(element, "lookup"));
element.value = address;
if (is_mu_address(element))
  update_refcounts(get_or_insert(Memory, element.value), ingredients.at(2).at(0), payload_size(element));

:(scenario refcounts_put_index)
def main [
  1:address:number <- new number:type
  # fake array because we can't yet create an array of addresses (wait for the
  # support for dilated reagents and parsing more complex type trees)
  1003:number/raw <- copy 3  # skip refcount at 1002
  2:address:array:address:number <- copy 1002/unsafe
  *2:address:array:address:number <- put-index *2:address:array:address:number, 0, 1:address:number
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "array" "address" "number")} <- copy {1002: "literal", "unsafe": ()}
+mem: incrementing refcount of 1002: 0 -> 1
+run: {2: ("address" "array" "address" "number"), "lookup": ()} <- put-index {2: ("address" "array" "address" "number"), "lookup": ()}, {0: "literal"}, {1: ("address" "number")}
# put-index increments refcount
+mem: incrementing refcount of 1000: 1 -> 2

:(after "Write Memory in PUT_INDEX in Run")
if (is_mu_address(element))
  update_refcounts(get_or_insert(Memory, element.value), value.at(0), payload_size(element));

:(scenario refcounts_maybe_convert)
exclusive-container foo [
  x:number
  p:address:number
]
def main [
  1:address:number <- new number:type
  2:foo <- merge 1/p, 1:address:number
  4:address:number, 5:boolean <- maybe-convert 2:foo, p:variant
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "foo"} <- merge {1: "literal", "p": ()}, {1: ("address" "number")}
+run: {4: ("address" "number")}, {5: "boolean"} <- maybe-convert {2: "foo"}, {p: "variant"}
# maybe-convert increments refcount on success
+mem: incrementing refcount of 1000: 1 -> 2

:(after "Write Memory in Successful MAYBE_CONVERT")
if (is_mu_address(product))
  update_refcounts(get_or_insert(Memory, product.value), get_or_insert(Memory, base_address+/*skip tag*/1), payload_size(product));

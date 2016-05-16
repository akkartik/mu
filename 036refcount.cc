//: Update refcounts when copying addresses.
//: The top of the address layer has more on refcounts.

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

:(before "End write_memory(x) Special-cases")
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

int payload_size(reagent/*copy*/ x) {
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
reagent/*copy*/ element = element_type(base.type, offset);
assert(!has_property(element, "lookup"));
element.value = address;
if (is_mu_address(element))
  update_refcounts(get_or_insert(Memory, element.value), ingredients.at(2).at(0), payload_size(element));
// End Update Refcounts in PUT

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
// End Update Refcounts in PUT_INDEX

:(scenario refcounts_maybe_convert)
exclusive-container foo [
  x:number
  p:address:number
]
def main [
  1:address:number <- new number:type
  2:foo <- merge 1/p, 1:address:number
  4:address:number, 5:boolean <- maybe-convert 2:foo, 1:variant/p
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
# merging in an address increments refcount
+run: {2: "foo"} <- merge {1: "literal", "p": ()}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {4: ("address" "number")}, {5: "boolean"} <- maybe-convert {2: "foo"}, {1: "variant", "p": ()}
# maybe-convert increments refcount on success
+mem: incrementing refcount of 1000: 2 -> 3

:(after "Write Memory in Successful MAYBE_CONVERT")
if (is_mu_address(product))
  update_refcounts(get_or_insert(Memory, product.value), get_or_insert(Memory, base_address+/*skip tag*/1), payload_size(product));
// End Update Refcounts in Successful MAYBE_CONVERT

//:: manage refcounts in instructions that copy multiple locations at a time

:(scenario refcounts_copy_nested)
container foo [
  x:address:number  # address inside container
]
def main [
  1:address:number <- new number:type
  2:address:foo <- new foo:type
  *2:address:foo <- put *2:address:foo, x:offset, 1:address:number
  3:foo <- copy *2:address:foo
]
+transform: compute address offsets for container foo
+transform: checking container foo, element 0
+transform: address at offset 0
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "foo"), "lookup": ()} <- put {2: ("address" "foo"), "lookup": ()}, {x: "offset"}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
# copying a container increments refcounts of any contained addresses
+run: {3: "foo"} <- copy {2: ("address" "foo"), "lookup": ()}
+mem: incrementing refcount of 1000: 2 -> 3

:(after "Types")
struct address_element_info {
  int offset;  // where inside a container type (after flattening nested containers!) the address lies
  int payload_size;  // size of type it points to
  address_element_info(int o, int p) {
    offset = o;
    payload_size = p;
  }
};
:(before "struct container_metadata ")
// valid fields for containers: size, offset, address, maybe_address (if container directly or indirectly contains exclusive containers with addresses)
// valid fields for exclusive containers: size, maybe_address
:(before "End container_metadata Fields")
vector<address_element_info> address;  // list of offsets containing addresses, and the sizes of their corresponding payloads
map<pair</*offset*/int, /*tag*/int>, vector<address_element_info> > maybe_address;

//: populate metadata.address in a separate transform, because it requires
//: already knowing the sizes of all types

:(after "Transform.push_back(compute_container_sizes)")
Transform.push_back(compute_container_address_offsets);
:(code)
void compute_container_address_offsets(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9992, "transform") << "--- compute address offsets for " << caller.name << end();
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
    trace(9993, "transform") << "- compute address offsets for " << to_string(inst) << end();
    for (int i = 0; i < SIZE(inst.ingredients); ++i)
      compute_container_address_offsets(inst.ingredients.at(i));
    for (int i = 0; i < SIZE(inst.products); ++i)
      compute_container_address_offsets(inst.products.at(i));
  }
}
void compute_container_address_offsets(reagent& r) {
  if (is_literal(r) || is_dummy(r)) return;
  compute_container_address_offsets(r.type);
  if (contains_key(Container_metadata, r.type))
    r.metadata = get(Container_metadata, r.type);
}
void compute_container_address_offsets(type_tree* type) {
  if (!type) return;
  if (type->left) compute_container_address_offsets(type->left);
  if (type->right) compute_container_address_offsets(type->right);
  if (!contains_key(Type, type->value)) return;  // error raised elsewhere
  type_info& info = get(Type, type->value);
  if (info.kind == CONTAINER) {
    container_metadata& metadata = get(Container_metadata, type);
    if (!metadata.address.empty()) return;
    trace(9994, "transform") << "compute address offsets for container " << info.name << end();
    if (!append_addresses(0, type, metadata.address, metadata))
      return;  // error
  }
  if (info.kind == EXCLUSIVE_CONTAINER) {
    container_metadata& metadata = get(Container_metadata, type);
    if (!metadata.maybe_address.empty()) return;
    trace(9994, "transform") << "compute address offsets for exclusive container " << info.name << end();
    for (int tag = 0; tag < SIZE(info.elements); ++tag) {
      if (!append_addresses(/*skip tag offset*/1, variant_type(type, tag).type, get_or_insert(metadata.maybe_address, pair<int, int>(/*tag offset*/0, tag)), metadata))
        return;  // error
    }
  }
}

// returns false on error (raised elsewhere)
//: error status is used in later layers
bool append_addresses(int base_offset, const type_tree* type, vector<address_element_info>& out, container_metadata& out_metadata) {
  const type_info& info = get(Type, type->value);
  if (type->name == "address") {
    out.push_back(address_element_info(base_offset, payload_size(type)));
    return true;
  }
  if (info.kind == PRIMITIVE) return true;
  for (int curr_index = 0, curr_offset = base_offset; curr_index < SIZE(info.elements); ++curr_index) {
    trace(9993, "transform") << "checking container " << type->name << ", element " << curr_index << end();
    reagent/*copy*/ element = element_type(type, curr_index);
    // Compute Container Address Offset(element)
    if (is_mu_address(element)) {
      trace(9993, "transform") << "address at offset " << curr_offset << end();
      out.push_back(address_element_info(curr_offset, payload_size(element)));
      ++curr_offset;
    }
    else if (is_mu_container(element)) {
      if (!append_addresses(curr_offset, element.type, out, out_metadata))
        return false;  // error
      curr_offset += size_of(element);
    }
    else if (is_mu_exclusive_container(element)) {
      const type_info& element_info = get(Type, element.type->value);
      for (int tag = 0; tag < SIZE(element_info.elements); ++tag) {
        vector<address_element_info>& tmp = get_or_insert(out_metadata.maybe_address, pair<int, int>(curr_offset, tag));
        if (tmp.empty()) {
          if (!append_addresses(curr_offset+1, variant_type(element.type, tag).type, tmp, out_metadata))
            return false;  // error
        }
      }
      curr_offset += size_of(element);
    }
    else {
      // non-address primitive
      ++curr_offset;
    }
  }
  return true;
}

int payload_size(const type_tree* type) {
  assert(type->name == "address");
  return size_of(type->right)+/*refcount*/1;
}

//: use metadata.address to update refcounts within containers, arrays and
//: exclusive containers

:(before "End write_memory(x) Special-cases")
if (is_mu_container(x) || is_mu_exclusive_container(x))
  update_container_refcounts(x, data);
:(before "End Update Refcounts in PUT")
if (is_mu_container(element) || is_mu_exclusive_container(element))
  update_container_refcounts(element, ingredients.at(2));
:(before "End Update Refcounts in PUT_INDEX")
if (is_mu_container(element) || is_mu_exclusive_container(element))
  update_container_refcounts(element, value);
:(before "End Update Refcounts in Successful MAYBE_CONVERT")
if (is_mu_container(product) || is_mu_exclusive_container(product)) {
  vector<double> data;
  for (int i = 0; i < size_of(product); ++i)
    data.push_back(get_or_insert(Memory, base_address+/*skip tag*/1+i));
  update_container_refcounts(product, data);
}

:(code)
void update_container_refcounts(const reagent& x, const vector<double>& data) {
  assert(is_mu_container(x) || is_mu_exclusive_container(x));
  const container_metadata& metadata = get(Container_metadata, x.type);
  for (int i = 0; i < SIZE(metadata.address); ++i) {
    const address_element_info& info = metadata.address.at(i);
    update_refcounts(get_or_insert(Memory, x.value + info.offset), data.at(info.offset), info.payload_size);
  }
  for (map<pair<int, int>, vector<address_element_info> >::const_iterator p = metadata.maybe_address.begin(); p != metadata.maybe_address.end(); ++p) {
    if (data.at(p->first.first) != p->first.second) continue;
    for (int i = 0; i < SIZE(p->second); ++i) {
      const address_element_info& info = p->second.at(i);
      update_refcounts(get_or_insert(Memory, x.value + info.offset), data.at(info.offset), info.payload_size);
    }
  }
}

:(scenario refcounts_put_container)
container foo [
  a:bar  # contains an address
]
container bar [
  x:address:number
]
def main [
  1:address:number <- new number:type
  2:bar <- merge 1:address:number
  3:address:foo <- new foo:type
  *3:address:foo <- put *3:address:foo, a:offset, 2:bar
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "bar"} <- merge {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {3: ("address" "foo"), "lookup": ()} <- put {3: ("address" "foo"), "lookup": ()}, {a: "offset"}, {2: "bar"}
# put increments refcount inside container
+mem: incrementing refcount of 1000: 2 -> 3

:(scenario refcounts_put_index_container)
container bar [
  x:address:number
]
def main [
  1:address:number <- new number:type
  2:bar <- merge 1:address:number
  3:address:array:bar <- new bar:type, 3
  *3:address:array:bar <- put-index *3:address:array:bar, 0, 2:bar
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "bar"} <- merge {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {3: ("address" "array" "bar"), "lookup": ()} <- put-index {3: ("address" "array" "bar"), "lookup": ()}, {0: "literal"}, {2: "bar"}
# put-index increments refcount inside container
+mem: incrementing refcount of 1000: 2 -> 3

:(scenario refcounts_maybe_convert_container)
exclusive-container foo [
  a:number
  b:bar  # contains an address
]
container bar [
  x:address:number
]
def main [
  1:address:number <- new number:type
  2:bar <- merge 1:address:number
  3:foo <- merge 1/b, 2:bar
  5:bar, 6:boolean <- maybe-convert 3:foo, 1:variant/b
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "bar"} <- merge {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {3: "foo"} <- merge {1: "literal", "b": ()}, {2: "bar"}
+mem: incrementing refcount of 1000: 2 -> 3
+run: {5: "bar"}, {6: "boolean"} <- maybe-convert {3: "foo"}, {1: "variant", "b": ()}
+mem: incrementing refcount of 1000: 3 -> 4

:(scenario refcounts_copy_doubly_nested)
container foo [
  a:bar  # no addresses
  b:curr  # contains addresses
]
container bar [
  x:number
  y:number
]
container curr [
  x:number
  y:address:number  # address inside container inside container
]
def main [
  1:address:number <- new number:type
  2:address:curr <- new curr:type
  *2:address:curr <- put *2:address:curr, 1:offset/y, 1:address:number
  3:address:foo <- new foo:type
  *3:address:foo <- put *3:address:foo, 1:offset/b, *2:address:curr
  4:foo <- copy *3:address:foo
]
+transform: compute address offsets for container foo
+transform: checking container foo, element 1
+transform: address at offset 3
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
# storing an address in a container updates its refcount
+run: {2: ("address" "curr"), "lookup": ()} <- put {2: ("address" "curr"), "lookup": ()}, {1: "offset", "y": ()}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
# storing a container in a container updates refcounts of any contained addresses
+run: {3: ("address" "foo"), "lookup": ()} <- put {3: ("address" "foo"), "lookup": ()}, {1: "offset", "b": ()}, {2: ("address" "curr"), "lookup": ()}
+mem: incrementing refcount of 1000: 2 -> 3
# copying a container containing a container containing an address updates refcount
+run: {4: "foo"} <- copy {3: ("address" "foo"), "lookup": ()}
+mem: incrementing refcount of 1000: 3 -> 4

:(scenario refcounts_copy_exclusive_container_within_container)
container foo [
  a:number
  b:bar
]
exclusive-container bar [
  x:number
  y:number
  z:address:number
]
def main [
  1:address:number <- new number:type
  2:bar <- merge 0/x, 34
  3:foo <- merge 12, 2:bar
  5:bar <- merge 1/y, 35
  6:foo <- merge 13, 5:bar
  8:bar <- merge 2/z, 1:address:number
  9:foo <- merge 14, 8:bar
  11:foo <- copy 9:foo
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
# no change while merging items of other types
+run: {8: "bar"} <- merge {2: "literal", "z": ()}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {9: "foo"} <- merge {14: "literal"}, {8: "bar"}
+mem: incrementing refcount of 1000: 2 -> 3
+run: {11: "foo"} <- copy {9: "foo"}
+mem: incrementing refcount of 1000: 3 -> 4

:(scenario refcounts_copy_container_within_exclusive_container)
exclusive-container foo [
  a:number
  b:bar
]
container bar [
  x:number
  y:number
  z:address:number
]
def main [
  1:address:number <- new number:type
  2:foo <- merge 0/a, 34
  6:foo <- merge 0/a, 35
  10:bar <- merge 2/x, 15/y, 1:address:number
  13:foo <- merge 1/b, 10:bar
  17:foo <- copy 13:foo
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
# no change while merging items of other types
+run: {10: "bar"} <- merge {2: "literal", "x": ()}, {15: "literal", "y": ()}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {13: "foo"} <- merge {1: "literal", "b": ()}, {10: "bar"}
+mem: incrementing refcount of 1000: 2 -> 3
+run: {17: "foo"} <- copy {13: "foo"}
+mem: incrementing refcount of 1000: 3 -> 4

:(code)
bool is_mu_container(const reagent& r) {
  if (r.type->value == 0) return false;
  type_info& info = get(Type, r.type->value);
  return info.kind == CONTAINER;
}

bool is_mu_exclusive_container(const reagent& r) {
  if (r.type->value == 0) return false;
  type_info& info = get(Type, r.type->value);
  return info.kind == EXCLUSIVE_CONTAINER;
}

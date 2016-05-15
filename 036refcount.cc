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
+run: {2: "foo"} <- merge {1: "literal", "p": ()}, {1: ("address" "number")}
+run: {4: ("address" "number")}, {5: "boolean"} <- maybe-convert {2: "foo"}, {1: "variant", "p": ()}
# maybe-convert increments refcount on success
+mem: incrementing refcount of 1000: 1 -> 2

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
+transform: --- compute address offsets for foo
+transform: checking container foo, element 0
+transform: container foo contains an address at offset 0
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
:(before "End container_metadata Fields")
vector<address_element_info> address;  // list of offsets containing addresses, and the sizes of their corresponding payloads

//: populate metadata.address in a separate transform, because it requires
//: already knowing the sizes of all types

:(after "Transform.push_back(compute_container_sizes)")
Transform.push_back(compute_container_address_offsets);
:(code)
void compute_container_address_offsets(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    instruction& inst = caller.steps.at(i);
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
    trace(9992, "transform") << "--- compute address offsets for " << info.name << end();
    stack<pair<const type_tree*, /*next field to process*/int> > containers;
    containers.push(pair<const type_tree*, int>(new type_tree(*type), 0));
    int curr_offset = 0;
    while (!containers.empty()) {
      const type_tree* curr_type = containers.top().first;
      int curr_index = containers.top().second;
      type_ordinal t = curr_type->value;
      assert(t);
      type_info& curr_info = get(Type, t);
      assert(curr_info.kind == CONTAINER);
      assert(get(Type, curr_type->value).kind == CONTAINER);
      if (curr_index >= SIZE(get(Type, curr_type->value).elements)) {
        delete curr_type;
        containers.pop();
        continue;
      }
      trace(9993, "transform") << "checking container " << curr_type->name << ", element " << curr_index << end();
      reagent/*copy*/ element = element_type(curr_type, curr_index);
      // Compute Container Address Offset(element)
      // base case
      if (is_mu_address(element)) {
        trace(9993, "transform") << "container " << info.name << " contains an address at offset " << curr_offset << end();
        /*top level*/metadata.address.push_back(address_element_info(curr_offset, payload_size(element)));
      }
      // recursive case and update loop variables
      if (is_mu_container(element)) {
        ++containers.top().second;
        containers.push(pair<const type_tree*, int>(new type_tree(*element.type), 0));
      }
      else if (is_mu_exclusive_container(element)) {
        // TODO: stub
        ++containers.top().second;
        ++curr_offset;
      }
      else {
        ++containers.top().second;
        ++curr_offset;
      }
    }
  }
}

//: use metadata.address to update refcounts within containers, arrays and
//: exclusive containers

:(before "End write_memory(x) Special-cases")
if (is_mu_container(x))
  update_container_refcounts(x, data);
:(before "End Update Refcounts in PUT")
if (is_mu_container(element))
  update_container_refcounts(element, ingredients.at(2));
:(before "End Update Refcounts in PUT_INDEX")
if (is_mu_container(element))
  update_container_refcounts(element, value);
:(before "End Update Refcounts in Successful MAYBE_CONVERT")
if (is_mu_container(product)) {
  vector<double> data;
  for (int i = 0; i < size_of(product); ++i)
    data.push_back(get_or_insert(Memory, base_address+/*skip tag*/1+i));
  update_container_refcounts(product, data);
}

:(code)
void update_container_refcounts(const reagent& x, const vector<double>& data) {
  assert(is_mu_container(x));
  const container_metadata& metadata = get(Container_metadata, x.type);
  for (int i = 0; i < SIZE(metadata.address); ++i) {
    const address_element_info& info = metadata.address.at(i);
    update_refcounts(get_or_insert(Memory, x.value + info.offset), data.at(info.offset), info.payload_size);
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
# todo: refcount should increment here as well, but we can't handle exclusive-containers (sometimes) containing addresses yet
+run: {5: "bar"}, {6: "boolean"} <- maybe-convert {3: "foo"}, {1: "variant", "b": ()}
+mem: incrementing refcount of 1000: 2 -> 3

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
+transform: --- compute address offsets for foo
+transform: checking container foo, element 1
+transform: container foo contains an address at offset 3
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

// todo:
//  exclusive container sometimes containing address
//  container containing exclusive container sometimes containing address

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
if (should_update_refcounts_in_write_memory(product_index)) {
  if (is_mu_address(x)) {
    assert(scalar(data));
    assert(x.value);
    assert(!x.metadata.size);
    update_refcounts(x, data.at(0));
  }
  // End Update Refcounts in write_memory(x)
}

:(code)
//: hook for a later layer
bool should_update_refcounts_in_write_memory(int product_index) {
  return true;
}

void update_refcounts(const reagent& old, int new_address) {
  assert(is_mu_address(old));
  update_refcounts(get_or_insert(Memory, old.value), new_address, old.type->right, payload_size(old));
}

void update_refcounts(int old_address, int new_address, const type_tree* payload_type, int /*just in case it's an array*/payload_size) {
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
    // End Decrement Reference Count(old_address, payload_type, payload_size)
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
  x.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  lookup_memory_core(x);
  return size_of(x) + /*refcount*/1;
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
  update_refcounts(element, ingredients.at(2).at(0));
// End Update Refcounts in PUT

:(scenario refcounts_put_index)
def main [
  1:address:number <- new number:type
  2:address:array:address:number <- new {(address number): type}, 3
  *2:address:array:address:number <- put-index *2:address:array:address:number, 0, 1:address:number
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "array" "address" "number")} <- new {(address number): "type"}, {3: "literal"}
+mem: incrementing refcount of 1002: 0 -> 1
+run: {2: ("address" "array" "address" "number"), "lookup": ()} <- put-index {2: ("address" "array" "address" "number"), "lookup": ()}, {0: "literal"}, {1: ("address" "number")}
# put-index increments refcount
+mem: incrementing refcount of 1000: 1 -> 2

:(after "Write Memory in PUT_INDEX in Run")
if (is_mu_address(element))
  update_refcounts(element, value.at(0));
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
  update_refcounts(product, get_or_insert(Memory, base_address+/*skip tag*/1));
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

:(after "End type_tree Definition")
struct address_element_info {
  int offset;  // where inside a container type (after flattening nested containers!) the address lies
  const type_tree* payload_type;  // all the information we need to compute sizes of items inside an address inside a container. Doesn't need to be a full-scale reagent, since an address inside a container can never be an array, and arrays are the only type that need to know their location to compute their size.
  address_element_info(int o, const type_tree* p) {
    offset = o;
    payload_type = p;
  }
  address_element_info(const address_element_info& other) {
    offset = other.offset;
    payload_type = other.payload_type ? new type_tree(*other.payload_type) : NULL;
  }
  ~address_element_info() {
    if (payload_type) {
      delete payload_type;
      payload_type = NULL;
    }
  }
  address_element_info& operator=(const address_element_info& other) {
    offset = other.offset;
    if (payload_type) delete payload_type;
    payload_type = other.payload_type ? new type_tree(*other.payload_type) : NULL;
    return *this;
  }
};

// For exclusive containers we might sometimes have an address at some offset
// if some other offset has a specific tag. This struct encapsulates such
// guards.
struct tag_condition_info {
  int offset;
  int tag;
  tag_condition_info(int o, int t) :offset(o), tag(t) {}
};

:(before "End container_metadata Fields")
// a list of facts of the form:
//
//  IF offset o1 has tag t2 AND offset o2 has tag t2 AND .., THEN
//    for all address_element_infos:
//      you need to update refcounts for the address at offset pointing to a payload of type payload_type (just in case we need to abandon something in the process)
map<set<tag_condition_info>, set<address_element_info> > address;
:(code)
bool operator<(const set<tag_condition_info>& a, const set<tag_condition_info>& b) {
  if (a.size() != b.size()) return a.size() < b.size();
  for (set<tag_condition_info>::const_iterator pa = a.begin(), pb = b.begin();  pa != a.end();  ++pa, ++pb) {
    if (pa->offset != pb->offset) return pa->offset < pb->offset;
    if (pa->tag != pb->tag) return pa->tag < pb->tag;
  }
  return false;  // equal
}
bool operator<(const tag_condition_info& a, const tag_condition_info& b) {
  if (a.offset != b.offset) return a.offset < b.offset;
  if (a.tag != b.tag) return a.tag < b.tag;
  return false;  // equal
}
bool operator<(const set<address_element_info>& a, const set<address_element_info>& b) {
  if (a.size() != b.size()) return a.size() < b.size();
  for (set<address_element_info>::const_iterator pa = a.begin(), pb = b.begin();  pa != a.end();  ++pa, ++pb) {
    if (pa->offset != pb->offset) return pa->offset < pb->offset;
  }
  return false;  // equal
}
bool operator<(const address_element_info& a, const address_element_info& b) {
  if (a.offset != b.offset) return a.offset < b.offset;
  return false;  // equal
}


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
    append_addresses(0, type, metadata.address, set<tag_condition_info>());
  }
  if (info.kind == EXCLUSIVE_CONTAINER) {
    container_metadata& metadata = get(Container_metadata, type);
    trace(9994, "transform") << "compute address offsets for exclusive container " << info.name << end();
    for (int tag = 0; tag < SIZE(info.elements); ++tag) {
      set<tag_condition_info> key;
      key.insert(tag_condition_info(/*tag is at offset*/0, tag));
      append_addresses(/*skip tag offset*/1, variant_type(type, tag).type, metadata.address, key);
    }
  }
}

void append_addresses(int base_offset, const type_tree* type, map<set<tag_condition_info>, set<address_element_info> >& out, const set<tag_condition_info>& key) {
  const type_info& info = get(Type, type->value);
  if (type->name == "address") {
    assert(type->right && type->right->name != "array");  // array types can't be handled without a full reagent and its value
    get_or_insert(out, key).insert(address_element_info(base_offset, new type_tree(*type->right)));
    return;
  }
  if (info.kind == CONTAINER) {
    for (int curr_index = 0, curr_offset = base_offset; curr_index < SIZE(info.elements); ++curr_index) {
      trace(9993, "transform") << "checking container " << type->name << ", element " << curr_index << end();
      reagent/*copy*/ element = element_type(type, curr_index);
      // Compute Container Address Offset(element)
      if (is_mu_address(element)) {
        trace(9993, "transform") << "address at offset " << curr_offset << end();
        get_or_insert(out, key).insert(address_element_info(curr_offset, new type_tree(*element.type->right)));
        ++curr_offset;
      }
      else if (is_mu_container(element)) {
        append_addresses(curr_offset, element.type, out, key);
        curr_offset += size_of(element);
      }
      else if (is_mu_exclusive_container(element)) {
        const type_info& element_info = get(Type, element.type->value);
        for (int tag = 0; tag < SIZE(element_info.elements); ++tag) {
          set<tag_condition_info> new_key = key;
          new_key.insert(tag_condition_info(curr_offset, tag));
          if (!contains_key(out, new_key))
            append_addresses(curr_offset+/*skip tag*/1, variant_type(element.type, tag).type, out, new_key);
        }
        curr_offset += size_of(element);
      }
      else {
        // non-address primitive
        ++curr_offset;
      }
    }
  }
  else if (info.kind == EXCLUSIVE_CONTAINER) {
    for (int tag = 0; tag < SIZE(info.elements); ++tag) {
      set<tag_condition_info> new_key = key;
      new_key.insert(tag_condition_info(base_offset, tag));
      if (!contains_key(out, new_key))
        append_addresses(base_offset+/*skip tag*/1, variant_type(type, tag).type, out, new_key);
    }
  }
}

int payload_size(const type_tree* type) {
  assert(type->name == "address");
  assert(type->right->name != "array");
  return size_of(type->right) + /*refcount*/1;
}

//: use metadata.address to update refcounts within containers, arrays and
//: exclusive containers

:(before "End Update Refcounts in write_memory(x)")
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
  for (map<set<tag_condition_info>, set<address_element_info> >::const_iterator p = metadata.address.begin(); p != metadata.address.end(); ++p) {
    if (!all_match(data, p->first)) continue;
    for (set<address_element_info>::const_iterator info = p->second.begin(); info != p->second.end(); ++info)
      update_refcounts(get_or_insert(Memory, x.value + info->offset), data.at(info->offset), info->payload_type, size_of(info->payload_type)+/*refcount*/1);
  }
}

bool all_match(const vector<double>& data, const set<tag_condition_info>& conditions) {
  for (set<tag_condition_info>::const_iterator p = conditions.begin(); p != conditions.end(); ++p) {
    if (data.at(p->offset) != p->tag)
      return false;
  }
  return true;
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

:(scenario refcounts_copy_exclusive_container_within_exclusive_container)
exclusive-container foo [
  a:number
  b:bar
]
exclusive-container bar [
  x:number
  y:address:number
]
def main [
  1:address:number <- new number:type
  10:foo <- merge 1/b, 1/y, 1:address:number
  20:foo <- copy 10:foo
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
# no change while merging items of other types
+run: {10: "foo"} <- merge {1: "literal", "b": ()}, {1: "literal", "y": ()}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {20: "foo"} <- copy {10: "foo"}
+mem: incrementing refcount of 1000: 2 -> 3

:(code)
bool is_mu_container(const reagent& r) {
  return is_mu_container(r.type);
}
bool is_mu_container(const type_tree* type) {
  if (type->value == 0) return false;
  type_info& info = get(Type, type->value);
  return info.kind == CONTAINER;
}

bool is_mu_exclusive_container(const reagent& r) {
  return is_mu_exclusive_container(r.type);
}
bool is_mu_exclusive_container(const type_tree* type) {
  if (type->value == 0) return false;
  type_info& info = get(Type, type->value);
  return info.kind == EXCLUSIVE_CONTAINER;
}

//: Update refcounts when copying addresses.
//: The top of the address layer has more on refcounts.

:(scenario refcounts)
def main [
  1:address:num <- copy 1000/unsafe
  2:address:num <- copy 1:address:num
  1:address:num <- copy 0
  2:address:num <- copy 0
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
update_any_refcounts(x, data);

:(before "End Globals")
bool Reclaim_memory = true;
:(before "End Commandline Options(*arg)")
else if (is_equal(*arg, "--no-reclaim")) {
  cerr << "Disabling memory reclamation. Some tests will fail.\n";
  Reclaim_memory = false;
}
:(code)
void update_any_refcounts(const reagent& canonized_x, const vector<double>& data) {
  if (!Reclaim_memory) return;
  if (!should_update_refcounts()) return;
  increment_any_refcounts(canonized_x, data);  // increment first so we don't reclaim on x <- copy x
  decrement_any_refcounts(canonized_x);
}

//: escape hatch for a later layer
bool should_update_refcounts() {
  // End should_update_refcounts() Special-cases
  return true;
}

void increment_any_refcounts(const reagent& canonized_x, const vector<double>& data) {
  if (is_mu_address(canonized_x)) {
    assert(scalar(data));
    assert(!canonized_x.metadata.size);
    increment_refcount(data.at(0));
  }
  // End Increment Refcounts(canonized_x)
}

void increment_refcount(int new_address) {
  assert(new_address >= 0);
  if (new_address == 0) return;
  ++Total_refcount_updates;
  int new_refcount = get_or_insert(Memory, new_address);
  trace(9999, "mem") << "incrementing refcount of " << new_address << ": " << new_refcount << " -> " << new_refcount+1 << end();
  put(Memory, new_address, new_refcount+1);
}

void decrement_any_refcounts(const reagent& canonized_x) {
  if (is_mu_address(canonized_x)) {
    assert(canonized_x.value);
    assert(!canonized_x.metadata.size);
    decrement_refcount(get_or_insert(Memory, canonized_x.value), payload_type(canonized_x.type), payload_size(canonized_x));
  }
  // End Decrement Refcounts(canonized_x)
}

void decrement_refcount(int old_address, const type_tree* payload_type, int payload_size) {
  assert(old_address >= 0);
  if (old_address == 0) return;
  ++Total_refcount_updates;
  int old_refcount = get_or_insert(Memory, old_address);
  trace(9999, "mem") << "decrementing refcount of " << old_address << ": " << old_refcount << " -> " << old_refcount-1 << end();
  --old_refcount;
  put(Memory, old_address, old_refcount);
  if (old_refcount < 0) {
    cerr << "Negative refcount!!! " << old_address << ' ' << old_refcount << '\n';
    if (Trace_stream) {
      cerr << "Saving trace to last_trace.\n";
      ofstream fout("last_trace");
      fout << Trace_stream->readable_contents("");
      fout.close();
    }
    exit(1);
  }
  // End Decrement Refcount(old_address, payload_type, payload_size)
}

int payload_size(reagent/*copy*/ x) {
  x.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  lookup_memory_core(x, /*check for nulls*/false);
  return size_of(x) + /*refcount*/1;
}

:(scenario refcounts_reflexive)
def main [
  1:address:num <- new number:type
  # idempotent copies leave refcount unchanged
  1:address:num <- copy 1:address:num
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {1: ("address" "number")} <- copy {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+mem: decrementing refcount of 1000: 2 -> 1

:(scenario refcounts_call)
def main [
  1:address:num <- new number:type
  # passing in addresses to recipes increments refcount
  foo 1:address:num
  # return does NOT yet decrement refcount; memory must be explicitly managed
  1:address:num <- new number:type
]
def foo [
  2:address:num <- next-ingredient
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: foo {1: ("address" "number")}
# leave ambiguous precisely when the next increment happens
+mem: incrementing refcount of 1000: 1 -> 2
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: decrementing refcount of 1000: 2 -> 1

//: fix up any instructions that don't follow the usual flow of read_memory
//: before the RUN switch, and write_memory after

:(scenario refcounts_put)
container foo [
  x:address:num
]
def main [
  1:address:num <- new number:type
  2:address:foo <- new foo:type
  *2:address:foo <- put *2:address:foo, x:offset, 1:address:num
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
element.set_value(address);
update_any_refcounts(element, ingredients.at(2));

:(scenario refcounts_put_index)
def main [
  1:address:num <- new number:type
  2:address:array:address:num <- new {(address number): type}, 3
  *2:address:array:address:num <- put-index *2:address:array:address:num, 0, 1:address:num
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: ("address" "array" "address" "number")} <- new {(address number): "type"}, {3: "literal"}
+mem: incrementing refcount of 1002: 0 -> 1
+run: {2: ("address" "array" "address" "number"), "lookup": ()} <- put-index {2: ("address" "array" "address" "number"), "lookup": ()}, {0: "literal"}, {1: ("address" "number")}
# put-index increments refcount
+mem: incrementing refcount of 1000: 1 -> 2

:(after "Write Memory in PUT_INDEX in Run")
reagent/*local*/ element;
element.set_value(address);
element.type = copy_array_element(base.type);
update_any_refcounts(element, value);

:(scenario refcounts_maybe_convert)
exclusive-container foo [
  x:num
  p:address:num
]
def main [
  1:address:num <- new number:type
  2:foo <- merge 1/p, 1:address:num
  4:address:num, 5:bool <- maybe-convert 2:foo, 1:variant/p
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
// todo: double-check data here as well
vector<double> data;
for (int i = 0;  i < size_of(product);  ++i)
  data.push_back(get_or_insert(Memory, base_address+/*skip tag*/1+i));
update_any_refcounts(product, data);

//:: manage refcounts in instructions that copy multiple locations at a time

:(scenario refcounts_copy_nested)
container foo [
  x:address:num  # address inside container
]
def main [
  1:address:num <- new number:type
  2:address:foo <- new foo:type
  *2:address:foo <- put *2:address:foo, x:offset, 1:address:num
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

:(before "End type_tree Definition")
struct address_element_info {
  // Where inside a container type (after flattening nested containers!) the
  // address lies
  int offset;

  // All the information we need to compute sizes of items inside an address
  // inside a container. `payload_type` Doesn't need to be a full-scale
  // reagent, since an address inside a container can never be an array, and
  // arrays are the only type that need to know their location to compute their
  // size.
  const type_tree* payload_type;

  address_element_info(int o, const type_tree* p);
  address_element_info(const address_element_info& other);
  ~address_element_info();
  address_element_info& operator=(const address_element_info& other);
};
:(code)
address_element_info::address_element_info(int o, const type_tree* p) {
  offset = o;
  payload_type = p;
}
address_element_info::address_element_info(const address_element_info& other) {
  offset = other.offset;
  payload_type = copy(other.payload_type);
}
address_element_info::~address_element_info() {
  if (payload_type) {
    delete payload_type;
    payload_type = NULL;
  }
}
address_element_info& address_element_info::operator=(const address_element_info& other) {
  offset = other.offset;
  if (payload_type) delete payload_type;
  payload_type = copy(other.payload_type);
  return *this;
}

:(before "End type_tree Definition")
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
Transform.push_back(compute_container_address_offsets);  // idempotent
:(code)
void compute_container_address_offsets(const recipe_ordinal r) {
  recipe& caller = get(Recipe, r);
  trace(9992, "transform") << "--- compute address offsets for " << caller.name << end();
  for (int i = 0;  i < SIZE(caller.steps);  ++i) {
    instruction& inst = caller.steps.at(i);
    trace(9993, "transform") << "- compute address offsets for " << to_string(inst) << end();
    for (int i = 0;  i < SIZE(inst.ingredients);  ++i)
      compute_container_address_offsets(inst.ingredients.at(i), " in '"+inst.original_string+"'");
    for (int i = 0;  i < SIZE(inst.products);  ++i)
      compute_container_address_offsets(inst.products.at(i), " in '"+inst.original_string+"'");
  }
}

void compute_container_address_offsets(reagent& r, const string& location_for_error_messages) {
  if (is_literal(r) || is_dummy(r)) return;
  compute_container_address_offsets(r.type, location_for_error_messages);
  if (contains_key(Container_metadata, r.type))
    r.metadata = get(Container_metadata, r.type);
}

// the recursive structure of this function needs to exactly match
// compute_container_sizes
void compute_container_address_offsets(const type_tree* type, const string& location_for_error_messages) {
  if (!type) return;
  if (!type->atom) {
    if (!type->left->atom) {
      raise << "invalid type " << to_string(type) << location_for_error_messages << '\n' << end();
      return;
    }
    if (type->left->name == "address")
      compute_container_address_offsets(payload_type(type), location_for_error_messages);
    else if (type->left->name == "array")
      compute_container_address_offsets(array_element(type), location_for_error_messages);
    // End compute_container_address_offsets Non-atom Special-cases
  }
  const type_tree* base_type = type;
  // Update base_type in compute_container_address_offsets
  if (!contains_key(Type, base_type->value)) return;  // error raised elsewhere
  type_info& info = get(Type, base_type->value);
  if (info.kind == CONTAINER) {
    compute_container_address_offsets(info, type, location_for_error_messages);
  }
  if (info.kind == EXCLUSIVE_CONTAINER) {
    compute_exclusive_container_address_offsets(info, type, location_for_error_messages);
  }
}

void compute_container_address_offsets(const type_info& container_info, const type_tree* full_type, const string& location_for_error_messages) {
  container_metadata& metadata = get(Container_metadata, full_type);
  if (!metadata.address.empty()) return;
  trace(9994, "transform") << "compute address offsets for container " << container_info.name << end();
  append_addresses(0, full_type, metadata.address, set<tag_condition_info>(), location_for_error_messages);
}

void compute_exclusive_container_address_offsets(const type_info& exclusive_container_info, const type_tree* full_type, const string& location_for_error_messages) {
  container_metadata& metadata = get(Container_metadata, full_type);
  trace(9994, "transform") << "compute address offsets for exclusive container " << exclusive_container_info.name << end();
  for (int tag = 0;  tag < SIZE(exclusive_container_info.elements);  ++tag) {
    set<tag_condition_info> key;
    key.insert(tag_condition_info(/*tag is at offset*/0, tag));
    append_addresses(/*skip tag offset*/1, variant_type(full_type, tag).type, metadata.address, key, location_for_error_messages);
  }
}

void append_addresses(int base_offset, const type_tree* type, map<set<tag_condition_info>, set<address_element_info> >& out, const set<tag_condition_info>& key, const string& location_for_error_messages) {
  if (is_mu_address(type)) {
    get_or_insert(out, key).insert(address_element_info(base_offset, new type_tree(*payload_type(type))));
    return;
  }
  const type_tree* base_type = type;
  // Update base_type in append_container_address_offsets
  const type_info& info = get(Type, base_type->value);
  if (info.kind == CONTAINER) {
    for (int curr_index = 0, curr_offset = base_offset;  curr_index < SIZE(info.elements);  ++curr_index) {
      trace(9993, "transform") << "checking container " << base_type->name << ", element " << curr_index << end();
      reagent/*copy*/ element = element_type(type, curr_index);  // not base_type
      // Compute Container Address Offset(element)
      if (is_mu_address(element)) {
        trace(9993, "transform") << "address at offset " << curr_offset << end();
        get_or_insert(out, key).insert(address_element_info(curr_offset, new type_tree(*payload_type(element.type))));
        ++curr_offset;
      }
      else if (is_mu_array(element)) {
        curr_offset += /*array length*/1;
        const type_tree* array_element_type = array_element(element.type);
        int array_element_size = size_of(array_element_type);
        for (int i = 0; i < static_array_length(element.type); ++i) {
          append_addresses(curr_offset, array_element_type, out, key, location_for_error_messages);
          curr_offset += array_element_size;
        }
      }
      else if (is_mu_container(element)) {
        append_addresses(curr_offset, element.type, out, key, location_for_error_messages);
        curr_offset += size_of(element);
      }
      else if (is_mu_exclusive_container(element)) {
        const type_tree* element_base_type = element.type;
        // Update element_base_type For Exclusive Container in append_addresses
        const type_info& element_info = get(Type, element_base_type->value);
        for (int tag = 0;  tag < SIZE(element_info.elements);  ++tag) {
          set<tag_condition_info> new_key = key;
          new_key.insert(tag_condition_info(curr_offset, tag));
          if (!contains_key(out, new_key))
            append_addresses(curr_offset+/*skip tag*/1, variant_type(element.type, tag).type, out, new_key, location_for_error_messages);
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
    for (int tag = 0;  tag < SIZE(info.elements);  ++tag) {
      set<tag_condition_info> new_key = key;
      new_key.insert(tag_condition_info(base_offset, tag));
      if (!contains_key(out, new_key))
        append_addresses(base_offset+/*skip tag*/1, variant_type(type, tag).type, out, new_key, location_for_error_messages);
    }
  }
}

//: for the following unit tests we'll do the work of the transform by hand

:(before "End Unit Tests")
void test_container_address_offsets_empty() {
  int old_size = SIZE(Container_metadata);
  // define a container with no addresses
  reagent r("x:point");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // scan
  compute_container_address_offsets(r, "");
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // the reagent we scanned knows it has no addresses
  CHECK(r.metadata.address.empty());
  // the global table contains an identical entry
  CHECK(contains_key(Container_metadata, r.type));
  CHECK(get(Container_metadata, r.type).address.empty());
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
}

void test_container_address_offsets() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0 that we have the size for
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  reagent r("x:foo");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // scan
  compute_container_address_offsets(r, "");
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // the reagent we scanned knows it has an address at offset 0
  CHECK_EQ(SIZE(r.metadata.address), 1);
  CHECK(contains_key(r.metadata.address, set<tag_condition_info>()));
  const set<address_element_info>& address_offsets = get(r.metadata.address, set<tag_condition_info>());  // unconditional for containers
  CHECK_EQ(SIZE(address_offsets), 1);
  CHECK_EQ(address_offsets.begin()->offset, 0);
  CHECK(address_offsets.begin()->payload_type->atom);
  CHECK_EQ(address_offsets.begin()->payload_type->name, "number");
  // the global table contains an identical entry
  CHECK(contains_key(Container_metadata, r.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, r.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
}

void test_container_address_offsets_2() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 1 that we have the size for
  run("container foo [\n"
      "  x:num\n"
      "  y:address:num\n"
      "]\n");
  reagent r("x:foo");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scan
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // the reagent we scanned knows it has an address at offset 1
  CHECK_EQ(SIZE(r.metadata.address), 1);
  CHECK(contains_key(r.metadata.address, set<tag_condition_info>()));
  const set<address_element_info>& address_offsets = get(r.metadata.address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets), 1);
  CHECK_EQ(address_offsets.begin()->offset, 1);  //
  CHECK(address_offsets.begin()->payload_type->atom);
  CHECK_EQ(address_offsets.begin()->payload_type->name, "number");
  // the global table contains an identical entry
  CHECK(contains_key(Container_metadata, r.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, r.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 1);  //
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

void test_container_address_offsets_nested() {
  int old_size = SIZE(Container_metadata);
  // define a container with a nested container containing an address
  run("container foo [\n"
      "  x:address:num\n"
      "  y:num\n"
      "]\n"
      "container bar [\n"
      "  p:point\n"
      "  f:foo\n"  // nested container containing address
      "]\n");
  reagent r("x:bar");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains entries for bar and included types: point and foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 3);
  // scan
  compute_container_address_offsets(r, "");
  // the reagent we scanned knows it has an address at offset 2
  CHECK_EQ(SIZE(r.metadata.address), 1);
  CHECK(contains_key(r.metadata.address, set<tag_condition_info>()));
  const set<address_element_info>& address_offsets = get(r.metadata.address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets), 1);
  CHECK_EQ(address_offsets.begin()->offset, 2);  //
  CHECK(address_offsets.begin()->payload_type->atom);
  CHECK_EQ(address_offsets.begin()->payload_type->name, "number");
  // the global table also knows its address offset
  CHECK(contains_key(Container_metadata, r.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, r.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 2);  //
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 3);
}

void test_container_address_offsets_from_address() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  reagent r("x:address:foo");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scan an address to the container
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scanning precomputed metadata for the container
  reagent container("x:foo");
  CHECK(contains_key(Container_metadata, container.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, container.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

void test_container_address_offsets_from_array() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  reagent r("x:array:foo");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scan an array of the container
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scanning precomputed metadata for the container
  reagent container("x:foo");
  CHECK(contains_key(Container_metadata, container.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, container.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

void test_container_address_offsets_from_address_to_array() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  reagent r("x:address:array:foo");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scan an address to an array of the container
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scanning precomputed metadata for the container
  reagent container("x:foo");
  CHECK(contains_key(Container_metadata, container.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, container.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

void test_container_address_offsets_from_static_array() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  reagent r("x:array:foo:10");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scan a static array of the container
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scanning precomputed metadata for the container
  reagent container("x:foo");
  CHECK(contains_key(Container_metadata, container.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, container.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

void test_container_address_offsets_from_address_to_static_array() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  reagent r("x:address:array:foo:10");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scan an address to a static array of the container
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scanning precomputed metadata for the container
  reagent container("x:foo");
  CHECK(contains_key(Container_metadata, container.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, container.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

void test_container_address_offsets_from_repeated_address_and_array_types() {
  int old_size = SIZE(Container_metadata);
  // define a container with an address at offset 0
  run("container foo [\n"
      "  x:address:num\n"
      "]\n");
  // scan a deep nest of 'address' and 'array' types modifying a container
  reagent r("x:address:array:address:address:array:foo:10");
  compute_container_sizes(r, "");  // need to first pre-populate the metadata
  // global metadata contains just the entry for foo
  // no entries for non-container types or other junk
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  compute_container_address_offsets(r, "");
  // compute_container_address_offsets creates no new entries
  CHECK_EQ(SIZE(Container_metadata)-old_size, 1);
  // scanning precomputed metadata for the container
  reagent container("x:foo");
  CHECK(contains_key(Container_metadata, container.type));
  const set<address_element_info>& address_offsets2 = get(get(Container_metadata, container.type).address, set<tag_condition_info>());
  CHECK_EQ(SIZE(address_offsets2), 1);
  CHECK_EQ(address_offsets2.begin()->offset, 0);
  CHECK(address_offsets2.begin()->payload_type->atom);
  CHECK_EQ(address_offsets2.begin()->payload_type->name, "number");
}

//: use metadata.address to update refcounts within containers, arrays and
//: exclusive containers

:(before "End Increment Refcounts(canonized_x)")
if (is_mu_container(canonized_x) || is_mu_exclusive_container(canonized_x)) {
  const container_metadata& metadata = get(Container_metadata, canonized_x.type);
  for (map<set<tag_condition_info>, set<address_element_info> >::const_iterator p = metadata.address.begin();  p != metadata.address.end();  ++p) {
    if (!all_match(data, p->first)) continue;
    for (set<address_element_info>::const_iterator info = p->second.begin();  info != p->second.end();  ++info)
      increment_refcount(data.at(info->offset));
  }
}

:(before "End Decrement Refcounts(canonized_x)")
if (is_mu_container(canonized_x) || is_mu_exclusive_container(canonized_x)) {
  trace(9999, "mem") << "need to read old value of '" << to_string(canonized_x) << "' to figure out what refcounts to decrement" << end();
  // read from canonized_x but without canonizing again
  reagent/*copy*/ tmp = canonized_x;
  tmp.properties.push_back(pair<string, string_tree*>("raw", NULL));
  vector<double> data = read_memory(tmp);
  trace(9999, "mem") << "done reading old value of '" << to_string(canonized_x) << "'" << end();
  const container_metadata& metadata = get(Container_metadata, canonized_x.type);
  for (map<set<tag_condition_info>, set<address_element_info> >::const_iterator p = metadata.address.begin();  p != metadata.address.end();  ++p) {
    if (!all_match(data, p->first)) continue;
    for (set<address_element_info>::const_iterator info = p->second.begin();  info != p->second.end();  ++info) {
      int element_address = get_or_insert(Memory, canonized_x.value + info->offset);
      reagent/*local*/ element;
      element.set_value(element_address+/*skip refcount*/1);
      element.type = new type_tree(*info->payload_type);
      decrement_refcount(element_address, info->payload_type, size_of(element)+/*refcount*/1);
    }
  }
}

:(code)
bool all_match(const vector<double>& data, const set<tag_condition_info>& conditions) {
  for (set<tag_condition_info>::const_iterator p = conditions.begin();  p != conditions.end();  ++p) {
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
  x:address:num
]
def main [
  1:address:num <- new number:type
  2:bar <- merge 1:address:num
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

:(scenario refcounts_put_index_array)
container bar [
  x:address:num
]
def main [
  1:address:num <- new number:type
  2:bar <- merge 1:address:num
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
  a:num
  b:bar  # contains an address
]
container bar [
  x:address:num
]
def main [
  1:address:num <- new number:type
  2:bar <- merge 1:address:num
  3:foo <- merge 1/b, 2:bar
  5:bar, 6:bool <- maybe-convert 3:foo, 1:variant/b
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
  x:num
  y:num
]
container curr [
  x:num
  y:address:num  # address inside container inside container
]
def main [
  1:address:num <- new number:type
  2:address:curr <- new curr:type
  *2:address:curr <- put *2:address:curr, 1:offset/y, 1:address:num
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
  a:num
  b:bar
]
exclusive-container bar [
  x:num
  y:num
  z:address:num
]
def main [
  1:address:num <- new number:type
  2:bar <- merge 0/x, 34
  3:foo <- merge 12, 2:bar
  5:bar <- merge 1/y, 35
  6:foo <- merge 13, 5:bar
  8:bar <- merge 2/z, 1:address:num
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
  a:num
  b:bar
]
container bar [
  x:num
  y:num
  z:address:num
]
def main [
  1:address:num <- new number:type
  2:foo <- merge 0/a, 34
  6:foo <- merge 0/a, 35
  10:bar <- merge 2/x, 15/y, 1:address:num
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
  a:num
  b:bar
]
exclusive-container bar [
  x:num
  y:address:num
]
def main [
  1:address:num <- new number:type
  10:foo <- merge 1/b, 1/y, 1:address:num
  20:foo <- copy 10:foo
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
# no change while merging items of other types
+run: {10: "foo"} <- merge {1: "literal", "b": ()}, {1: "literal", "y": ()}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {20: "foo"} <- copy {10: "foo"}
+mem: incrementing refcount of 1000: 2 -> 3

:(scenario refcounts_copy_array_within_container)
container foo [
  x:address:array:num
]
def main [
  1:address:array:num <- new number:type, 3
  2:foo <- merge 1:address:array:num
  3:address:array:num <- new number:type, 5
  2:foo <- merge 3:address:array:num
]
+run: {1: ("address" "array" "number")} <- new {number: "type"}, {3: "literal"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "foo"} <- merge {1: ("address" "array" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: {2: "foo"} <- merge {3: ("address" "array" "number")}
+mem: decrementing refcount of 1000: 2 -> 1

:(scenario refcounts_copy_address_within_static_array_within_container)
container foo [
  a:array:bar:3
  b:address:num
]
container bar [
  y:num
  z:address:num
]
def main [
  1:address:num <- new number:type
  2:bar <- merge 34, 1:address:num
  10:array:bar:3 <- create-array
  put-index 10:array:bar:3, 1, 2:bar
  20:foo <- merge 10:array:bar:3, 1:address:num
  1:address:num <- copy 0
  2:bar <- merge 34, 1:address:num
  put-index 10:array:bar:3, 1, 2:bar
  20:foo <- merge 10:array:bar:3, 1:address:num
]
+run: {1: ("address" "number")} <- new {number: "type"}
+mem: incrementing refcount of 1000: 0 -> 1
+run: {2: "bar"} <- merge {34: "literal"}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 1 -> 2
+run: put-index {10: ("array" "bar" "3")}, {1: "literal"}, {2: "bar"}
+mem: incrementing refcount of 1000: 2 -> 3
+run: {20: "foo"} <- merge {10: ("array" "bar" "3")}, {1: ("address" "number")}
+mem: incrementing refcount of 1000: 3 -> 4
+mem: incrementing refcount of 1000: 4 -> 5
+run: {1: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 1000: 5 -> 4
+run: {2: "bar"} <- merge {34: "literal"}, {1: ("address" "number")}
+mem: decrementing refcount of 1000: 4 -> 3
+run: put-index {10: ("array" "bar" "3")}, {1: "literal"}, {2: "bar"}
+mem: decrementing refcount of 1000: 3 -> 2
+run: {20: "foo"} <- merge {10: ("array" "bar" "3")}, {1: ("address" "number")}
+mem: decrementing refcount of 1000: 2 -> 1
+mem: decrementing refcount of 1000: 1 -> 0

:(scenario refcounts_handle_exclusive_containers_with_different_tags)
container foo1 [
  x:address:num
  y:num
]
container foo2 [
  x:num
  y:address:num
]
exclusive-container bar [
  a:foo1
  b:foo2
]
def main [
  1:address:num <- copy 12000/unsafe  # pretend allocation
  *1:address:num <- copy 34
  2:bar <- merge 0/foo1, 1:address:num, 97
  5:address:num <- copy 13000/unsafe  # pretend allocation
  *5:address:num <- copy 35
  6:bar <- merge 1/foo2, 98, 5:address:num
  2:bar <- copy 6:bar
]
+run: {2: "bar"} <- merge {0: "literal", "foo1": ()}, {1: ("address" "number")}, {97: "literal"}
+mem: incrementing refcount of 12000: 1 -> 2
+run: {6: "bar"} <- merge {1: "literal", "foo2": ()}, {98: "literal"}, {5: ("address" "number")}
+mem: incrementing refcount of 13000: 1 -> 2
+run: {2: "bar"} <- copy {6: "bar"}
+mem: incrementing refcount of 13000: 2 -> 3
+mem: decrementing refcount of 12000: 2 -> 1

:(code)
bool is_mu_container(const reagent& r) {
  return is_mu_container(r.type);
}
bool is_mu_container(const type_tree* type) {
  if (!type) return false;
  // End is_mu_container(type) Special-cases
  if (type->value == 0) return false;
  if (!contains_key(Type, type->value)) return false;  // error raised elsewhere
  type_info& info = get(Type, type->value);
  return info.kind == CONTAINER;
}

bool is_mu_exclusive_container(const reagent& r) {
  return is_mu_exclusive_container(r.type);
}
bool is_mu_exclusive_container(const type_tree* type) {
  if (!type) return false;
  // End is_mu_exclusive_container(type) Special-cases
  if (type->value == 0) return false;
  if (!contains_key(Type, type->value)) return false;  // error raised elsewhere
  type_info& info = get(Type, type->value);
  return info.kind == EXCLUSIVE_CONTAINER;
}

//:: Counters for trying to understand where Mu programs are spending time
//:: updating refcounts.

:(before "End Globals")
int Total_refcount_updates = 0;
map<recipe_ordinal, map</*step index*/int, /*num refcount updates*/int> > Num_refcount_updates;
:(after "Running One Instruction")
int initial_num_refcount_updates = Total_refcount_updates;
:(before "End Running One Instruction")
if (Run_profiler) {
  Num_refcount_updates[current_call().running_recipe][current_call().running_step_index]
      += (Total_refcount_updates - initial_num_refcount_updates);
  initial_num_refcount_updates = Total_refcount_updates;
}
:(before "End Non-primitive Call(caller_frame)")
Num_refcount_updates[caller_frame.running_recipe][caller_frame.running_step_index]
    += (Total_refcount_updates - initial_num_refcount_updates);
initial_num_refcount_updates = Total_refcount_updates;
:(after "Starting Reply")
if (Run_profiler) {
  Num_refcount_updates[current_call().running_recipe][current_call().running_step_index]
      += (Total_refcount_updates - initial_num_refcount_updates);
  initial_num_refcount_updates = Total_refcount_updates;
}
:(before "End dump_profile")
fout.open("profile.refcounts");
if (fout) {
  for (map<recipe_ordinal, recipe>::iterator p = Recipe.begin();  p != Recipe.end();  ++p)
    dump_recipe_profile(p->first, p->second, fout);
}
fout.close();
:(code)
void dump_recipe_profile(recipe_ordinal ridx, const recipe& r, ostream& out) {
  out << "recipe " << r.name << " [\n";
  for (int i = 0;  i < SIZE(r.steps);  ++i) {
    out << std::setw(6) << Num_refcount_updates[ridx][i] << ' ' << to_string(r.steps.at(i)) << '\n';
  }
  out << "]\n\n";
}

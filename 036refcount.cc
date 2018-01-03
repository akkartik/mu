int payload_size(reagent/*copy*/ x) {
  x.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  lookup_memory_core(x, /*check_for_null*/false);
  return size_of(x);
}

:(before "End type_tree Definition")
struct address_element_info {
  // Where inside a container type (after flattening nested containers!) the
  // address lies
  int offset;

  // All the information we need to compute sizes of items inside an address
  // inside a container. 'payload_type' doesn't need to be a full-scale
  // reagent because an address inside a container can never be an array, and
  // because arrays are the only type that need to know their location to
  // compute their size.
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
//      there is an address at 'offset' pointing to a payload of type payload_type
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

:(code)
bool all_match(const vector<double>& data, const set<tag_condition_info>& conditions) {
  for (set<tag_condition_info>::const_iterator p = conditions.begin();  p != conditions.end();  ++p) {
    if (data.at(p->offset) != p->tag)
      return false;
  }
  return true;
}

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

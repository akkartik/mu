// To recursively copy containers and any addresses they contain, use
// 'deep-copy'.
//
// Invariant: After a deep-copy its ingredient and result will point to no
// common addresses.
// Implications: Refcounts of all data pointed to by the original ingredient
// will remain unchanged. Refcounts of all data pointed to by the (newly
// created) result will be 1, in the absence of cycles.

:(scenario deep_copy_number)
def main [
  local-scope
  x:number <- copy 34
  y:number <- deep-copy x
  10:boolean/raw <- equal x, y
]
# non-address primitives are identical
+mem: storing 1 in location 10

:(scenario deep_copy_container_without_address)
container foo [
  x:number
  y:number
]
def main [
  local-scope
  a:foo <- merge 34, 35
  b:foo <- deep-copy a
  10:boolean/raw <- equal a, b
]
# containers are identical as long as they don't contain addresses
+mem: storing 1 in location 10

:(scenario deep_copy_address)
% Memory_allocated_until = 200;
def main [
  # avoid all memory allocations except the implicit ones inside deep-copy, so
  # that the result is deterministic
  1:address:number <- copy 100/unsafe  # pretend allocation
  *1:address:number <- copy 34
  2:address:number <- deep-copy 1:address:number
  10:boolean <- equal 1:address:number, 2:address:number
  11:boolean <- equal *1:address:number, *2:address:number
  2:address:number <- copy 0
]
# the result of deep-copy is a new address
+mem: storing 0 in location 10
# however, the contents are identical
+mem: storing 1 in location 11
# the result of deep-copy gets a refcount of 1
# (its address 202 = 200 base + 2 for temporary space inside deep-copy)
+run: {2: ("address" "number")} <- copy {0: "literal"}
+mem: decrementing refcount of 202: 1 -> 0
+abandon: saving 202 in free-list of size 2

:(scenario deep_copy_address_to_address)
% Memory_allocated_until = 200;
def main [
  # avoid all memory allocations except the implicit ones inside deep-copy, so
  # that the result is deterministic
  1:address:address:number <- copy 100/unsafe  # pretend allocation
  *1:address:address:number <- copy 150/unsafe
  **1:address:address:number <- copy 34
  2:address:address:number <- deep-copy 1:address:address:number
  10:boolean <- equal 1:address:address:number, 2:address:address:number
  11:boolean <- equal *1:address:address:number, *2:address:address:number
  12:boolean <- equal **1:address:address:number, **2:address:address:number
]
# the result of deep-copy is a new address
+mem: storing 0 in location 10
# any addresses in it or pointed to it are also new
+mem: storing 0 in location 11
# however, the non-address contents are identical
+mem: storing 1 in location 12

:(scenario deep_copy_array)
% Memory_allocated_until = 200;
def main [
  # avoid all memory allocations except the implicit ones inside deep-copy, so
  # that the result is deterministic
  100:number <- copy 1  # pretend refcount
  101:number <- copy 3  # pretend array length
  1:address:array:number <- copy 100/unsafe  # pretend allocation
  put-index *1:address:array:number, 0, 34
  put-index *1:address:array:number, 1, 35
  put-index *1:address:array:number, 2, 36
  stash [old:], *1:address:array:number
  2:address:array:number <- deep-copy 1:address:array:number
  stash 2:address:array:number
  stash [new:], *2:address:array:number
  10:boolean <- equal 1:address:array:number, 2:address:array:number
  11:boolean <- equal *1:address:array:number, *2:address:array:number
]
+app: old: 3 34 35 36
+app: new: 3 34 35 36
# the result of deep-copy is a new address
+mem: storing 0 in location 10
# however, the contents are identical
+mem: storing 1 in location 11

:(scenario deep_copy_container_with_address)
container foo [
  x:number
  y:address:number
]
def main [
  local-scope
  y0:address:number <- new number:type
  *y0 <- copy 35
  a:foo <- merge 34, y0
  b:foo <- deep-copy a
  10:boolean/raw <- equal a, b
  y1:address:number <- get b, y:offset
  11:boolean/raw <- equal y0, y1
  12:number/raw <- copy *y1
]
# containers containing addresses are not identical to their deep copies
+mem: storing 0 in location 10
# the addresses the contain are not identical either
+mem: storing 0 in location 11
+mem: storing 35 in location 12

:(before "End Primitive Recipe Declarations")
DEEP_COPY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "deep-copy", DEEP_COPY);
:(before "End Primitive Recipe Checks")
case DEEP_COPY: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'deep-copy' takes exactly one ingredient rather than '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case DEEP_COPY: {
  const reagent& input = current_instruction().ingredients.at(0);
  // allocate a tiny bit of temporary space for deep_copy()
  trace(9991, "run") << "deep-copy: allocating space for temporary" << end();
  reagent tmp("tmp:address:number");
  tmp.value = allocate(1);
  products.push_back(deep_copy(input, tmp));
  // reclaim Mu memory allocated for tmp
  trace(9991, "run") << "deep-copy: reclaiming temporary" << end();
  abandon(tmp.value, tmp.type->right, payload_size(tmp));
  // reclaim host memory allocated for tmp.type when tmp goes out of scope
  break;
}

:(code)
vector<double> deep_copy(reagent/*copy*/ in, const reagent& tmp) {
  canonize(in);
  vector<double> result;
  map<int, int> addresses_copied;
  if (is_mu_address(in))
    result.push_back(deep_copy_address(in, addresses_copied, tmp));
  else
    deep_copy(in, addresses_copied, tmp, result);
  trace(9991, "run") << "deep-copy: done" << end();
  return result;
}

// deep-copy an address and return a new address
int deep_copy_address(const reagent& canonized_in, map<int, int>& addresses_copied, const reagent& tmp) {
  int in_address = canonized_in.value;
  if (in_address == 0) return 0;
  trace(9991, "run") << "deep-copy: copying address " << in_address << end();
  if (contains_key(addresses_copied, in_address))
    return get(addresses_copied, in_address);
  reagent/*copy*/ payload = canonized_in;
  payload.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  int out = allocate(size_of(payload));
  put(addresses_copied, in_address, out);
  reagent/*copy*/ payload_type = payload;
  canonize_type(payload_type);
  const type_info& info = get(Type, payload_type.type->value);
  switch (info.kind) {
    case PRIMITIVE: {
      trace(9991, "run") << "deep-copy: reading ingredient " << payload.value << ' ' << to_string(payload) << end();
      vector<double> data;
      if (is_mu_address(payload_type)) {
        trace(9991, "run") << "deep-copy: payload is an address; recursing" << end();
        reagent/*copy*/ sub_payload = payload;
        canonize(sub_payload);
        data.push_back(deep_copy_address(sub_payload, addresses_copied, tmp));
        trace(9991, "run") << "deep-copy: done recursing " << to_string(data) << end();
      }
      else {
        data = read_memory(payload);
        trace(9991, "run") << "deep-copy: done reading " << to_string(data) << end();
      }
      trace(9991, "run") << "deep-copy: writing result " << out << ": " << to_string(data) << end();
      reagent/*copy*/ out_payload = payload;
      // HACK: write_memory interface isn't ideal for this situation; we need
      // a temporary location to help copy the payload.
      trace(9991, "run") << "deep-copy: writing temporary " << tmp.value << ": " << out << end();
      put(Memory, tmp.value, out);
      out_payload.value = tmp.value;
      vector<double> old_data = read_memory(out_payload);
      trace(9991, "run") << "deep-copy: really writing to " << out_payload.value << ' ' << to_string(out_payload) << " (old value " << to_string(old_data) << " new value " << to_string(data) << ")" << end();
      write_memory(out_payload, data, -1);
      trace(9991, "run") << "deep-copy: output is " << to_string(data) << end();
      break;
    }
    case CONTAINER:
      break;
    case EXCLUSIVE_CONTAINER:
      break;
  }
  return out;
}

// deep-copy a container and return a container

// deep-copy a container and return a vector of locations
void deep_copy(const reagent& canonized_in, map<int, int>& addresses_copied, const reagent& tmp, vector<double>& out) {
  assert(!is_mu_address(canonized_in));
  if (!contains_key(Container_metadata, canonized_in.type)) {
    assert(get(Type, canonized_in.type->value).kind == PRIMITIVE);  // not a container
    vector<double> result = read_memory(canonized_in);
    assert(scalar(result));
    out.push_back(result.at(0));
    return;
  }
  vector<double> data = read_memory(canonized_in);
  out.insert(out.end(), data.begin(), data.end());
  trace(9991, "run") << "deep-copy: scanning for addresses in " << to_string(data) << end();
  const container_metadata& metadata = get(Container_metadata, canonized_in.type);
  for (map<set<tag_condition_info>, set<address_element_info> >::const_iterator p = metadata.address.begin(); p != metadata.address.end(); ++p) {
    if (!all_match(data, p->first)) continue;
    for (set<address_element_info>::const_iterator info = p->second.begin(); info != p->second.end(); ++info) {
      // construct a fake reagent that reads directly from the appropriate
      // field of the container
      reagent curr;
      curr.type = new type_tree("address", new type_tree(*info->payload_type));
      curr.set_value(canonized_in.value + info->offset);
      curr.properties.push_back(pair<string, string_tree*>("raw", NULL));
      trace(9991, "run") << "deep-copy: copying address " << curr.value << end();
      out.at(info->offset) = deep_copy_address(curr, addresses_copied, tmp);
    }
  }
}

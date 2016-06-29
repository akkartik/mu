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
  a:foo <- merge 34 35
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
  reagent tmp("tmp:address:number");
  tmp.value = allocate(1);
  products.push_back(deep_copy(input, tmp));
  // reclaim Mu memory allocated for tmp
  abandon(tmp.value, tmp.type->right, payload_size(tmp));
  // reclaim host memory allocated for tmp.type when tmp goes out of scope
  break;
}

:(code)
vector<double> deep_copy(reagent/*copy*/ in, reagent& tmp) {
  canonize(in);
  vector<double> result;
  map<int, int> addresses_copied;
  if (is_mu_address(in))
    result.push_back(deep_copy_address(in, addresses_copied, tmp));
  // TODO: handle arrays
  else
    deep_copy(in, addresses_copied, result);
  return result;
}

// deep-copy an address and return a new address
int deep_copy_address(reagent/*copy*/ canonized_in, map<int, int>& addresses_copied, reagent& tmp) {
  int in_address = canonized_in.value;
  if (in_address == 0) return 0;
  if (contains_key(addresses_copied, in_address))
    return get(addresses_copied, in_address);
  // TODO: what about address:address:___? Should deep-copy be doing multiple
  // lookups? If the goal is to eliminate all common addresses, yes.
  reagent/*copy*/ payload = canonized_in;
  payload.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  canonize(payload);
  int out = allocate(size_of(payload));
  const type_info& info = get(Type, payload.type->value);
  switch (info.kind) {
    case PRIMITIVE: {
      canonized_in.properties.push_back(pair<string, string_tree*>("lookup", NULL));
      vector<double> data = read_memory(canonized_in);
      reagent/*copy*/ out_payload = canonized_in;
      // HACK: write_memory interface isn't ideal for this situation; we need
      // a temporary location to help copy the payload.
      put(Memory, tmp.value, out);
      out_payload.value = tmp.value;
      write_memory(out_payload, data, -1);
      break;
    }
    case CONTAINER:
      break;
    case EXCLUSIVE_CONTAINER:
      break;
  }
  put(addresses_copied, in_address, out);
  return out;
}

// deep-copy a container and return a container

// deep-copy a container and return a vector of locations
void deep_copy(const reagent& canonized_in, map<int, int>& addresses_copied, vector<double>& out) {
  assert(!is_mu_address(canonized_in));
  if (!contains_key(Container_metadata, canonized_in.type)) {
    assert(get(Type, canonized_in.type->value).kind == PRIMITIVE);  // not a container
    vector<double> result = read_memory(canonized_in);
    assert(scalar(result));
    out.push_back(result.at(0));
    return;
  }
  if (get(Container_metadata, canonized_in.type).address.empty()) {
    vector<double> result = read_memory(canonized_in);
    out.insert(out.end(), result.begin(), result.end());
    return;
  }
}

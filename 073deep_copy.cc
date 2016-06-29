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
  products.push_back(deep_copy(input));
  break;
}

:(code)
vector<double> deep_copy(reagent/*copy*/ in) {
  canonize(in);
  vector<double> result;
  map<int, int> addresses_copied;
  if (is_mu_address(in))
    result.push_back(deep_copy_address(in.value, addresses_copied));
  // TODO: handle arrays
  else
    deep_copy(in, addresses_copied, result);
  return result;
}

// deep-copy an address and return a new address
int deep_copy_address(int in_address, map<int, int>& addresses_copied) {
  if (in_address == 0) return 0;
  if (contains_key(addresses_copied, in_address)) return get(addresses_copied, in_address);
  int out = 0;
  // HERE
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

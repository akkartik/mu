int payload_size(reagent/*copy*/ x) {
  x.properties.push_back(pair<string, string_tree*>("lookup", NULL));
  lookup_memory_core(x, /*check_for_null*/false);
  return size_of(x);
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

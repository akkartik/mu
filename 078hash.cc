// A universal hash function that can handle objects of any type.
//
// The way it's currently implemented, two objects will have the same hash if
// all their non-address fields (all the way down) expand to the same sequence
// of scalar values. In particular, a container with all zero addresses hashes
// to 0. Hopefully this won't be an issue because we are usually hashing
// objects of a single type in any given hash table.
//
// Based on http://burtleburtle.net/bob/hash/hashfaq.html

:(before "End Primitive Recipe Declarations")
HASH,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "hash", HASH);
:(before "End Primitive Recipe Checks")
case HASH: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'hash' takes exactly one ingredient rather than '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case HASH: {
  reagent/*copy*/ input = current_instruction().ingredients.at(0);
  products.resize(1);
  products.at(0).push_back(hash(0, input));
  break;
}

//: in all the code below, the intermediate results of hashing are threaded through 'h'

:(code)
size_t hash(size_t h, reagent& r) {
  canonize(r);
  if (is_mu_string(r))  // optimization
    return hash_mu_string(h, r);
  else if (is_mu_address(r))
    return hash_mu_address(h, r);
  else if (is_mu_scalar(r))
    return hash_mu_scalar(h, r);
  else if (is_mu_array(r))
    return hash_mu_array(h, r);
  else if (is_mu_container(r))
    return hash_mu_container(h, r);
  else if (is_mu_exclusive_container(r))
    return hash_mu_exclusive_container(h, r);
  assert(false);
}

size_t hash_mu_scalar(size_t h, const reagent& r) {
  double input = is_literal(r) ? r.value : get_or_insert(Memory, r.value);
  return hash_iter(h, static_cast<size_t>(input));
}

size_t hash_mu_address(size_t h, reagent& r) {
  if (r.value == 0) return 0;
  trace(9999, "mem") << "location " << r.value << " is " << no_scientific(get_or_insert(Memory, r.value)) << end();
  r.value = get_or_insert(Memory, r.value);
  if (r.value != 0) {
    trace(9999, "mem") << "skipping refcount at " << r.value << end();
    r.set_value(r.value+1);  // skip refcount
  }
  drop_from_type(r, "address");
  return hash(h, r);
}

size_t hash_mu_string(size_t h, const reagent& r) {
  string input = read_mu_string(get_or_insert(Memory, r.value));
  for (int i = 0; i < SIZE(input); ++i) {
    h = hash_iter(h, static_cast<size_t>(input.at(i)));
//?     cerr << i << ": " << h << '\n';
  }
  return h;
}

size_t hash_mu_array(size_t h, const reagent& r) {
  int size = get_or_insert(Memory, r.value);
  reagent/*copy*/ elem = r;
  delete elem.type;
  elem.type = copy_array_element(r.type);
  for (int i=0, address = r.value+1; i < size; ++i, address += size_of(elem)) {
    reagent/*copy*/ tmp = elem;
    tmp.value = address;
    h = hash(h, tmp);
//?     cerr << i << " (" << address << "): " << h << '\n';
  }
  return h;
}

size_t hash_mu_container(size_t h, const reagent& r) {
  assert(r.type->value);
  type_info& info = get(Type, r.type->value);
  int address = r.value;
  int offset = 0;
  for (int i = 0; i < SIZE(info.elements); ++i) {
    reagent/*copy*/ element = element_type(r.type, i);
    if (has_property(element, "ignore-for-hash")) continue;
    element.set_value(address+offset);
    h = hash(h, element);
//?     cerr << i << ": " << h << '\n';
    offset += size_of(info.elements.at(i).type);
  }
  return h;
}

size_t hash_mu_exclusive_container(size_t h, const reagent& r) {
  assert(r.type->value);
  int tag = get(Memory, r.value);
  reagent/*copy*/ variant = variant_type(r, tag);
  // todo: move this error to container definition time
  if (has_property(variant, "ignore-for-hash"))
    raise << get(Type, r.type->value).name << ": /ignore-for-hash won't work in exclusive containers\n" << end();
  variant.set_value(r.value + /*skip tag*/1);
  h = hash(h, variant);
  return h;
}

size_t hash_iter(size_t h, size_t input) {
  h += input;
  h += (h<<10);
  h ^= (h>>6);

  h += (h<<3);
  h ^= (h>>11);
  h += (h<<15);
  return h;
}

:(scenario hash_container_checks_all_elements)
container foo [
  x:number
  y:character
]
def main [
  1:foo <- merge 34, 97/a
  3:number <- hash 1:foo
  return-unless 3:number
  4:foo <- merge 34, 98/a
  6:number <- hash 4:foo
  return-unless 6:number
  7:boolean <- equal 3:number, 6:number
]
# hash on containers includes all elements
+mem: storing 0 in location 7

:(scenario hash_exclusive_container_checks_all_elements)
exclusive-container foo [
  x:bar
  y:number
]
container bar [
  a:number
  b:number
]
def main [
  1:foo <- merge 0/x, 34, 35
  4:number <- hash 1:foo
  return-unless 4:number
  5:foo <- merge 0/x, 34, 36
  8:number <- hash 5:foo
  return-unless 8:number
  9:boolean <- equal 4:number, 8:number
]
# hash on containers includes all elements
+mem: storing 0 in location 9

:(scenario hash_can_ignore_container_elements)
container foo [
  x:number
  y:character/ignore-for-hash
]
def main [
  1:foo <- merge 34, 97/a
  3:number <- hash 1:foo
  return-unless 3:number
  4:foo <- merge 34, 98/a
  6:number <- hash 4:foo
  return-unless 6:number
  7:boolean <- equal 3:number, 6:number
]
# hashes match even though y is different
+mem: storing 1 in location 7

//: These properties aren't necessary for hash, they just test that the
//: current implementation works like we think it does.

:(scenario hash_of_zero_address)
def main [
  1:address:number <- copy 0
  2:number <- hash 1:address:number
]
+mem: storing 0 in location 2

//: This is probably too aggressive, but we need some way to avoid depending
//: on the precise bit pattern of a floating-point number.
:(scenario hash_of_numbers_ignores_fractional_part)
def main [
  1:number <- hash 1.5
  2:number <- hash 1
  3:boolean <- equal 1:number, 2:number
]
+mem: storing 1 in location 3

:(scenario hash_of_array_same_as_string)
def main [
  10:number <- copy 3
  11:number <- copy 97
  12:number <- copy 98
  13:number <- copy 99
  2:number <- hash 10:array:number/unsafe
  return-unless 2:number
  3:address:array:character <- new [abc]
  4:number <- hash 3:address:array:character
  return-unless 4:number
  5:boolean <- equal 2:number, 4:number
]
+mem: storing 1 in location 5

:(scenario hash_ignores_address_value)
def main [
  1:address:number <- new number:type
  *1:address:number <- copy 34
  2:number <- hash 1:address:number
  3:address:number <- new number:type
  *3:address:number <- copy 34
  4:number <- hash 3:address:number
  5:boolean <- equal 2:number, 4:number
]
# different addresses hash to the same result as long as the values the point to do so
+mem: storing 1 in location 5

:(scenario hash_ignores_address_refcount)
def main [
  1:address:number <- new number:type
  *1:address:number <- copy 34
  2:number <- hash 1:address:number
  return-unless 2:number
  # increment refcount
  3:address:number <- copy 1:address:number
  4:number <- hash 3:address:number
  return-unless 4:number
  5:boolean <- equal 2:number, 4:number
]
# hash doesn't change when refcount changes
+mem: storing 1 in location 5

:(scenario hash_container_depends_only_on_elements)
container foo [
  x:number
  y:character
]
container bar [
  x:number
  y:character
]
def main [
  1:foo <- merge 34, 97/a
  3:number <- hash 1:foo
  return-unless 3:number
  4:bar <- merge 34, 97/a
  6:number <- hash 4:bar
  return-unless 6:number
  7:boolean <- equal 3:number, 6:number
]
# containers with identical elements return identical hashes
+mem: storing 1 in location 7

:(scenario hash_container_depends_only_on_elements_2)
container foo [
  x:number
  y:character
  z:address:number
]
def main [
  1:address:number <- new number:type
  *1:address:number <- copy 34
  2:foo <- merge 34, 97/a, 1:address:number
  5:number <- hash 2:foo
  return-unless 5:number
  6:address:number <- new number:type
  *6:address:number <- copy 34
  7:foo <- merge 34, 97/a, 6:address:number
  10:number <- hash 7:foo
  return-unless 10:number
  11:boolean <- equal 5:number, 10:number
]
# containers with identical 'leaf' elements return identical hashes
+mem: storing 1 in location 11

:(scenario hash_container_depends_only_on_elements_3)
container foo [
  x:number
  y:character
  z:bar
]
container bar [
  x:number
  y:number
]
def main [
  1:foo <- merge 34, 97/a, 47, 48
  6:number <- hash 1:foo
  return-unless 6:number
  7:foo <- merge 34, 97/a, 47, 48
  12:number <- hash 7:foo
  return-unless 12:number
  13:boolean <- equal 6:number, 12:number
]
# containers with identical 'leaf' elements return identical hashes
+mem: storing 1 in location 13

:(scenario hash_exclusive_container_ignores_tag)
exclusive-container foo [
  x:bar
  y:number
]
container bar [
  a:number
  b:number
]
def main [
  1:foo <- merge 0/x, 34, 35
  4:number <- hash 1:foo
  return-unless 4:number
  5:bar <- merge 34, 35
  7:number <- hash 5:bar
  return-unless 7:number
  8:boolean <- equal 4:number, 7:number
]
# hash on containers includes all elements
+mem: storing 1 in location 8

//: An older version that supported only strings.
//: Hash functions are subtle and easy to get wrong, so we keep the old
//: version around and check that the new one is consistent with it.

:(scenario hash_matches_old_version)
def main [
  1:address:array:character <- new [abc]
  2:number <- hash 1:address:array:character
  3:number <- hash_old 1:address:array:character
  4:boolean <- equal 2:number, 3:number
]
+mem: storing 1 in location 4

:(before "End Primitive Recipe Declarations")
HASH_OLD,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "hash_old", HASH_OLD);
:(before "End Primitive Recipe Checks")
case HASH_OLD: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'hash_old' takes exactly one ingredient rather than '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_string(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'hash_old' currently only supports strings (address:array:character), but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case HASH_OLD: {
  string input = read_mu_string(ingredients.at(0).at(0));
  size_t h = 0 ;

  for (int i = 0; i < SIZE(input); ++i) {
    h += static_cast<size_t>(input.at(i));
    h += (h<<10);
    h ^= (h>>6);

    h += (h<<3);
    h ^= (h>>11);
    h += (h<<15);
  }

  products.resize(1);
  products.at(0).push_back(h);
  break;
}

// Compute a hash for objects of any type.
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
  const reagent& input = current_instruction().ingredients.at(0);
  products.resize(1);
  products.at(0).push_back(hash(0, input));
  break;
}

//: in all the code below, the intermediate results of hashing are threaded through 'h'

:(code)
size_t hash(size_t h, reagent/*copy*/ r) {
  canonize(r);
  if (is_mu_text(r))  // optimization
    return hash_mu_text(h, r);
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
  trace("mem") << "location " << r.value << " is " << no_scientific(get_or_insert(Memory, r.value)) << end();
  r.set_value(get_or_insert(Memory, r.value));
  drop_from_type(r, "address");
  return hash(h, r);
}

size_t hash_mu_text(size_t h, const reagent& r) {
  string input = read_mu_text(get_or_insert(Memory, r.value+/*skip alloc id*/1));
  for (int i = 0;  i < SIZE(input);  ++i) {
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
  for (int i=0, address = r.value+1;  i < size;  ++i, address += size_of(elem)) {
    reagent/*copy*/ tmp = elem;
    tmp.set_value(address);
    h = hash(h, tmp);
//?     cerr << i << " (" << address << "): " << h << '\n';
  }
  return h;
}

size_t hash_mu_container(size_t h, const reagent& r) {
  type_info& info = get(Type, get_base_type(r.type)->value);
  int address = r.value;
  int offset = 0;
  for (int i = 0;  i < SIZE(info.elements);  ++i) {
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
  const type_tree* type = get_base_type(r.type);
  assert(type->value);
  int tag = get(Memory, r.value);
  reagent/*copy*/ variant = variant_type(r, tag);
  // todo: move this error to container definition time
  if (has_property(variant, "ignore-for-hash"))
    raise << get(Type, type->value).name << ": /ignore-for-hash won't work in exclusive containers\n" << end();
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
  x:num
  y:char
]
def main [
  1:foo <- merge 34, 97/a
  3:num <- hash 1:foo
  return-unless 3:num
  4:foo <- merge 34, 98/a
  6:num <- hash 4:foo
  return-unless 6:num
  7:bool <- equal 3:num, 6:num
]
# hash on containers includes all elements
+mem: storing 0 in location 7

:(scenario hash_exclusive_container_checks_all_elements)
exclusive-container foo [
  x:bar
  y:num
]
container bar [
  a:num
  b:num
]
def main [
  1:foo <- merge 0/x, 34, 35
  4:num <- hash 1:foo
  return-unless 4:num
  5:foo <- merge 0/x, 34, 36
  8:num <- hash 5:foo
  return-unless 8:num
  9:bool <- equal 4:num, 8:num
]
# hash on containers includes all elements
+mem: storing 0 in location 9

:(scenario hash_can_ignore_container_elements)
container foo [
  x:num
  y:char/ignore-for-hash
]
def main [
  1:foo <- merge 34, 97/a
  3:num <- hash 1:foo
  return-unless 3:num
  4:foo <- merge 34, 98/a
  6:num <- hash 4:foo
  return-unless 6:num
  7:bool <- equal 3:num, 6:num
]
# hashes match even though y is different
+mem: storing 1 in location 7

//: These properties aren't necessary for hash, they just test that the
//: current implementation works like we think it does.

:(scenario hash_of_zero_address)
def main [
  1:&:num <- copy 0
  2:num <- hash 1:&:num
]
+mem: storing 0 in location 2

//: This is probably too aggressive, but we need some way to avoid depending
//: on the precise bit pattern of a floating-point number.
:(scenario hash_of_numbers_ignores_fractional_part)
def main [
  1:num <- hash 1.5
  2:num <- hash 1
  3:bool <- equal 1:num, 2:num
]
+mem: storing 1 in location 3

:(scenario hash_of_array_same_as_string)
def main [
  10:num <- copy 3
  11:num <- copy 97
  12:num <- copy 98
  13:num <- copy 99
  2:num <- hash 10:@:num/unsafe
  return-unless 2:num
  3:text <- new [abc]
  4:num <- hash 3:text
  return-unless 4:num
  5:bool <- equal 2:num, 4:num
]
+mem: storing 1 in location 5

:(scenario hash_ignores_address_value)
def main [
  1:&:num <- new number:type
  *1:&:num <- copy 34
  2:num <- hash 1:&:num
  3:&:num <- new number:type
  *3:&:num <- copy 34
  4:num <- hash 3:&:num
  5:bool <- equal 2:num, 4:num
]
# different addresses hash to the same result as long as the values the point to do so
+mem: storing 1 in location 5

:(scenario hash_container_depends_only_on_elements)
container foo [
  x:num
  y:char
]
container bar [
  x:num
  y:char
]
def main [
  1:foo <- merge 34, 97/a
  3:num <- hash 1:foo
  return-unless 3:num
  4:bar <- merge 34, 97/a
  6:num <- hash 4:bar
  return-unless 6:num
  7:bool <- equal 3:num, 6:num
]
# containers with identical elements return identical hashes
+mem: storing 1 in location 7

:(scenario hash_container_depends_only_on_elements_2)
container foo [
  x:num
  y:char
  z:&:num
]
def main [
  1:&:num <- new number:type
  *1:&:num <- copy 34
  2:foo <- merge 34, 97/a, 1:&:num
  5:num <- hash 2:foo
  return-unless 5:num
  6:&:num <- new number:type
  *6:&:num <- copy 34
  7:foo <- merge 34, 97/a, 6:&:num
  10:num <- hash 7:foo
  return-unless 10:num
  11:bool <- equal 5:num, 10:num
]
# containers with identical 'leaf' elements return identical hashes
+mem: storing 1 in location 11

:(scenario hash_container_depends_only_on_elements_3)
container foo [
  x:num
  y:char
  z:bar
]
container bar [
  x:num
  y:num
]
def main [
  1:foo <- merge 34, 97/a, 47, 48
  6:num <- hash 1:foo
  return-unless 6:num
  7:foo <- merge 34, 97/a, 47, 48
  12:num <- hash 7:foo
  return-unless 12:num
  13:bool <- equal 6:num, 12:num
]
# containers with identical 'leaf' elements return identical hashes
+mem: storing 1 in location 13

:(scenario hash_exclusive_container_ignores_tag)
exclusive-container foo [
  x:bar
  y:num
]
container bar [
  a:num
  b:num
]
def main [
  1:foo <- merge 0/x, 34, 35
  4:num <- hash 1:foo
  return-unless 4:num
  5:bar <- merge 34, 35
  7:num <- hash 5:bar
  return-unless 7:num
  8:bool <- equal 4:num, 7:num
]
# hash on containers includes all elements
+mem: storing 1 in location 8

//: An older version that supported only strings.
//: Hash functions are subtle and easy to get wrong, so we keep the old
//: version around and check that the new one is consistent with it.

:(scenario hash_matches_old_version)
def main [
  1:text <- new [abc]
  3:num <- hash 1:text
  4:num <- hash_old 1:text
  5:bool <- equal 3:num, 4:num
]
+mem: storing 1 in location 5

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
  if (!is_mu_text(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'hash_old' currently only supports texts (address array character), but got '" << inst.ingredients.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case HASH_OLD: {
  string input = read_mu_text(ingredients.at(0).at(/*skip alloc id*/1));
  size_t h = 0 ;

  for (int i = 0;  i < SIZE(input);  ++i) {
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

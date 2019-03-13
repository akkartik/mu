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
  trace(Callstack_depth+1, "mem") << "location " << r.value << " is " << no_scientific(get_or_insert(Memory, r.value)) << end();
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

void test_hash_container_checks_all_elements() {
  run(
      "container foo [\n"
      "  x:num\n"
      "  y:char\n"
      "]\n"
      "def main [\n"
      "  1:foo <- merge 34, 97/a\n"
      "  3:num <- hash 1:foo\n"
      "  return-unless 3:num\n"
      "  4:foo <- merge 34, 98/a\n"
      "  6:num <- hash 4:foo\n"
      "  return-unless 6:num\n"
      "  7:bool <- equal 3:num, 6:num\n"
      "]\n"
  );
  // hash on containers includes all elements
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 7\n"
  );
}

void test_hash_exclusive_container_checks_all_elements() {
  run(
      "exclusive-container foo [\n"
      "  x:bar\n"
      "  y:num\n"
      "]\n"
      "container bar [\n"
      "  a:num\n"
      "  b:num\n"
      "]\n"
      "def main [\n"
      "  1:foo <- merge 0/x, 34, 35\n"
      "  4:num <- hash 1:foo\n"
      "  return-unless 4:num\n"
      "  5:foo <- merge 0/x, 34, 36\n"
      "  8:num <- hash 5:foo\n"
      "  return-unless 8:num\n"
      "  9:bool <- equal 4:num, 8:num\n"
      "]\n"
  );
  // hash on containers includes all elements
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 9\n"
  );
}

void test_hash_can_ignore_container_elements() {
  run(
      "container foo [\n"
      "  x:num\n"
      "  y:char/ignore-for-hash\n"
      "]\n"
      "def main [\n"
      "  1:foo <- merge 34, 97/a\n"
      "  3:num <- hash 1:foo\n"
      "  return-unless 3:num\n"
      "  4:foo <- merge 34, 98/a\n"
      "  6:num <- hash 4:foo\n"
      "  return-unless 6:num\n"
      "  7:bool <- equal 3:num, 6:num\n"
      "]\n"
  );
  // hashes match even though y is different
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 7\n"
  );
}

//: These properties aren't necessary for hash, they just test that the
//: current implementation works like we think it does.

void test_hash_of_zero_address() {
  run(
      "def main [\n"
      "  1:&:num <- copy null\n"
      "  2:num <- hash 1:&:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 2\n"
  );
}

//: This is probably too aggressive, but we need some way to avoid depending
//: on the precise bit pattern of a floating-point number.
void test_hash_of_numbers_ignores_fractional_part() {
  run(
      "def main [\n"
      "  1:num <- hash 1.5\n"
      "  2:num <- hash 1\n"
      "  3:bool <- equal 1:num, 2:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 3\n"
  );
}

void test_hash_of_array_same_as_string() {
  run(
      "def main [\n"
      "  10:num <- copy 3\n"
      "  11:num <- copy 97\n"
      "  12:num <- copy 98\n"
      "  13:num <- copy 99\n"
      "  2:num <- hash 10:@:num/unsafe\n"
      "  return-unless 2:num\n"
      "  3:text <- new [abc]\n"
      "  4:num <- hash 3:text\n"
      "  return-unless 4:num\n"
      "  5:bool <- equal 2:num, 4:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 5\n"
  );
}

void test_hash_ignores_address_value() {
  run(
      "def main [\n"
      "  1:&:num <- new number:type\n"
      "  *1:&:num <- copy 34\n"
      "  2:num <- hash 1:&:num\n"
      "  3:&:num <- new number:type\n"
      "  *3:&:num <- copy 34\n"
      "  4:num <- hash 3:&:num\n"
      "  5:bool <- equal 2:num, 4:num\n"
      "]\n"
  );
  // different addresses hash to the same result as long as the values the point to do so
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 5\n"
  );
}

void test_hash_container_depends_only_on_elements() {
  run(
      "container foo [\n"
      "  x:num\n"
      "  y:char\n"
      "]\n"
      "container bar [\n"
      "  x:num\n"
      "  y:char\n"
      "]\n"
      "def main [\n"
      "  1:foo <- merge 34, 97/a\n"
      "  3:num <- hash 1:foo\n"
      "  return-unless 3:num\n"
      "  4:bar <- merge 34, 97/a\n"
      "  6:num <- hash 4:bar\n"
      "  return-unless 6:num\n"
      "  7:bool <- equal 3:num, 6:num\n"
      "]\n"
  );
  // containers with identical elements return identical hashes
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 7\n"
  );
}

void test_hash_container_depends_only_on_elements_2() {
  run(
      "container foo [\n"
      "  x:num\n"
      "  y:char\n"
      "  z:&:num\n"
      "]\n"
      "def main [\n"
      "  1:&:num <- new number:type\n"
      "  *1:&:num <- copy 34\n"
      "  2:foo <- merge 34, 97/a, 1:&:num\n"
      "  5:num <- hash 2:foo\n"
      "  return-unless 5:num\n"
      "  6:&:num <- new number:type\n"
      "  *6:&:num <- copy 34\n"
      "  7:foo <- merge 34, 97/a, 6:&:num\n"
      "  10:num <- hash 7:foo\n"
      "  return-unless 10:num\n"
      "  11:bool <- equal 5:num, 10:num\n"
      "]\n"
  );
  // containers with identical 'leaf' elements return identical hashes
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 11\n"
  );
}

void test_hash_container_depends_only_on_elements_3() {
  run(
      "container foo [\n"
      "  x:num\n"
      "  y:char\n"
      "  z:bar\n"
      "]\n"
      "container bar [\n"
      "  x:num\n"
      "  y:num\n"
      "]\n"
      "def main [\n"
      "  1:foo <- merge 34, 97/a, 47, 48\n"
      "  6:num <- hash 1:foo\n"
      "  return-unless 6:num\n"
      "  7:foo <- merge 34, 97/a, 47, 48\n"
      "  12:num <- hash 7:foo\n"
      "  return-unless 12:num\n"
      "  13:bool <- equal 6:num, 12:num\n"
      "]\n"
  );
  // containers with identical 'leaf' elements return identical hashes
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 13\n"
  );
}

void test_hash_exclusive_container_ignores_tag() {
  run(
      "exclusive-container foo [\n"
      "  x:bar\n"
      "  y:num\n"
      "]\n"
      "container bar [\n"
      "  a:num\n"
      "  b:num\n"
      "]\n"
      "def main [\n"
      "  1:foo <- merge 0/x, 34, 35\n"
      "  4:num <- hash 1:foo\n"
      "  return-unless 4:num\n"
      "  5:bar <- merge 34, 35\n"
      "  7:num <- hash 5:bar\n"
      "  return-unless 7:num\n"
      "  8:bool <- equal 4:num, 7:num\n"
      "]\n"
  );
  // hash on containers includes all elements
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 8\n"
  );
}

//: An older version that supported only strings.
//: Hash functions are subtle and easy to get wrong, so we keep the old
//: version around and check that the new one is consistent with it.

void test_hash_matches_old_version() {
  run(
      "def main [\n"
      "  1:text <- new [abc]\n"
      "  3:num <- hash 1:text\n"
      "  4:num <- hash_old 1:text\n"
      "  5:bool <- equal 3:num, 4:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 5\n"
  );
}

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

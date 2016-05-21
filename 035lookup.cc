//: Go from an address to the payload it points at (skipping the refcount)
//: using /lookup.
//:
//: Let's say we have this address (read the top of the address layer for
//: details on these diagrams):
//:
//:                     +---+------------+
//:          x -------> | 1 |  number    |
//:                     +---+------------+
//:
//: Once you have an address you can read or modify its payload by performing
//: a lookup:
//:
//:     x/lookup <- copy 34
//:
//: or more concisely:
//:
//:     *x <- copy 34
//:
//: This modifies not x, but the payload x points to:
//:
//:                     +---+------------+
//:          x -------> | 1 |         34 |
//:                     +---+------------+
//:
//: You can also read from the payload in instructions like this:
//:
//:     z:number <- add *x, 1
//:
//: After this instruction runs the value of z will be 35.
//:
//: The tests in this layer use unsafe operations so as to stay decoupled from
//: 'new'.

:(scenario copy_indirect)
def main [
  1:address:number <- copy 10/unsafe
  11:number <- copy 34
  # This loads location 1 as an address and looks up *that* location.
  2:number <- copy 1:address:number/lookup
]
# 1 contains 10. Skip refcount and lookup location 11.
+mem: storing 34 in location 2

:(before "End Preprocess read_memory(x)")
canonize(x);

//: similarly, write to addresses pointing at other locations using the
//: 'lookup' property
:(scenario store_indirect)
def main [
  1:address:number <- copy 10/unsafe
  1:address:number/lookup <- copy 34
]
+mem: storing 34 in location 11

:(before "End Preprocess write_memory(x, data)")
canonize(x);
if (x.value == 0) {
  raise << "can't write to location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
  return;
}

//: writes to address 0 always loudly fail
:(scenario store_to_0_fails)
% Hide_errors = true;
def main [
  1:address:number <- copy 0
  1:address:number/lookup <- copy 34
]
-mem: storing 34 in location 0
+error: can't write to location 0 in '1:address:number/lookup <- copy 34'

:(code)
void canonize(reagent& x) {
  if (is_literal(x)) return;
  // End canonize(x) Special-cases
  while (has_property(x, "lookup"))
    lookup_memory(x);
}

void lookup_memory(reagent& x) {
  if (!x.type || x.type->value != get(Type_ordinal, "address")) {
    raise << maybe(current_recipe_name()) << "tried to /lookup '" << x.original_string << "' but it isn't an address\n" << end();
    return;
  }
  // compute value
  if (x.value == 0) {
    raise << maybe(current_recipe_name()) << "tried to /lookup 0\n" << end();
    return;
  }
  lookup_memory_core(x);
}

void lookup_memory_core(reagent& x) {
  if (x.value == 0) return;
  trace(9999, "mem") << "location " << x.value << " is " << no_scientific(get_or_insert(Memory, x.value)) << end();
  x.set_value(get_or_insert(Memory, x.value));
  drop_from_type(x, "address");
  if (x.value) {
    trace(9999, "mem") << "skipping refcount at " << x.value << end();
    x.set_value(x.value+1);  // skip refcount
  }
  drop_one_lookup(x);
}

void test_lookup_address_skips_refcount() {
  reagent x("*x:address:number");
  x.set_value(34);  // unsafe
  put(Memory, 34, 1000);
  lookup_memory(x);
  CHECK_TRACE_CONTENTS("mem: skipping refcount at 1000");
  CHECK_EQ(x.value, 1001);
}

void test_lookup_zero_address_does_not_skip_refcount() {
  reagent x("*x:address:number");
  x.set_value(34);  // unsafe
  put(Memory, 34, 0);
  lookup_memory(x);
  CHECK_TRACE_DOESNT_CONTAIN("mem: skipping refcount at 0");
  CHECK_EQ(x.value, 0);
}

:(before "End Preprocess types_strictly_match(reagent to, reagent from)")
if (!canonize_type(to)) return false;
if (!canonize_type(from)) return false;

:(before "End Preprocess is_mu_array(reagent r)")
if (!canonize_type(r)) return false;

:(before "End Preprocess is_mu_address(reagent r)")
if (!canonize_type(r)) return false;

:(before "End Preprocess is_mu_number(reagent r)")
if (!canonize_type(r)) return false;
:(before "End Preprocess is_mu_boolean(reagent r)")
if (!canonize_type(r)) return false;

:(after "Update product While Type-checking Merge")
if (!canonize_type(product)) continue;

:(before "End Compute Call Ingredient")
canonize_type(ingredient);
:(before "End Preprocess NEXT_INGREDIENT product")
canonize_type(product);
:(before "End Check RETURN Copy(lhs, rhs)
canonize_type(lhs);
canonize_type(rhs);

:(before "Compute Container Size(reagent rcopy)")
if (!canonize_type(rcopy)) return;

:(before "Compute Container Size(element)")
assert(!has_property(element, "lookup"));

:(code)
bool canonize_type(reagent& r) {
  while (has_property(r, "lookup")) {
    if (!r.type || r.type->value != get(Type_ordinal, "address")) {
      raise << "can't lookup non-address: '" << to_string(r) << "': '" << to_string(r.type) << "'\n" << end();
      return false;
    }
    drop_from_type(r, "address");
    drop_one_lookup(r);
  }
  return true;
}

void drop_one_lookup(reagent& r) {
  for (vector<pair<string, string_tree*> >::iterator p = r.properties.begin(); p != r.properties.end(); ++p) {
    if (p->first == "lookup") {
      r.properties.erase(p);
      return;
    }
  }
  assert(false);
}

//: Tedious fixup to support addresses in container/array instructions of previous layers.
//: Most instructions don't require fixup if they use the 'ingredients' and
//: 'products' variables in run_current_routine().

:(scenario get_indirect)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  2:number <- get 1:address:point/lookup, 0:offset
]
+mem: storing 34 in location 2

:(scenario get_indirect2)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  2:address:number <- copy 20/unsafe
  2:address:number/lookup <- get 1:address:point/lookup, 0:offset
]
+mem: storing 34 in location 21

:(scenario include_nonlookup_properties)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  2:number <- get 1:address:point/lookup/foo, 0:offset
]
+mem: storing 34 in location 2

:(after "Update GET base in Check")
if (!canonize_type(base)) break;
:(after "Update GET product in Check")
if (!canonize_type(product)) break;
:(after "Update GET base in Run")
canonize(base);

:(scenario put_indirect)
def main [
  1:address:point <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  12:number <- copy 35
  1:address:point/lookup <- put 1:address:point/lookup, 0:offset, 36
]
+mem: storing 36 in location 11

:(after "Update PUT base in Check")
if (!canonize_type(base)) break;
:(after "Update PUT offset in Check")
if (!canonize_type(offset)) break;
:(after "Update PUT base in Run")
canonize(base);

:(scenario new_error)
% Hide_errors = true;
def main [
  1:number/raw <- new number:type
]
+error: main: product of 'new' has incorrect type: '1:number/raw <- new number:type'

:(after "Update NEW product in Check")
canonize_type(product);

:(scenario copy_array_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  2:array:number <- copy 1:address:array:number/lookup
]
+mem: storing 3 in location 2
+mem: storing 14 in location 3
+mem: storing 15 in location 4
+mem: storing 16 in location 5

:(before "Update CREATE_ARRAY product in Check")
// 'create-array' does not support indirection. Static arrays are meant to be
// allocated on the 'stack'.
assert(!has_property(product, "lookup"));
:(before "Update CREATE_ARRAY product in Run")
// 'create-array' does not support indirection. Static arrays are meant to be
// allocated on the 'stack'.
assert(!has_property(product, "lookup"));

:(scenario index_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  2:number <- index 1:address:array:number/lookup, 1
]
+mem: storing 15 in location 2

:(before "Update INDEX base in Check")
if (!canonize_type(base)) break;
:(before "Update INDEX index in Check")
if (!canonize_type(index)) break;
:(before "Update INDEX product in Check")
if (!canonize_type(product)) break;

:(before "Update INDEX base in Run")
canonize(base);
:(before "Update INDEX index in Run")
canonize(index);

:(scenario put_index_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  1:address:array:number/lookup <- put-index 1:address:array:number/lookup, 1, 34
]
+mem: storing 34 in location 13

:(scenario put_index_indirect_2)
def main [
  1:array:number:3 <- create-array
  2:number <- copy 14
  3:number <- copy 15
  4:number <- copy 16
  5:address:number <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 1
  5:address:array:number/lookup <- put-index 1:array:number:3, 5:address:number/lookup, 34
]
+mem: storing 34 in location 3

:(scenario dilated_reagent_in_static_array)
def main [
  {1: (array (address number) 3)} <- create-array
  5:address:number <- new number:type
  {1: (array (address number) 3)} <- put-index {1: (array (address number) 3)}, 0, 5:address:number
  *5:address:number <- copy 34
  6:number <- copy *5:address:number
]
+run: creating array of size 4
+mem: storing 34 in location 6

:(before "Update PUT_INDEX base in Check")
if (!canonize_type(base)) break;
:(before "Update PUT_INDEX index in Check")
if (!canonize_type(index)) break;
:(before "Update PUT_INDEX value in Check")
if (!canonize_type(value)) break;

:(before "Update PUT_INDEX base in Run")
canonize(base);
:(before "Update PUT_INDEX index in Run")
canonize(index);

:(scenario length_indirect)
def main [
  # 10 reserved for refcount
  11:array:number:3 <- create-array
  12:number <- copy 14
  13:number <- copy 15
  14:number <- copy 16
  1:address:array:number <- copy 10/unsafe
  2:number <- length 1:address:array:number/lookup
]
+mem: storing 3 in location 2

:(before "Update LENGTH array in Check")
if (!canonize_type(array)) break;
:(before "Update LENGTH array in Run")
canonize(array);

:(scenario maybe_convert_indirect)
def main [
  # 10 reserved for refcount
  11:number-or-point <- merge 0/number, 34
  1:address:number-or-point <- copy 10/unsafe
  2:number, 3:boolean <- maybe-convert 1:address:number-or-point/lookup, i:variant
]
+mem: storing 1 in location 3
+mem: storing 34 in location 2

:(scenario maybe_convert_indirect_2)
def main [
  # 10 reserved for refcount
  11:number-or-point <- merge 0/number, 34
  1:address:number-or-point <- copy 10/unsafe
  2:address:number <- copy 20/unsafe
  2:address:number/lookup, 3:boolean <- maybe-convert 1:address:number-or-point/lookup, i:variant
]
+mem: storing 1 in location 3
+mem: storing 34 in location 21

:(scenario maybe_convert_indirect_3)
def main [
  # 10 reserved for refcount
  11:number-or-point <- merge 0/number, 34
  1:address:number-or-point <- copy 10/unsafe
  2:address:boolean <- copy 20/unsafe
  3:number, 2:address:boolean/lookup <- maybe-convert 1:address:number-or-point/lookup, i:variant
]
+mem: storing 1 in location 21
+mem: storing 34 in location 3

:(before "Update MAYBE_CONVERT base in Check")
if (!canonize_type(base)) break;
:(before "Update MAYBE_CONVERT product in Check")
if (!canonize_type(product)) break;
:(before "Update MAYBE_CONVERT status in Check")
if (!canonize_type(status)) break;

:(before "Update MAYBE_CONVERT base in Run")
canonize(base);
:(before "Update MAYBE_CONVERT product in Run")
canonize(product);
:(before "Update MAYBE_CONVERT status in Run")
canonize(status);

:(scenario merge_exclusive_container_indirect)
def main [
  1:address:number-or-point <- copy 10/unsafe
  1:address:number-or-point/lookup <- merge 0/number, 34
]
# skip 10 for refcount
+mem: storing 0 in location 11
+mem: storing 34 in location 12

:(before "Update size_mismatch Check for MERGE(x)
canonize(x);

//: abbreviation for '/lookup': a prefix '*'

:(scenario lookup_abbreviation)
def main [
  1:address:number <- copy 10/unsafe
  # 10 reserved for refcount
  11:number <- copy 34
  3:number <- copy *1:address:number
]
+parse: ingredient: {1: ("address" "number"), "lookup": ()}
+mem: storing 34 in location 3

:(before "End Parsing reagent")
{
  while (!name.empty() && name.at(0) == '*') {
    name.erase(0, 1);
    properties.push_back(pair<string, string_tree*>("lookup", NULL));
  }
  if (name.empty())
    raise << "illegal name '" << original_string << "'\n" << end();
}

//:: helpers for debugging

:(before "End Primitive Recipe Declarations")
_DUMP,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$dump", _DUMP);
:(before "End Primitive Recipe Implementations")
case _DUMP: {
  reagent/*copy*/ after_canonize = current_instruction().ingredients.at(0);
  canonize(after_canonize);
  cerr << maybe(current_recipe_name()) << current_instruction().ingredients.at(0).name << ' ' << no_scientific(current_instruction().ingredients.at(0).value) << " => " << no_scientific(after_canonize.value) << " => " << no_scientific(get_or_insert(Memory, after_canonize.value)) << '\n';
  break;
}

//: grab an address, and then dump its value at intervals
//: useful for tracking down memory corruption (writing to an out-of-bounds address)
:(before "End Globals")
int Bar = -1;
:(before "End Primitive Recipe Declarations")
_BAR,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$bar", _BAR);
:(before "End Primitive Recipe Implementations")
case _BAR: {
  if (current_instruction().ingredients.empty()) {
    if (Bar != -1) cerr << Bar << ": " << no_scientific(get_or_insert(Memory, Bar)) << '\n';
    else cerr << '\n';
  }
  else {
    reagent/*copy*/ tmp = current_instruction().ingredients.at(0);
    canonize(tmp);
    Bar = tmp.value;
  }
  break;
}

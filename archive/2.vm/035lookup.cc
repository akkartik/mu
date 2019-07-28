//: Go from an address to the payload it points at using /lookup.
//:
//: The tests in this layer use unsafe operations so as to stay decoupled from
//: 'new'.

void test_copy_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:num
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 94\n"
      // Treat locations 10 and 11 as an address to look up, pointing at the
      // payload in locations 20 and 21.
      "  30:num <- copy 10:&:num/lookup\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 94 in location 30\n"
  );
}

:(before "End Preprocess read_memory(x)")
canonize(x);

//: similarly, write to addresses pointing at other locations using the
//: 'lookup' property
:(code)
void test_store_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:num
      "  11:num <- copy 10\n"
      "  10:&:num/lookup <- copy 94\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 94 in location 11\n"
  );
}

:(before "End Preprocess write_memory(x, data)")
canonize(x);

//: writes to address 0 always loudly fail
:(code)
void test_store_to_0_fails() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  10:&:num <- copy null\n"
      "  10:&:num/lookup <- copy 94\n"
      "]\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("mem: storing 94 in location 0");
  CHECK_TRACE_CONTENTS(
      "error: main: tried to lookup 0 in '10:&:num/lookup <- copy 94'\n"
  );
}

//: attempts to /lookup address 0 always loudly fail
void test_lookup_0_fails() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  10:&:num <- copy null\n"
      "  20:num <- copy 10:&:num/lookup\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: tried to lookup 0 in '20:num <- copy 10:&:num/lookup'\n"
  );
}

void test_lookup_0_dumps_callstack() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  foo null\n"
      "]\n"
      "def foo [\n"
      "  10:&:num <- next-input\n"
      "  20:num <- copy 10:&:num/lookup\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: foo: tried to lookup 0 in '20:num <- copy 10:&:num/lookup'\n"
      "error:   called from main: foo null\n"
  );
}

void canonize(reagent& x) {
  if (is_literal(x)) return;
  // Begin canonize(x) Lookups
  while (has_property(x, "lookup"))
    lookup_memory(x);
}

void lookup_memory(reagent& x) {
  if (!x.type || x.type->atom || x.type->left->value != Address_type_ordinal) {
    raise << maybe(current_recipe_name()) << "tried to lookup '" << x.original_string << "' but it isn't an address\n" << end();
    dump_callstack();
    return;
  }
  // compute value
  if (x.value == 0) {
    raise << maybe(current_recipe_name()) << "tried to lookup 0\n" << end();
    dump_callstack();
    return;
  }
  lookup_memory_core(x, /*check_for_null*/true);
}

void lookup_memory_core(reagent& x, bool check_for_null) {
  double address = x.value + /*skip alloc id in address*/1;
  double new_value = get_or_insert(Memory, address);
  trace(Callstack_depth+1, "mem") << "location " << address << " contains " << no_scientific(new_value) << end();
  // check for null
  if (check_for_null && new_value == 0) {
    if (Current_routine) {
      raise << maybe(current_recipe_name()) << "tried to lookup 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
      dump_callstack();
    }
    else {
      raise << "tried to lookup 0\n" << end();
    }
  }
  // validate alloc-id
  double alloc_id_in_address = get_or_insert(Memory, x.value);
  double alloc_id_in_payload = get_or_insert(Memory, new_value);
//?   cerr << x.value << ": " << alloc_id_in_address << " vs " << new_value << ": " << alloc_id_in_payload << '\n';
  if (alloc_id_in_address != alloc_id_in_payload) {
      raise << maybe(current_recipe_name()) << "address is already abandoned in '" << to_original_string(current_instruction()) << "'\n" << end();
      dump_callstack();
  }
  // all well; complete the lookup
  x.set_value(new_value+/*skip alloc id in payload*/1);
  drop_from_type(x, "address");
  drop_one_lookup(x);
}

:(after "Begin types_coercible(reagent to, reagent from)")
if (!canonize_type(to)) return false;
if (!canonize_type(from)) return false;
:(after "Begin types_match(reagent to, reagent from)")
if (!canonize_type(to)) return false;
if (!canonize_type(from)) return false;
:(after "Begin types_strictly_match(reagent to, reagent from)")
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
:(before "End Preprocess is_mu_character(reagent r)")
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

:(code)
bool canonize_type(reagent& r) {
  while (has_property(r, "lookup")) {
    if (!r.type || r.type->atom || !r.type->left || !r.type->left->atom || r.type->left->value != Address_type_ordinal) {
      raise << "cannot perform lookup on '" << r.name << "' because it has non-address type " << to_string(r.type) << '\n' << end();
      return false;
    }
    drop_from_type(r, "address");
    drop_one_lookup(r);
  }
  return true;
}

void drop_one_lookup(reagent& r) {
  for (vector<pair<string, string_tree*> >::iterator p = r.properties.begin();  p != r.properties.end();  ++p) {
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

void test_get_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 94\n"
      "  22:num <- copy 95\n"
      "  30:num <- get 10:&:point/lookup, 0:offset\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 94 in location 30\n"
  );
}

void test_get_indirect2() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 94\n"
      "  22:num <- copy 95\n"
      // skip alloc id for destination
      "  31:num <- copy 40\n"
      "  30:&:num/lookup <- get 10:&:point/lookup, 0:offset\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 94 in location 41\n"
  );
}

void test_include_nonlookup_properties() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 94\n"
      "  22:num <- copy 95\n"
      "  30:num <- get 10:&:point/lookup/foo, 0:offset\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 94 in location 30\n"
  );
}

:(after "Update GET base in Check")
if (!canonize_type(base)) break;
:(after "Update GET product in Check")
if (!canonize_type(product)) break;
:(after "Update GET base in Run")
canonize(base);

:(code)
void test_put_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 94\n"
      "  22:num <- copy 95\n"
      "  10:&:point/lookup <- put 10:&:point/lookup, 0:offset, 96\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 96 in location 21\n"
  );
}

:(after "Update PUT base in Check")
if (!canonize_type(base)) break;
:(after "Update PUT offset in Check")
if (!canonize_type(offset)) break;
:(after "Update PUT base in Run")
canonize(base);

:(code)
void test_put_product_error_with_lookup() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  11:num <- copy 20\n"
      "  21:num <- copy 94\n"
      "  22:num <- copy 95\n"
      "  10:&:point <- put 10:&:point/lookup, x:offset, 96\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: product of 'put' must be first ingredient '10:&:point/lookup', but got '10:&:point'\n"
  );
}

:(before "End PUT Product Checks")
reagent/*copy*/ p = inst.products.at(0);
if (!canonize_type(p)) break;  // error raised elsewhere
reagent/*copy*/ i = inst.ingredients.at(0);
if (!canonize_type(i)) break;  // error raised elsewhere
if (!types_strictly_match(p, i)) {
  raise << maybe(get(Recipe, r).name) << "product of 'put' must be first ingredient '" << inst.ingredients.at(0).original_string << "', but got '" << inst.products.at(0).original_string << "'\n" << end();
  break;
}

:(code)
void test_new_error() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  1:num/raw <- new num:type\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: product of 'new' has incorrect type: '1:num/raw <- new num:type'\n"
  );
}

:(after "Update NEW product in Check")
canonize_type(product);

:(code)
void test_copy_array_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:@:num
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 3\n"  // array length
      "  22:num <- copy 94\n"
      "  23:num <- copy 95\n"
      "  24:num <- copy 96\n"
      "  30:@:num <- copy 10:&:@:num/lookup\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 3 in location 30\n"
      "mem: storing 94 in location 31\n"
      "mem: storing 95 in location 32\n"
      "mem: storing 96 in location 33\n"
  );
}

void test_create_array_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:@:num:3
      "  11:num <- copy 3000\n"
      "  10:&:array:num:3/lookup <- create-array\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 3 in location 3001\n"
  );
}

:(after "Update CREATE_ARRAY product in Check")
if (!canonize_type(product)) break;
:(after "Update CREATE_ARRAY product in Run")
canonize(product);

:(code)
void test_index_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:@:num
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 3\n"  // array length
      "  22:num <- copy 94\n"
      "  23:num <- copy 95\n"
      "  24:num <- copy 96\n"
      "  30:num <- index 10:&:@:num/lookup, 1\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 95 in location 30\n"
  );
}

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

:(code)
void test_put_index_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:@:num
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 3\n"  // array length
      "  22:num <- copy 94\n"
      "  23:num <- copy 95\n"
      "  24:num <- copy 96\n"
      "  10:&:@:num/lookup <- put-index 10:&:@:num/lookup, 1, 97\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 97 in location 23\n"
  );
}

void test_put_index_indirect_2() {
  run(
      "def main [\n"
      "  10:num <- copy 3\n"  // array length
      "  11:num <- copy 94\n"
      "  12:num <- copy 95\n"
      "  13:num <- copy 96\n"
      // skip alloc id for address
      "  21:num <- copy 30\n"
      // skip alloc id for payload
      "  31:num <- copy 1\n"  // index
      "  10:@:num <- put-index 10:@:num, 20:&:num/lookup, 97\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 97 in location 12\n"
  );
}

void test_put_index_product_error_with_lookup() {
  Hide_errors = true;
  run(
      "def main [\n"
      "  11:num <- copy 20\n"
      "  21:num <- copy 3\n"  // array length
      "  22:num <- copy 94\n"
      "  23:num <- copy 95\n"
      "  24:num <- copy 96\n"
      "  10:&:@:num <- put-index 10:&:@:num/lookup, 1, 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: main: product of 'put-index' must be first ingredient '10:&:@:num/lookup', but got '10:&:@:num'\n"
  );
}

:(before "End PUT_INDEX Product Checks")
reagent/*copy*/ p = inst.products.at(0);
if (!canonize_type(p)) break;  // error raised elsewhere
reagent/*copy*/ i = inst.ingredients.at(0);
if (!canonize_type(i)) break;  // error raised elsewhere
if (!types_strictly_match(p, i)) {
  raise << maybe(get(Recipe, r).name) << "product of 'put-index' must be first ingredient '" << inst.ingredients.at(0).original_string << "', but got '" << inst.products.at(0).original_string << "'\n" << end();
  break;
}

:(code)
void test_dilated_reagent_in_static_array() {
  run(
      "def main [\n"
      "  {1: (array (& num) 3)} <- create-array\n"
      "  10:&:num <- new num:type\n"
      "  {1: (array (& num) 3)} <- put-index {1: (array (& num) 3)}, 0, 10:&:num\n"
      "  *10:&:num <- copy 94\n"
      "  20:num <- copy *10:&:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: creating array from 7 locations\n"
      "mem: storing 94 in location 20\n"
  );
}

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

:(code)
void test_length_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:@:num
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 3\n"  // array length
      "  22:num <- copy 94\n"
      "  23:num <- copy 95\n"
      "  24:num <- copy 96\n"
      "  30:num <- length 10:&:array:num/lookup\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 3 in location 30\n"
  );
}

:(before "Update LENGTH array in Check")
if (!canonize_type(array)) break;
:(before "Update LENGTH array in Run")
canonize(array);

:(code)
void test_maybe_convert_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:number-or-point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:number-or-point <- merge 0/number, 94\n"
      "  30:num, 31:bool <- maybe-convert 10:&:number-or-point/lookup, i:variant\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 31\n"
      "mem: storing 94 in location 30\n"
  );
}

void test_maybe_convert_indirect_2() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:number-or-point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:number-or-point <- merge 0/number, 94\n"
      // skip alloc id for 30:&:num
      "  31:num <- copy 40\n"
      "  30:&:num/lookup, 50:bool <- maybe-convert 10:&:number-or-point/lookup, i:variant\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 50\n"
      "mem: storing 94 in location 41\n"
  );
}

void test_maybe_convert_indirect_3() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:number-or-point
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:number-or-point <- merge 0/number, 94\n"
      // skip alloc id for 30:&:bool
      "  31:num <- copy 40\n"
      "  50:num, 30:&:bool/lookup <- maybe-convert 10:&:number-or-point/lookup, i:variant\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 41\n"
      "mem: storing 94 in location 50\n"
  );
}

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

:(code)
void test_merge_exclusive_container_indirect() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:number-or-point
      "  11:num <- copy 20\n"
      "  10:&:number-or-point/lookup <- merge 0/number, 34\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // skip alloc id
      "mem: storing 0 in location 21\n"
      "mem: storing 34 in location 22\n"
  );
}

:(before "Update size_mismatch Check for MERGE(x)
canonize(x);

//: abbreviation for '/lookup': a prefix '*'

:(code)
void test_lookup_abbreviation() {
  run(
      "def main [\n"
      // skip alloc id for 10:&:num
      "  11:num <- copy 20\n"
      // skip alloc id for payload
      "  21:num <- copy 94\n"
      "  30:num <- copy *10:&:num\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "parse: ingredient: {10: (\"&\" \"num\"), \"lookup\": ()}\n"
      "mem: storing 94 in location 30\n"
  );
}

:(before "End Parsing reagent")
{
  while (starts_with(name, "*")) {
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

//: Exclusive containers contain exactly one of a fixed number of 'variants'
//: of different types.
//:
//: They also implicitly contain a tag describing precisely which variant is
//: currently stored in them.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
{
type_ordinal tmp = put(Type_ordinal, "number-or-point", Next_type_ordinal++);
get_or_insert(Type, tmp).size = 2;
get(Type, tmp).kind = EXCLUSIVE_CONTAINER;
get(Type, tmp).name = "number-or-point";
get(Type, tmp).elements.push_back(reagent("i:number"));
get(Type, tmp).elements.push_back(reagent("p:point"));
}

//: Tests in this layer often explicitly setup memory before reading it as an
//: array. Don't do this in general. I'm tagging exceptions with /raw to
//: avoid errors.
:(scenario copy_exclusive_container)
# Copying exclusive containers copies all their contents and an extra location for the tag.
recipe main [
  1:number <- copy 1  # 'point' variant
  2:number <- copy 34
  3:number <- copy 35
  4:number-or-point <- copy 1:number-or-point/unsafe
]
+mem: storing 1 in location 4
+mem: storing 34 in location 5
+mem: storing 35 in location 6

:(before "End size_of(type) Cases")
if (t.kind == EXCLUSIVE_CONTAINER) {
  // size of an exclusive container is the size of its largest variant
  // (So like containers, it can't contain arrays.)
  long long int result = 0;
  for (long long int i = 0; i < t.size; ++i) {
    reagent tmp;
    tmp.type = new type_tree(*type);
    long long int size = size_of(variant_type(tmp, i));
    if (size > result) result = size;
  }
  // ...+1 for its tag.
  return result+1;
}

//:: To access variants of an exclusive container, use 'maybe-convert'.
//: It always returns an address (so that you can modify it) or null (to
//: signal that the conversion failed (because the container contains a
//: different variant).

//: 'maybe-convert' requires a literal in ingredient 1. We'll use a synonym
//: called 'variant'.
:(before "End Mu Types Initialization")
put(Type_ordinal, "variant", 0);

:(scenario maybe_convert)
recipe main [
  12:number <- copy 1
  13:number <- copy 35
  14:number <- copy 36
  20:address:point <- maybe-convert 12:number-or-point/unsafe, 1:variant
]
+mem: storing 13 in location 20

:(scenario maybe_convert_fail)
recipe main [
  12:number <- copy 1
  13:number <- copy 35
  14:number <- copy 36
  20:address:number <- maybe-convert 12:number-or-point/unsafe, 0:variant
]
+mem: storing 0 in location 20

:(before "End Primitive Recipe Declarations")
MAYBE_CONVERT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "maybe-convert", MAYBE_CONVERT);
:(before "End Primitive Recipe Checks")
case MAYBE_CONVERT: {
  const recipe& caller = get(Recipe, r);
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(caller.name) << "'maybe-convert' expects exactly 2 ingredients in '" << to_string(inst) << "'\n" << end();
    break;
  }
  reagent base = inst.ingredients.at(0);
  canonize_type(base);
  if (!base.type || !base.type->value || get(Type, base.type->value).kind != EXCLUSIVE_CONTAINER) {
    raise_error << maybe(caller.name) << "first ingredient of 'maybe-convert' should be an exclusive-container, but got " << base.original_string << '\n' << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(1))) {
    raise_error << maybe(caller.name) << "second ingredient of 'maybe-convert' should have type 'variant', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  if (inst.products.empty()) break;
  reagent product = inst.products.at(0);
  if (!canonize_type(product)) break;
  reagent& offset = inst.ingredients.at(1);
  populate_value(offset);
  if (offset.value >= SIZE(get(Type, base.type->value).elements)) {
    raise_error << maybe(caller.name) << "invalid tag " << offset.value << " in '" << to_string(inst) << '\n' << end();
    break;
  }
  reagent variant = variant_type(base, offset.value);
  variant.type = new type_tree("address", get(Type_ordinal, "address"), variant.type);
  if (!types_coercible(product, variant)) {
    raise_error << maybe(caller.name) << "'maybe-convert " << base.original_string << ", " << inst.ingredients.at(1).original_string << "' should write to " << to_string(variant.type) << " but " << product.name << " has type " << to_string(product.type) << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case MAYBE_CONVERT: {
  reagent base = current_instruction().ingredients.at(0);
  canonize(base);
  long long int base_address = base.value;
  if (base_address == 0) {
    raise_error << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  long long int tag = current_instruction().ingredients.at(1).value;
  long long int result;
  if (tag == static_cast<long long int>(get_or_insert(Memory, base_address))) {
    result = base_address+1;
  }
  else {
    result = 0;
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(code)
const reagent variant_type(const reagent& canonized_base, long long int tag) {
  assert(tag >= 0);
  assert(contains_key(Type, canonized_base.type->value));
  assert(!get(Type, canonized_base.type->value).name.empty());
  const type_info& info = get(Type, canonized_base.type->value);
  assert(info.kind == EXCLUSIVE_CONTAINER);
  reagent element = info.elements.at(tag);
  // End variant_type Special-cases
  return element;
}

:(scenario maybe_convert_product_type_mismatch)
% Hide_errors = true;
recipe main [
  12:number <- copy 1
  13:number <- copy 35
  14:number <- copy 36
  20:address:number <- maybe-convert 12:number-or-point/unsafe, 1:variant
]
+error: main: 'maybe-convert 12:number-or-point/unsafe, 1:variant' should write to (address point) but 20 has type (address number)

//:: Allow exclusive containers to be defined in mu code.

:(scenario exclusive_container)
exclusive-container foo [
  x:number
  y:number
]
+parse: --- defining exclusive-container foo
+parse: element: x: "number"
+parse: element: y: "number"

:(before "End Command Handlers")
else if (command == "exclusive-container") {
  insert_container(command, EXCLUSIVE_CONTAINER, in);
}

//: arrays are disallowed inside exclusive containers unless their length is
//: fixed in advance

:(scenario exclusive_container_contains_array)
exclusive-container foo [
  x:array:number:3
]
$error: 0

:(scenario exclusive_container_disallows_dynamic_array_element)
% Hide_errors = true;
exclusive-container foo [
  x:array:number
]
+error: container 'foo' cannot determine size of element x

//:: To construct exclusive containers out of variant types, use 'merge'.
:(scenario lift_to_exclusive_container)
exclusive-container foo [
  x:number
  y:number
]

recipe main [
  1:number <- copy 34
  2:foo <- merge 0/x, 1:number  # tag must be a literal when merging exclusive containers
  4:foo <- merge 1/y, 1:number
]
+mem: storing 0 in location 2
+mem: storing 34 in location 3
+mem: storing 1 in location 4
+mem: storing 34 in location 5

//: type-checking for 'merge' on exclusive containers

:(scenario merge_handles_exclusive_container)
exclusive-container foo [
  x:number
  y:bar
]
container bar [
  z:number
]
recipe main [
  1:foo <- merge 0/x, 34
]
+mem: storing 0 in location 1
+mem: storing 34 in location 2
$error: 0

:(scenario merge_requires_literal_tag_for_exclusive_container)
% Hide_errors = true;
exclusive-container foo [
  x:number
  y:bar
]
container bar [
  z:number
]
recipe main [
  local-scope
  1:number <- copy 0
  2:foo <- merge 1:number, 34
]
+error: main: ingredient 0 of 'merge' should be a literal, for the tag of exclusive-container foo

:(before "End valid_merge Cases")
case EXCLUSIVE_CONTAINER: {
  assert(state.data.top().container_element_index == 0);
  trace(9999, "transform") << "checking exclusive container " << to_string(container) << " vs ingredient " << ingredient_index << end();
  if (!is_literal(ingredients.at(ingredient_index))) {
    raise_error << maybe(caller.name) << "ingredient " << ingredient_index << " of 'merge' should be a literal, for the tag of exclusive-container " << container_info.name << '\n' << end();
    return;
  }
  reagent ingredient = ingredients.at(ingredient_index);  // unnecessary copy just to keep this function from modifying caller
  populate_value(ingredient);
  if (ingredient.value >= SIZE(container_info.elements)) {
    raise_error << maybe(caller.name) << "invalid tag at " << ingredient_index << " for " << container_info.name << " in '" << to_string(inst) << '\n' << end();
    return;
  }
  reagent variant = variant_type(container, ingredient.value);
  trace(9999, "transform") << "tag: " << ingredient.value << end();
  // replace union with its variant
  state.data.pop();
  state.data.push(merge_check_point(variant, 0));
  ++ingredient_index;
  break;
}

:(scenario merge_check_container_containing_exclusive_container)
container foo [
  x:number
  y:bar
]
exclusive-container bar [
  x:number
  y:number
]
recipe main [
  1:foo <- merge 23, 1/y, 34
]
+mem: storing 23 in location 1
+mem: storing 1 in location 2
+mem: storing 34 in location 3
$error: 0

:(scenario merge_check_container_containing_exclusive_container_2)
% Hide_errors = true;
container foo [
  x:number
  y:bar
]
exclusive-container bar [
  x:number
  y:number
]
recipe main [
  1:foo <- merge 23, 1/y, 34, 35
]
+error: main: too many ingredients in '1:foo <- merge 23, 1/y, 34, 35'

:(scenario merge_check_exclusive_container_containing_container)
exclusive-container foo [
  x:number
  y:bar
]
container bar [
  x:number
  y:number
]
recipe main [
  1:foo <- merge 1/y, 23, 34
]
+mem: storing 1 in location 1
+mem: storing 23 in location 2
+mem: storing 34 in location 3
$error: 0

:(scenario merge_check_exclusive_container_containing_container_2)
exclusive-container foo [
  x:number
  y:bar
]
container bar [
  x:number
  y:number
]
recipe main [
  1:foo <- merge 0/x, 23
]
$error: 0

:(scenario merge_check_exclusive_container_containing_container_3)
% Hide_errors = true;
exclusive-container foo [
  x:number
  y:bar
]
container bar [
  x:number
  y:number
]
recipe main [
  1:foo <- merge 1/y, 23
]
+error: main: too few ingredients in '1:foo <- merge 1/y, 23'

//: Since the different variants of an exclusive-container might have
//: different sizes, relax the size mismatch check for 'merge' instructions.
:(before "End size_mismatch(x) Cases")
if (current_instruction().operation == MERGE
    && !current_instruction().products.empty()
    && current_instruction().products.at(0).type) {
  reagent x = current_instruction().products.at(0);
  canonize(x);
  if (get(Type, x.type->value).kind == EXCLUSIVE_CONTAINER) {
    return size_of(x) < SIZE(data);
  }
}

:(scenario merge_exclusive_container_with_mismatched_sizes)
container foo [
  x:number
  y:number
]

exclusive-container bar [
  x:number
  y:foo
]

recipe main [
  1:number <- copy 34
  2:number <- copy 35
  3:bar <- merge 0/x, 1:number
  6:bar <- merge 1/foo, 1:number, 2:number
]
+mem: storing 0 in location 3
+mem: storing 34 in location 4
# bar is always 3 large so location 5 is skipped
+mem: storing 1 in location 6
+mem: storing 34 in location 7
+mem: storing 35 in location 8

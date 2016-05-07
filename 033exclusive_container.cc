//: Exclusive containers contain exactly one of a fixed number of 'variants'
//: of different types.
//:
//: They also implicitly contain a tag describing precisely which variant is
//: currently stored in them.

:(before "End Mu Types Initialization")
//: We'll use this container as a running example, with two number elements.
{
type_ordinal tmp = put(Type_ordinal, "number-or-point", Next_type_ordinal++);
get_or_insert(Type, tmp);  // initialize
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
def main [
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
  // Compute size_of Exclusive Container
  return get(Container_metadata, type).size;
}
:(before "End compute_container_metadata Cases")
if (info.kind == EXCLUSIVE_CONTAINER) {
  container_metadata metadata;
  // size of an exclusive container is the size of its largest variant
  // (So like containers, it can't contain arrays.)
  int size = 0;
  for (int i = 0; i < SIZE(info.elements); ++i) {
    reagent/*copy*/ element = info.elements.at(i);
    // Compute Exclusive Container Metadata(element)
    compute_container_metadata(element);
    int variant_size = size_of(element);
    if (variant_size > size) size = variant_size;
  }
  // ...+1 for its tag.
  metadata.size = size+1;
  Container_metadata.push_back(pair<type_tree*, container_metadata>(new type_tree(*type), metadata));
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
def main [
  12:number <- copy 1
  13:number <- copy 35
  14:number <- copy 36
  20:point, 22:boolean <- maybe-convert 12:number-or-point/unsafe, 1:variant
]
# boolean
+mem: storing 1 in location 22
# point
+mem: storing 35 in location 20
+mem: storing 36 in location 21

:(scenario maybe_convert_fail)
def main [
  12:number <- copy 1
  13:number <- copy 35
  14:number <- copy 36
  20:number, 21:boolean <- maybe-convert 12:number-or-point/unsafe, 0:variant
]
# boolean
+mem: storing 0 in location 21
# number: no write

:(before "End Primitive Recipe Declarations")
MAYBE_CONVERT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "maybe-convert", MAYBE_CONVERT);
:(before "End Primitive Recipe Checks")
case MAYBE_CONVERT: {
  const recipe& caller = get(Recipe, r);
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(caller.name) << "'maybe-convert' expects exactly 2 ingredients in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  reagent/*copy*/ base = inst.ingredients.at(0);
  // Update MAYBE_CONVERT base in Check
  if (!base.type || !base.type->value || get(Type, base.type->value).kind != EXCLUSIVE_CONTAINER) {
    raise << maybe(caller.name) << "first ingredient of 'maybe-convert' should be an exclusive-container, but got " << base.original_string << '\n' << end();
    break;
  }
  if (!is_literal(inst.ingredients.at(1))) {
    raise << maybe(caller.name) << "second ingredient of 'maybe-convert' should have type 'variant', but got " << inst.ingredients.at(1).original_string << '\n' << end();
    break;
  }
  if (inst.products.empty()) break;
  if (SIZE(inst.products) != 2) {
    raise << maybe(caller.name) << "'maybe-convert' expects exactly 2 products in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  reagent/*copy*/ product = inst.products.at(0);
  // Update MAYBE_CONVERT product in Check
  reagent& offset = inst.ingredients.at(1);
  populate_value(offset);
  if (offset.value >= SIZE(get(Type, base.type->value).elements)) {
    raise << maybe(caller.name) << "invalid tag " << offset.value << " in '" << to_original_string(inst) << '\n' << end();
    break;
  }
  const reagent& variant = variant_type(base, offset.value);
  if (!types_coercible(product, variant)) {
    raise << maybe(caller.name) << "'maybe-convert " << base.original_string << ", " << inst.ingredients.at(1).original_string << "' should write to " << to_string(variant.type) << " but " << product.name << " has type " << to_string(product.type) << '\n' << end();
    break;
  }
  reagent/*copy*/ status = inst.products.at(1);
  // Update MAYBE_CONVERT status in Check
  if (!is_mu_boolean(status)) {
    raise << maybe(get(Recipe, r).name) << "second product yielded by 'maybe-convert' should be a boolean, but tried to write to " << inst.products.at(1).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case MAYBE_CONVERT: {
  reagent/*copy*/ base = current_instruction().ingredients.at(0);
  // Update MAYBE_CONVERT base in Run
  int base_address = base.value;
  if (base_address == 0) {
    raise << maybe(current_recipe_name()) << "tried to access location 0 in '" << to_original_string(current_instruction()) << "'\n" << end();
    break;
  }
  int tag = current_instruction().ingredients.at(1).value;
  reagent/*copy*/ product = current_instruction().products.at(0);
  // Update MAYBE_CONVERT product in Run
  reagent/*copy*/ status = current_instruction().products.at(1);
  // Update MAYBE_CONVERT status in Run
  // optimization: directly write results to only update first product when necessary
  if (tag == static_cast<int>(get_or_insert(Memory, base_address))) {
    const reagent& variant = variant_type(base, tag);
    trace(9999, "mem") << "storing 1 in location " << status.value << end();
    put(Memory, status.value, 1);
    // Write Memory in Successful MAYBE_CONVERT in Run
    for (int i = 0; i < size_of(variant); ++i) {
      double val = get_or_insert(Memory, base_address+/*skip tag*/1+i);
      trace(9999, "mem") << "storing " << no_scientific(val) << " in location " << product.value+i << end();
      put(Memory, product.value+i, val);
    }
  }
  else {
    trace(9999, "mem") << "storing 0 in location " << status.value << end();
    put(Memory, status.value, 0);
  }
  goto finish_instruction;
}

:(code)
const reagent variant_type(const reagent& base, int tag) {
  assert(tag >= 0);
  assert(contains_key(Type, base.type->value));
  assert(!get(Type, base.type->value).name.empty());
  const type_info& info = get(Type, base.type->value);
  assert(info.kind == EXCLUSIVE_CONTAINER);
  reagent/*copy*/ element = info.elements.at(tag);
  // End variant_type Special-cases
  return element;
}

:(scenario maybe_convert_product_type_mismatch)
% Hide_errors = true;
def main [
  12:number <- copy 1
  13:number <- copy 35
  14:number <- copy 36
  20:number, 21:boolean <- maybe-convert 12:number-or-point/unsafe, 1:variant
]
+error: main: 'maybe-convert 12:number-or-point/unsafe, 1:variant' should write to point but 20 has type number

//:: Allow exclusive containers to be defined in mu code.

:(scenario exclusive_container)
exclusive-container foo [
  x:number
  y:number
]
+parse: --- defining exclusive-container foo
+parse: element: {x: "number"}
+parse: element: {y: "number"}

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

def main [
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
def main [
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
def main [
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
    raise << maybe(caller.name) << "ingredient " << ingredient_index << " of 'merge' should be a literal, for the tag of exclusive-container " << container_info.name << '\n' << end();
    return;
  }
  reagent/*copy*/ ingredient = ingredients.at(ingredient_index);  // unnecessary copy just to keep this function from modifying caller
  populate_value(ingredient);
  if (ingredient.value >= SIZE(container_info.elements)) {
    raise << maybe(caller.name) << "invalid tag at " << ingredient_index << " for " << container_info.name << " in '" << to_original_string(inst) << '\n' << end();
    return;
  }
  const reagent& variant = variant_type(container, ingredient.value);
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
def main [
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
def main [
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
def main [
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
def main [
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
def main [
  1:foo <- merge 1/y, 23
]
+error: main: too few ingredients in '1:foo <- merge 1/y, 23'

:(scenario merge_check_exclusive_container_containing_container_4)
exclusive-container foo [
  x:number
  y:bar
]
container bar [
  a:number
  b:number
]
def main [
  1:bar <- merge 23, 24
  3:foo <- merge 1/y, 1:bar
]
$error: 0

//: Since the different variants of an exclusive-container might have
//: different sizes, relax the size mismatch check for 'merge' instructions.
:(before "End size_mismatch(x) Cases")
if (current_step_index() < SIZE(Current_routine->steps())
    && current_instruction().operation == MERGE
    && !current_instruction().products.empty()
    && current_instruction().products.at(0).type) {
  reagent/*copy*/ x = current_instruction().products.at(0);
  // Update size_mismatch Check for MERGE(x)
  if (get(Type, x.type->value).kind == EXCLUSIVE_CONTAINER)
    return size_of(x) < SIZE(data);
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
def main [
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

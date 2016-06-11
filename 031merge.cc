//: Construct types out of their constituent fields.

:(scenario merge)
container foo [
  x:number
  y:number
]

def main [
  1:foo <- merge 3, 4
]
+mem: storing 3 in location 1
+mem: storing 4 in location 2

:(before "End Primitive Recipe Declarations")
MERGE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "merge", MERGE);
:(before "End Primitive Recipe Checks")
case MERGE: {
  // type-checking in a separate transform below
  break;
}
:(before "End Primitive Recipe Implementations")
case MERGE: {
  products.resize(1);
  for (int i = 0; i < SIZE(ingredients); ++i)
    for (int j = 0; j < SIZE(ingredients.at(i)); ++j)
      products.at(0).push_back(ingredients.at(i).at(j));
  break;
}

//: type-check 'merge' to avoid interpreting numbers as addresses

:(scenario merge_check)
def main [
  1:point <- merge 3, 4
]
$error: 0

:(scenario merge_check_missing_element)
% Hide_errors = true;
def main [
  1:point <- merge 3
]
+error: main: too few ingredients in '1:point <- merge 3'

:(scenario merge_check_extra_element)
% Hide_errors = true;
def main [
  1:point <- merge 3, 4, 5
]
+error: main: too many ingredients in '1:point <- merge 3, 4, 5'

//: We want to avoid causing memory corruption, but other than that we want to
//: be flexible in how we construct containers of containers. It should be
//: equally easy to define a container out of primitives or intermediate
//: container fields.

:(scenario merge_check_recursive_containers)
def main [
  1:point <- merge 3, 4
  1:point-number <- merge 1:point, 5
]
$error: 0

:(scenario merge_check_recursive_containers_2)
% Hide_errors = true;
def main [
  1:point <- merge 3, 4
  2:point-number <- merge 1:point
]
+error: main: too few ingredients in '2:point-number <- merge 1:point'

:(scenario merge_check_recursive_containers_3)
def main [
  1:point-number <- merge 3, 4, 5
]
$error: 0

:(scenario merge_check_recursive_containers_4)
% Hide_errors = true;
def main [
  1:point-number <- merge 3, 4
]
+error: main: too few ingredients in '1:point-number <- merge 3, 4'

:(scenario merge_check_reflexive)
% Hide_errors = true;
def main [
  1:point <- merge 3, 4
  2:point <- merge 1:point
]
$error: 0

//: Since a container can be merged in several ways, we need to be able to
//: backtrack through different possibilities. Later we'll allow creating
//: exclusive containers which contain just one of rather than all of their
//: elements. That will also require backtracking capabilities. Here's the
//: state we need to maintain for backtracking:

:(before "End Types")
struct merge_check_point {
  reagent container;
  int container_element_index;
  merge_check_point(const reagent& c, int i) :container(c), container_element_index(i) {}
};

struct merge_check_state {
  stack<merge_check_point> data;
};

:(before "End Checks")
Transform.push_back(check_merge_calls);
:(code)
void check_merge_calls(const recipe_ordinal r) {
  const recipe& caller = get(Recipe, r);
  trace(9991, "transform") << "--- type-check merge instructions in recipe " << caller.name << end();
  for (int i = 0; i < SIZE(caller.steps); ++i) {
    const instruction& inst = caller.steps.at(i);
    if (inst.name != "merge") continue;
    if (SIZE(inst.products) != 1) {
      raise << maybe(caller.name) << "'merge' should yield a single product in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    reagent/*copy*/ product = inst.products.at(0);
    // Update product While Type-checking Merge
    type_ordinal product_type = product.type->value;
    if (product_type == 0 || !contains_key(Type, product_type)) {
      raise << maybe(caller.name) << "'merge' should yield a container in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    const type_info& info = get(Type, product_type);
    if (info.kind != CONTAINER && info.kind != EXCLUSIVE_CONTAINER) {
      raise << maybe(caller.name) << "'merge' should yield a container in '" << to_original_string(inst) << "'\n" << end();
      continue;
    }
    check_merge_call(inst.ingredients, product, caller, inst);
  }
}

void check_merge_call(const vector<reagent>& ingredients, const reagent& product, const recipe& caller, const instruction& inst) {
  int ingredient_index = 0;
  merge_check_state state;
  state.data.push(merge_check_point(product, 0));
  while (true) {
    assert(!state.data.empty());
    trace(9999, "transform") << ingredient_index << " vs " << SIZE(ingredients) << end();
    if (ingredient_index >= SIZE(ingredients)) {
      raise << maybe(caller.name) << "too few ingredients in '" << to_original_string(inst) << "'\n" << end();
      return;
    }
    reagent& container = state.data.top().container;
    type_info& container_info = get(Type, container.type->value);
    switch (container_info.kind) {
      case CONTAINER: {
        // degenerate case: merge with the same type always succeeds
        if (state.data.top().container_element_index == 0 && types_coercible(container, inst.ingredients.at(ingredient_index)))
          return;
        const reagent& expected_ingredient = element_type(container.type, state.data.top().container_element_index);
        trace(9999, "transform") << "checking container " << to_string(container) << " || " << to_string(expected_ingredient) << " vs ingredient " << ingredient_index << end();
        // if the current element is the ingredient we expect, move on to the next element/ingredient
        if (types_coercible(expected_ingredient, ingredients.at(ingredient_index))) {
          ++ingredient_index;
          ++state.data.top().container_element_index;
          while (state.data.top().container_element_index >= SIZE(get(Type, state.data.top().container.type->value).elements)) {
            state.data.pop();
            if (state.data.empty()) {
              if (ingredient_index < SIZE(ingredients))
                raise << maybe(caller.name) << "too many ingredients in '" << to_original_string(inst) << "'\n" << end();
              return;
            }
            ++state.data.top().container_element_index;
          }
        }
        // if not, maybe it's a field of the current element
        else {
          // no change to ingredient_index
          state.data.push(merge_check_point(expected_ingredient, 0));
        }
        break;
      }
      // End check_merge_call Cases
      default: {
        if (!types_coercible(container, ingredients.at(ingredient_index))) {
          raise << maybe(caller.name) << "incorrect type of ingredient " << ingredient_index << " in '" << to_original_string(inst) << "'\n" << end();
          raise << "  (expected '" << debug_string(container) << "')\n" << end();
          raise << "  (got '" << debug_string(ingredients.at(ingredient_index)) << "')\n" << end();
          return;
        }
        ++ingredient_index;
        // ++state.data.top().container_element_index;  // unnecessary, but wouldn't do any harm
        do {
          state.data.pop();
          if (state.data.empty()) {
            if (ingredient_index < SIZE(ingredients))
              raise << maybe(caller.name) << "too many ingredients in '" << to_original_string(inst) << "'\n" << end();
            return;
          }
          ++state.data.top().container_element_index;
        } while (state.data.top().container_element_index >= SIZE(get(Type, state.data.top().container.type->value).elements));
      }
    }
  }
  // never gets here
  assert(false);
}

:(scenario merge_check_product)
% Hide_errors = true;
def main [
  1:number <- merge 3
]
+error: main: 'merge' should yield a container in '1:number <- merge 3'

:(before "End Includes")
#include <stack>
using std::stack;


:(before "End Primitive Recipe Declarations")
RANDOM,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "random", RANDOM);
:(before "End Primitive Recipe Checks")
case RANDOM: {
  break;
}
:(before "End Primitive Recipe Implementations")
case RANDOM: {
  // todo: limited range of numbers, might be imperfectly random
  // todo: thread state in extra ingredients and products
  products.resize(1);
  products.at(0).push_back(rand());
  break;
}

:(before "End Primitive Recipe Declarations")
MAKE_RANDOM_NONDETERMINISTIC,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "make-random-nondeterministic", MAKE_RANDOM_NONDETERMINISTIC);
:(before "End Primitive Recipe Checks")
case MAKE_RANDOM_NONDETERMINISTIC: {
  break;
}
:(before "End Primitive Recipe Implementations")
case MAKE_RANDOM_NONDETERMINISTIC: {
  srand(time(NULL));
  break;
}

:(before "End Primitive Recipe Declarations")
ROUND,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "round", ROUND);
:(before "End Primitive Recipe Checks")
case ROUND: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'round' requires exactly one ingredient, but got " << to_string(inst) << '\n' << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'round' should be a number, but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ROUND: {
  products.resize(1);
  products.at(0).push_back(rint(ingredients.at(0).at(0)));
  break;
}

:(scenario round_to_nearest_integer)
def main [
  1:number <- round 12.2
]
+mem: storing 12 in location 1

:(before "End Includes")
#include<math.h>

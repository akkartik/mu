:(before "End Primitive Recipe Declarations")
RANDOM,
:(before "End Primitive Recipe Numbers")
Recipe_number["random"] = RANDOM;
:(before "End Primitive Recipe Implementations")
case RANDOM: {
  // todo: limited range of numbers, might be imperfectly random
  // todo: thread state in extra ingredients and results
  products.resize(1);
  products.at(0).push_back(rand());
  break;
}

:(before "End Primitive Recipe Declarations")
MAKE_RANDOM_NONDETERMINISTIC,
:(before "End Primitive Recipe Numbers")
Recipe_number["make-random-nondeterministic"] = MAKE_RANDOM_NONDETERMINISTIC;
:(before "End Primitive Recipe Implementations")
case MAKE_RANDOM_NONDETERMINISTIC: {
  srand(time(NULL));
  break;
}

:(before "End Primitive Recipe Declarations")
ROUND,
:(before "End Primitive Recipe Numbers")
Recipe_number["round"] = ROUND;
:(before "End Primitive Recipe Implementations")
case ROUND: {
  assert(scalar(ingredients.at(0)));
  products.resize(1);
  products.at(0).push_back(rint(ingredients.at(0).at(0)));
  break;
}

:(scenario round_to_nearest_integer)
recipe main [
  1:number <- round 12.2
]
+mem: storing 12 in location 1

:(before "End Includes")
#include<math.h>

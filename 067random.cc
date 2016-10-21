:(before "End Primitive Recipe Declarations")
REAL_RANDOM,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "real-random", REAL_RANDOM);
:(before "End Primitive Recipe Checks")
case REAL_RANDOM: {
  break;
}
:(before "End Primitive Recipe Implementations")
case REAL_RANDOM: {
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

// undo non-determinism in later tests
:(before "End Setup")
srand(0);

//: Since different layers all carve out different parts of various namespaces
//: (recipes, memory, etc.) for their own use, there's no previous place where
//: we can lay out the big picture of what uses what. So we'll do that here.
//:
//:: Memory
//:
//: Location 0 - unused (since it can help uncover bugs)
//: Locations 1-999 - reserved for tests
//: Locations 1000 ('Reserved_for_tests') onward - available to the allocator in chunks of size Initial_memory_per_routine.
//:
//:: Recipes
//:
//: 0 - unused (IDLE; do nothing)
//: 1-999 - all fixed code
//: 1000 onwards - reserved for tests, cleared between tests

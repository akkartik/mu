//: Since different layers all carve out different parts of various namespaces
//: (recipes, memory, etc.) for their own use, there's no previous place where
//: we can lay out the big picture of what uses what. So we'll do that here
//: and just have to manually remember to update it when we move boundaries
//: around.
//:
//:: Memory
//:
//: Location 0 - unused (since it can help uncover bugs)
//: Locations 1-899 - reserved for tests
//: Locations 900-999 - reserved for predefined globals in mu scenarios, like keyboard, screen, etc.
:(before "End Setup")
assert(Max_variables_in_scenarios == 900);
//: Locations 1000 ('Reserved_for_tests') onward - available to the allocator in chunks of size Initial_memory_per_routine.
assert(Reserved_for_tests == 1000);

//:: Recipes
//:
//: 0 - unused (IDLE; do nothing)
//: 1-199 - primitives
assert(MAX_PRIMITIVE_RECIPES < 200);
//: 200-999 - defined in .mu files as sequences of primitives
assert(Next_recipe_ordinal == 1000);
//: 1000 onwards - reserved for tests, cleared between tests

//:: Depths for tracing
//:
//: 0 - unused
//: 1-100 - app-level trace statements in mu
//: 101-9998 - call-stack statements (mostly label run)
assert(Initial_callstack_depth == 101);
assert(Max_callstack_depth == 9998);
//: 9999 - intra-instruction lines (mostly label mem)
assert(Primitive_recipe_depth == 9999);

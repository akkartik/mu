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
//: 101-9989 - call-stack statements (mostly label run)
assert(Initial_callstack_depth == 101);
assert(Max_callstack_depth == 9989);
//: 9990-9999 - intra-instruction lines (mostly label mem)

//:: Summary of transforms and their dependencies
//: begin transforms
//:   begin instruction inserting transforms
//:     52 insert fragments
//:      ↳ 52.2 check fragments
//:   ---
//:   end instruction inserting transforms
//:
//:   begin instruction modifying transforms
//:     56.2 check header ingredients
//:      ↳ 56.4 fill in reply ingredients
//:
//:     begin type modifying transforms
//:        ↱ 56.3 deduce types from header
//:       56 check reply instructions against header
//:       48 check types by name
//:     ---
//:       30 check or set invalid containers
//:     end type modifying transforms
//:      ↳ 57 static dispatch
//:   ---
//:     13 update instruction operation
//:     40 transform braces
//:     41 transform labels
//:      ↱ 46 collect surrounding spaces
//:     42 transform names
//:   end instruction modifying transforms
//:
//:   begin checks
//:   ---
//:     21 check instruction
//:     ↳ 43 transform 'new' to 'allocate'
//:   end checks
//: end transforms

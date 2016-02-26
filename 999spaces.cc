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
//:     53 rewrite 'stash' instructions
//:   end instruction inserting transforms
//:
//:   begin instruction modifying transforms
//:     56.2 check header ingredients
//:      ↳ 56.4 fill in reply ingredients
//:     48 check or set types by name
//:
//:     begin type modifying transforms
//:       56.3 deduce types from header
//:     ---
//:       30 check or set invalid containers
//:     end type modifying transforms
//:         ↱ 46 collect surrounding spaces
//:      ↳ 42 transform names
//:         ↳ 57 static dispatch
//:   ---
//:     13 update instruction operation
//:     40 transform braces
//:     41 transform labels
//:   end instruction modifying transforms
//:    ↳ 60 check immutable ingredients
//:
//:   begin checks
//:   ---
//:     21 check instruction
//:     ↳ 61 check indirect calls against header
//:     ↳ 56 check calls against header
//:     ↳ 43 transform 'new' to 'allocate'
//:     30 check merge calls
//:     36 check types of reply instructions
//:     43 check default space
//:     56 check reply instructions against header
//:   end checks
//: end transforms

//:: Summary of type-checking in different phases
//: when dispatching instructions we accept first recipe that:
//:   strictly matches all types
//:   maps literal 0 or literal 1 to boolean for some ingredients
//:   performs some other acceptable type conversion
//:     literal 0 -> address
//:     literal -> character
//: when checking instructions we ensure that types match, and that literals map to some scalar
//:   (address can only map to literal 0)
//:   (boolean can only map to literal 0 or literal 1)
//:     (but conditionals can take any scalar)
//: at runtime we perform no checks

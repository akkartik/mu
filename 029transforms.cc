//: Ordering transforms is a well-known hard problem when building compilers.
//: In our case we also have the additional notion of layers. The ordering of
//: layers can have nothing in common with the ordering of transforms when
//: SubX is tangled and run. This can be confusing for readers, particularly
//: if later layers start inserting transforms at arbitrary points between
//: transforms introduced earlier. Over time adding transforms can get harder
//: and harder, having to meet the constraints of everything that's come
//: before. It's worth thinking about organization up-front so the ordering is
//: easy to hold in our heads, and it's obvious where to add a new transform.
//: Some constraints:
//:
//:   1. Layers force us to build SubX bottom-up; since we want to be able to
//:   build and run SubX after stopping loading at any layer, the overall
//:   organization has to be to introduce primitives before we start using
//:   them.
//:
//:   2. Transforms usually need to be run top-down, converting high-level
//:   representations to low-level ones so that low-level layers can be
//:   oblivious to them.
//:
//:   3. When running we'd often like new representations to be checked before
//:   they are transformed away. The whole reason for new representations is
//:   often to add new kinds of automatic checking for our machine code
//:   programs.
//:
//: Putting these constraints together, we'll use the following broad
//: organization:
//:
//:   a) We'll divide up our transforms into "levels", each level consisting
//:   of multiple transforms, and dealing in some new set of representational
//:   ideas. Levels will be added in reverse order to the one their transforms
//:   will be run in.
//:
//:     To run all transforms:
//:       Load transforms for level n
//:       Load transforms for level n-1
//:       ...
//:       Load transforms for level 2
//:       Run code at level 1
//:
//:   b) *Within* a level we'll usually introduce transforms in the order
//:   they're run in.
//:
//:     To run transforms for level n:
//:       Perform transform of layer l
//:       Perform transform of layer l+1
//:       ...
//:
//:   c) Within a level it's often most natural to introduce a new
//:   representation by showing how it's transformed to the level below. To
//:   make such exceptions more obvious checks usually won't be first-class
//:   transforms; instead code that keeps the program unmodified will run
//:   within transforms before they mutate the program. As an example:
//:
//:     Layer l introduces a transform
//:     Layer l+1 adds precondition checks for the transform
//:
//: This may all seem abstract, but will hopefully make sense over time. The
//: goals are basically to always have a working program after any layer, to
//: have the order of layers make narrative sense, and to order transforms
//: correctly at runtime.

:(before "End One-time Setup")
// Begin Transforms
// End Transforms

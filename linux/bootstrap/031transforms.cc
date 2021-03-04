:(before "End Types")
typedef void (*transform_fn)(program&);
:(before "End Globals")
vector<transform_fn> Transform;

:(before "End transform(program& p)")
for (int t = 0;  t < SIZE(Transform);  ++t)
  (*Transform.at(t))(p);

:(before "End One-time Setup")
// Begin Transforms
// End Transforms

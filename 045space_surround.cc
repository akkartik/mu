//: So far you can have global variables by not setting default-space, and
//: local variables by setting default-space. You can isolate variables
//: between those extremes by creating 'surrounding' spaces.
//:
//: (Surrounding spaces are like lexical scopes in other languages.)

:(scenario surrounding_space)
# location 1 in space 1 refers to the space surrounding the default space, here 20.
recipe main [
  10:number <- copy 5:literal  # pretend array
  20:number <- copy 5:literal  # pretend array
  default-space:address:array:location <- copy 10:literal
  0:address:array:location/names:dummy <- copy 20:literal  # later layers will explain the /names: property
  1:number <- copy 32:literal
  1:number/space:1 <- copy 33:literal
]
# chain space
+mem: storing 20 in location 11
# store to default-space
+mem: storing 32 in location 12
# store to chained space
+mem: storing 33 in location 22

//: If you think of a space as a collection of variables with a common
//: lifetime, surrounding allows managing shorter lifetimes inside a longer
//: one.

:(replace{} "long long int space_base(const reagent& x)")
long long int space_base(const reagent& x) {
//?   cerr << "space_base: " << x.to_string() << '\n'; //? 1
  return space_base(x, space_index(x), Current_routine->calls.front().default_space);
}

long long int space_base(const reagent& x, long long int space_index, long long int base) {
//?   trace("foo") << "base of space " << space_index << '\n'; //? 1
//?   cerr << "space_base sub: " << x.to_string() << '\n'; //? 1
  if (space_index == 0) {
//?     trace("foo") << "base of space " << space_index << " is " << base << '\n'; //? 1
    return base;
  }
//?   trace("foo") << "base of space " << space_index << " is " << Memory[base+1] << '\n'; //? 1
  long long int result = space_base(x, space_index-1, Memory[base+1]);
  return result;
}

long long int space_index(const reagent& x) {
//?   cerr << "space_index: " << x.to_string() << '\n'; //? 1
  for (long long int i = /*skip name:type*/1; i < SIZE(x.properties); ++i) {
    if (x.properties.at(i).first == "space") {
      assert(SIZE(x.properties.at(i).second) == 1);
      return to_integer(x.properties.at(i).second.at(0));
    }
  }
  return 0;
}

:(scenario permit_space_as_variable_name)
recipe main [
  space:number <- copy 0:literal
]

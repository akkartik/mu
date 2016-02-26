//: So far you can have global variables by not setting default-space, and
//: local variables by setting default-space. You can isolate variables
//: between those extremes by creating 'surrounding' spaces.
//:
//: (Surrounding spaces are like lexical scopes in other languages.)

:(scenario surrounding_space)
# location 1 in space 1 refers to the space surrounding the default space, here 20.
recipe main [
  # pretend shared:array:location; in practice we'll use new
  10:number <- copy 0  # refcount
  11:number <- copy 5  # length
  # pretend shared:array:location; in practice we'll use new
  20:number <- copy 0  # refcount
  21:number <- copy 5  # length
  # actual start of this recipe
  default-space:address:shared:array:location <- copy 10/unsafe
  0:address:shared:array:location/names:dummy <- copy 20/unsafe  # later layers will explain the /names: property
  1:number <- copy 32
  1:number/space:1 <- copy 33
]
recipe dummy [  # just for the /names: property above
]
# chain space: 10 + /*skip refcount*/1 + /*skip length*/1
+mem: storing 20 in location 12
# store to default space: 10 + /*skip refcount*/1 + /*skip length*/1 + /*index*/1
+mem: storing 32 in location 13
# store to chained space: /*contents of location 12*/20 + /*skip refcount*/1 + /*skip length*/1 + /*index*/1
+mem: storing 33 in location 23

//: If you think of a space as a collection of variables with a common
//: lifetime, surrounding allows managing shorter lifetimes inside a longer
//: one.

:(replace{} "long long int space_base(const reagent& x)")
long long int space_base(const reagent& x) {
  long long int base = current_call().default_space ? (current_call().default_space+/*skip refcount*/1) : 0;
  return space_base(x, space_index(x), base);
}

long long int space_base(const reagent& x, long long int space_index, long long int base) {
  if (space_index == 0)
    return base;
  long long int result = space_base(x, space_index-1, get_or_insert(Memory, base+/*skip length*/1))+/*skip refcount*/1;
  return result;
}

long long int space_index(const reagent& x) {
  for (long long int i = 0; i < SIZE(x.properties); ++i) {
    if (x.properties.at(i).first == "space") {
      if (!x.properties.at(i).second || x.properties.at(i).second->right)
        raise << maybe(current_recipe_name()) << "/space metadata should take exactly one value in " << x.original_string << '\n' << end();
      return to_integer(x.properties.at(i).second->value);
    }
  }
  return 0;
}

:(scenario permit_space_as_variable_name)
recipe main [
  space:number <- copy 0
]

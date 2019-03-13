//: So far you can have global variables by not setting default-space, and
//: local variables by setting default-space. You can isolate variables
//: between those extremes by creating 'surrounding' spaces.
//:
//: (Surrounding spaces are like lexical scopes in other languages.)

void test_surrounding_space() {
  run(
      // location 2 in space 1 (remember that locations 0 and 1 are reserved in all
      // spaces) refers to the space surrounding the default space, here 20.
      "def main [\n"
         // prepare default-space address
      "  10:num/alloc-id, 11:num <- copy 0, 1000\n"
         // prepare default-space payload
      "  1000:num <- copy 0\n"  // alloc id of payload
      "  1001:num <- copy 5\n"  // length
         // prepare address of chained space
      "  20:num/alloc-id, 21:num <- copy 0, 2000\n"
         // prepare payload of chained space
      "  2000:num <- copy 0\n"  // alloc id of payload
      "  2001:num <- copy 5\n"  // length
         // actual start of this recipe
      "  default-space:space <- copy 10:space\n"
         // later layers will explain the /names: property
      "  0:space/names:dummy <- copy 20:space/raw\n"
      "  2:num <- copy 94\n"
      "  2:num/space:1 <- copy 95\n"
      "]\n"
      "def dummy [\n"  // just for the /names: property above
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      // chain space: 1000 + (alloc id) 1 + (length) 1
      "mem: storing 0 in location 1002\n"
      "mem: storing 2000 in location 1003\n"
      // store to default space: 1000 + (alloc id) 1 + (length) 1 + (index) 2
      "mem: storing 94 in location 1004\n"
      // store to chained space: (contents of location 1003) 2000 + (alloc id) 1 + (length) 1 + (index) 2
      "mem: storing 95 in location 2004\n"
  );
}

//: If you think of a space as a collection of variables with a common
//: lifetime, surrounding allows managing shorter lifetimes inside a longer
//: one.

:(replace{} "int space_base(const reagent& x)")
int space_base(const reagent& x) {
  int base = current_call().default_space ? (current_call().default_space+/*skip alloc id*/1) : 0;
  return space_base(x, space_index(x), base);
}

int space_base(const reagent& x, int space_index, int base) {
  if (space_index == 0)
    return base;
  double chained_space_address = base+/*skip length*/1+/*skip alloc id of chaining slot*/1;
  double chained_space_base = get_or_insert(Memory, chained_space_address) + /*skip alloc id of chained space*/1;
  return space_base(x, space_index-1, chained_space_base);
}

int space_index(const reagent& x) {
  for (int i = 0;  i < SIZE(x.properties);  ++i) {
    if (x.properties.at(i).first == "space") {
      if (!x.properties.at(i).second || x.properties.at(i).second->right)
        raise << maybe(current_recipe_name()) << "/space metadata should take exactly one value in '" << x.original_string << "'\n" << end();
      return to_integer(x.properties.at(i).second->value);
    }
  }
  return 0;
}

:(code)
void test_permit_space_as_variable_name() {
  run(
      "def main [\n"
      "  space:num <- copy 0\n"
      "]\n"
  );
}

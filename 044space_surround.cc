//: So far you can have global variables by not setting default-space, and
//: local variables by setting default-space. You can isolate variables
//: between those extremes by creating 'surrounding' spaces.
//:
//: (Surrounding spaces are like lexical scopes in other languages.)

:(scenario surrounding_space)
# location 1 in space 1 refers to the space surrounding the default space, here 20.
def main [
  # pretend address:array:location; in practice we'll use 'new'
  11:num <- copy 5  # length
  # pretend address:array:location; in practice we'll use 'new"
  21:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 10/unsafe/skip-alloc-id
  #: later layers will explain the /names: property
  0:space/names:dummy <- copy 20/unsafe/skip-alloc-id
  2:num <- copy 32
  2:num/space:1 <- copy 33
]
def dummy [  # just for the /names: property above
]
# write chained space: 10 + (alloc id for default-space) 1 + (length) 1 + (alloc id for chained space) 1
+mem: storing 20 in location 13
# store to inside default space: 10 + (alloc id) 1 + (length) 1 + (index) 2
+mem: storing 32 in location 14
# store to inside chained space: (contents of location 12) 20 + (alloc id) 1 + (length) 1 + (index) 2
+mem: storing 33 in location 24

//: If you think of a space as a collection of variables with a common
//: lifetime, surrounding allows managing shorter lifetimes inside a longer
//: one.

:(replace{} "int space_base(const reagent& x)")
int space_base(const reagent& x) {
  int base = current_call().default_space ? (current_call().default_space+/*skip alloc id*/1) : 0;
  return space_base(x, space_index(x), base);
}

int space_base(const reagent& x, int space_index, int base) {
  trace("space") << "default_space is at location " << base << " with " << space_index << " chained spaces to go" << end();
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

:(scenario permit_space_as_variable_name)
def main [
  space:num <- copy 0
]

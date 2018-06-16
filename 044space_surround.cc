//: So far you can have global variables by not setting default-space, and
//: local variables by setting default-space. You can isolate variables
//: between those extremes by creating 'surrounding' spaces.
//:
//: (Surrounding spaces are like lexical scopes in other languages.)

:(scenario surrounding_space)
# location 1 in space 1 refers to the space surrounding the default space, here 20.
def main [
  # pretend address:array:location; in practice we'll use 'new'
  10:num <- copy 5  # length
  # pretend address:array:location; in practice we'll use 'new"
  20:num <- copy 5  # length
  # actual start of this recipe
  default-space:space <- copy 10/unsafe
  #: later layers will explain the /names: property
  0:space/names:dummy <- copy 20/unsafe
  1:num <- copy 32
  1:num/space:1 <- copy 33
]
def dummy [  # just for the /names: property above
]
# chain space: 10 + (length) 1
+mem: storing 20 in location 11
# store to default space: 10 + (skip length) 1 + (index) 1
+mem: storing 32 in location 12
# store to chained space: (contents of location 12) 20 + (length) 1 + (index) 1
+mem: storing 33 in location 22

//: If you think of a space as a collection of variables with a common
//: lifetime, surrounding allows managing shorter lifetimes inside a longer
//: one.

:(replace{} "int space_base(const reagent& x)")
int space_base(const reagent& x) {
  int base = current_call().default_space ? current_call().default_space : 0;
  return space_base(x, space_index(x), base);
}

int space_base(const reagent& x, int space_index, int base) {
  if (space_index == 0)
    return base;
  return space_base(x, space_index-1, get_or_insert(Memory, base+/*skip length*/1));
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

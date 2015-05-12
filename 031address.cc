//: Instructions can read from addresses pointing at other locations using the
//: 'deref' property.

:(scenario copy_indirect)
recipe main [
  1:address:integer <- copy 2:literal
  2:integer <- copy 34:literal
  # This loads location 1 as an address and looks up *that* location.
  3:integer <- copy 1:address:integer/deref
]
+run: instruction main/2
+mem: location 1 is 2
+mem: location 2 is 34
+mem: storing 34 in location 3

:(before "index_t base = x.value" following "vector<long long int> read_memory(reagent x)")
x = canonize(x);

//: similarly, write to addresses pointing at other locations using the
//: 'deref' property
:(scenario store_indirect)
recipe main [
  1:address:integer <- copy 2:literal
  1:address:integer/deref <- copy 34:literal
]
+run: instruction main/1
+mem: location 1 is 2
+mem: storing 34 in location 2

:(before "index_t base = x.value" following "void write_memory(reagent x, vector<long long int> data)")
x = canonize(x);

:(code)
reagent canonize(reagent x) {
  if (isa_literal(x)) return x;
//?   cout << "canonize\n"; //? 1
  reagent r = x;
//?   cout << x.to_string() << " => " << r.to_string() << '\n'; //? 1
  while (has_property(r, "deref"))
    r = deref(r);
  return r;
}

reagent deref(reagent x) {
//?   cout << "deref: " << x.to_string() << "\n"; //? 2
  static const type_number ADDRESS = Type_number["address"];
  reagent result;
  assert(x.types.at(0) == ADDRESS);

  // compute value
  result.set_value(mu_integer(value(Memory[x.value])));  // address must be a positive integer
  trace("mem") << "location " << x.value << " is " << result.value;

  // populate types
  copy(++x.types.begin(), x.types.end(), inserter(result.types, result.types.begin()));

  // drop-one 'deref'
  index_t i = 0;
  size_t len = x.properties.size();
  for (i = 0; i < len; ++i) {
    if (x.properties.at(i).first == "deref") break;
    result.properties.push_back(x.properties.at(i));
  }
  ++i;  // skip first deref
  for (; i < len; ++i) {
    result.properties.push_back(x.properties.at(i));
  }
  return result;
}

//:: 'get' can read from container address
:(scenario get_indirect)
recipe main [
  1:integer <- copy 2:literal
  2:integer <- copy 34:literal
  3:integer <- copy 35:literal
  4:integer <- get 1:address:point/deref, 0:offset
]
+run: instruction main/3
+run: address to copy is 2
+run: product 0 is 4
+mem: storing 34 in location 4

:(scenario include_nonderef_properties)
recipe main [
  1:integer <- copy 2:literal
  2:integer <- copy 34:literal
  3:integer <- copy 35:literal
  4:integer <- get 1:address:point/deref/foo, 0:offset
]
+run: instruction main/3
+run: address to copy is 2
+run: product 0 is 4
+mem: storing 34 in location 4

:(after "reagent base = " following "case GET:")
base = canonize(base);

:(scenario get_address_indirect)
# 'get' can read from container address
recipe main [
  1:integer <- copy 2:literal
  2:integer <- copy 34:literal
  3:integer <- copy 35:literal
  4:integer <- get-address 1:address:point/deref, 0:offset
]
+run: instruction main/3
+run: address to copy is 2
+run: product 0 is 4

:(after "reagent base = " following "case GET_ADDRESS:")
base = canonize(base);

//:: helpers

:(code)
bool has_property(reagent x, string name) {
  for (index_t i = 0; i < x.properties.size(); ++i) {
    if (x.properties.at(i).first == name) return true;
  }
  return false;
}

vector<string> property(const reagent& r, const string& name) {
  for (index_t p = 0; p != r.properties.size(); ++p) {
    if (r.properties.at(p).first == name)
      return r.properties.at(p).second;
  }
  return vector<string>();
}

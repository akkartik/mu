//: Instructions can read from addresses pointing at other locations using the
//: 'lookup' property.

:(scenario copy_indirect)
recipe main [
  1:address:number <- copy 2
  2:number <- copy 34
  # This loads location 1 as an address and looks up *that* location.
  3:number <- copy 1:address:number/lookup
]
+mem: storing 34 in location 3

:(before "long long int base = x.value" following "vector<double> read_memory(reagent x)")
x = canonize(x);

//: similarly, write to addresses pointing at other locations using the
//: 'lookup' property
:(scenario store_indirect)
recipe main [
  1:address:number <- copy 2
  1:address:number/lookup <- copy 34
]
+mem: storing 34 in location 2

:(before "long long int base = x.value" following "void write_memory(reagent x, vector<double> data)")
x = canonize(x);

:(code)
reagent canonize(reagent x) {
  if (is_literal(x)) return x;
//?   cout << "canonize\n"; //? 1
  reagent r = x;
//?   cout << x.to_string() << " => " << r.to_string() << '\n'; //? 1
  while (has_property(r, "lookup"))
    r = lookup_memory(r);
  return r;
}

reagent lookup_memory(reagent x) {
//?   cout << "lookup_memory: " << x.to_string() << "\n"; //? 2
  static const type_ordinal ADDRESS = Type_ordinal["address"];
  reagent result;
  if (x.types.at(0) != ADDRESS) {
    raise << current_recipe_name() << ": tried to /lookup " << x.original_string << " but it isn't an address\n" << end();
    return result;
  }
  // compute value
  if (x.value == 0) {
    raise << current_recipe_name() << ": tried to /lookup 0\n" << end();
    return result;
  }
  result.set_value(Memory[x.value]);
  trace(Primitive_recipe_depth, "mem") << "location " << x.value << " is " << result.value << end();

  // populate types
  copy(++x.types.begin(), x.types.end(), inserter(result.types, result.types.begin()));

  // drop-one 'lookup'
  long long int i = 0;
  long long int len = SIZE(x.properties);
  for (i = 0; i < len; ++i) {
    if (x.properties.at(i).first == "lookup") break;
    result.properties.push_back(x.properties.at(i));
  }
  ++i;  // skip first lookup
  for (; i < len; ++i) {
    result.properties.push_back(x.properties.at(i));
  }
  return result;
}

//:: 'get' can read from container address
:(scenario get_indirect)
recipe main [
  1:number <- copy 2
  2:number <- copy 34
  3:number <- copy 35
  4:number <- get 1:address:point/lookup, 0:offset
]
+mem: storing 34 in location 4

:(scenario include_nonlookup_properties)
recipe main [
  1:number <- copy 2
  2:number <- copy 34
  3:number <- copy 35
  4:number <- get 1:address:point/lookup/foo, 0:offset
]
+mem: storing 34 in location 4

:(after "reagent base = " following "case GET:")
base = canonize(base);

:(scenario get_address_indirect)
# 'get' can read from container address
recipe main [
  1:number <- copy 2
  2:number <- copy 34
  3:number <- copy 35
  4:number <- get-address 1:address:point/lookup, 0:offset
]
+mem: storing 2 in location 4

:(after "reagent base = " following "case GET_ADDRESS:")
base = canonize(base);

//:: helpers for debugging

:(before "End Primitive Recipe Declarations")
_DUMP,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$dump"] = _DUMP;
:(before "End Primitive Recipe Implementations")
case _DUMP: {
  reagent after_canonize = canonize(current_instruction().ingredients.at(0));
  cerr << current_recipe_name() << ": " << current_instruction().ingredients.at(0).name << ' ' << current_instruction().ingredients.at(0).value << " => " << after_canonize.value << " => " << Memory[after_canonize.value] << '\n';
  break;
}

//: grab an address, and then dump its value at intervals
//: useful for tracking down memory corruption (writing to an out-of-bounds address)
:(before "End Globals")
long long int foo = -1;
:(before "End Primitive Recipe Declarations")
_FOO,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$foo"] = _FOO;
:(before "End Primitive Recipe Implementations")
case _FOO: {
  if (current_instruction().ingredients.empty()) {
    if (foo != -1) cerr << foo << ": " << Memory[foo] << '\n';
    else cerr << '\n';
  }
  else {
    foo = canonize(current_instruction().ingredients.at(0)).value;
  }
  break;
}

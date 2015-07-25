//: Instructions can read from addresses pointing at other locations using the
//: 'deref' property.

:(scenario copy_indirect)
recipe main [
  1:address:number <- copy 2:literal
  2:number <- copy 34:literal
  # This loads location 1 as an address and looks up *that* location.
  3:number <- copy 1:address:number/deref
]
+mem: storing 34 in location 3

:(before "long long int base = x.value" following "vector<double> read_memory(reagent x)")
x = canonize(x);

//: similarly, write to addresses pointing at other locations using the
//: 'deref' property
:(scenario store_indirect)
recipe main [
  1:address:number <- copy 2:literal
  1:address:number/deref <- copy 34:literal
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
  while (has_property(r, "deref"))
    r = deref(r);
  return r;
}

reagent deref(reagent x) {
//?   cout << "deref: " << x.to_string() << "\n"; //? 2
  static const type_ordinal ADDRESS = Type_ordinal["address"];
  reagent result;
  assert(x.types.at(0) == ADDRESS);

  // compute value
  result.set_value(Memory[x.value]);
  trace(Primitive_recipe_depth, "mem") << "location " << x.value << " is " << result.value;

  // populate types
  copy(++x.types.begin(), x.types.end(), inserter(result.types, result.types.begin()));

  // drop-one 'deref'
  long long int i = 0;
  long long int len = SIZE(x.properties);
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
  1:number <- copy 2:literal
  2:number <- copy 34:literal
  3:number <- copy 35:literal
  4:number <- get 1:address:point/deref, 0:offset
]
+mem: storing 34 in location 4

:(scenario include_nonderef_properties)
recipe main [
  1:number <- copy 2:literal
  2:number <- copy 34:literal
  3:number <- copy 35:literal
  4:number <- get 1:address:point/deref/foo, 0:offset
]
+mem: storing 34 in location 4

:(after "reagent base = " following "case GET:")
base = canonize(base);

:(scenario get_address_indirect)
# 'get' can read from container address
recipe main [
  1:number <- copy 2:literal
  2:number <- copy 34:literal
  3:number <- copy 35:literal
  4:number <- get-address 1:address:point/deref, 0:offset
]
+mem: storing 2 in location 4

:(after "reagent base = " following "case GET_ADDRESS:")
base = canonize(base);

//:: Helpers for debugging

:(before "End Primitive Recipe Declarations")
_DUMP_TRACE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$dump-trace"] = _DUMP_TRACE;
:(before "End Primitive Recipe Implementations")
case _DUMP_TRACE: {
  if (ingredients.empty()) {
    DUMP("");
  }
  else {
    DUMP(current_instruction().ingredients.at(0).name);
  }
  break;
}

:(before "End Primitive Recipe Declarations")
_CLEAR_TRACE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$clear-trace"] = _CLEAR_TRACE;
:(before "End Primitive Recipe Implementations")
case _CLEAR_TRACE: {
  CLEAR_TRACE;
  break;
}

:(before "End Primitive Recipe Declarations")
_DUMP_MEMORY,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$dump-memory"] = _DUMP_MEMORY;
:(before "End Primitive Recipe Implementations")
case _DUMP_MEMORY: {
  dump_memory();
  break;
}

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

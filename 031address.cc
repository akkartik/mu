//: Instructions can read from addresses pointing at other locations using the
//: 'lookup' property.

:(scenario copy_indirect)
recipe main [
  1:address:number <- copy 2/raw
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
  1:address:number <- copy 2/raw
  1:address:number/lookup <- copy 34
]
+mem: storing 34 in location 2

:(before "long long int base = x.value" following "void write_memory(reagent x, vector<double> data)")
x = canonize(x);
if (x.value == 0) {
  raise << "can't write to location 0 in '" << current_instruction().to_string() << "'\n" << end();
  return;
}

//: writes to address 0 always loudly fail
:(scenario store_to_0_warns)
% Hide_warnings = true;
recipe main [
  1:address:number <- copy 0
  1:address:number/lookup <- copy 34
]
-mem: storing 34 in location 0
+warn: can't write to location 0 in '1:address:number/lookup <- copy 34'

:(code)
reagent canonize(reagent x) {
  if (is_literal(x)) return x;
  reagent r = x;
  while (has_property(r, "lookup"))
    r = lookup_memory(r);
  return r;
}

reagent lookup_memory(reagent x) {
  static const type_ordinal ADDRESS = Type_ordinal["address"];
  reagent result;
  if (x.types.empty() || x.types.at(0) != ADDRESS) {
    raise << maybe(current_recipe_name()) << "tried to /lookup " << x.original_string << " but it isn't an address\n" << end();
    return result;
  }
  // compute value
  if (x.value == 0) {
    raise << maybe(current_recipe_name()) << "tried to /lookup 0\n" << end();
    return result;
  }
  result.set_value(Memory[x.value]);
  trace(Primitive_recipe_depth, "mem") << "location " << x.value << " is " << no_scientific(result.value) << end();

  // populate types
  copy(++x.types.begin(), x.types.end(), inserter(result.types, result.types.begin()));

  // drop one 'lookup'
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

:(after "bool types_match(reagent lhs, reagent rhs)")
  if (!canonize_type(lhs)) return false;
  if (!canonize_type(rhs)) return false;

:(after "bool is_mu_array(reagent r)")
  if (!canonize_type(r)) return false;

:(after "bool is_mu_address(reagent r)")
  if (!canonize_type(r)) return false;

:(after "bool is_mu_number(reagent r)")
  if (!canonize_type(r)) return false;

:(code)
bool canonize_type(reagent& r) {
  while (has_property(r, "lookup")) {
    if (r.types.empty()) {
      raise << "can't lookup non-address: " << r.original_string << '\n' << end();
      return false;
    }
    if (r.types.at(0) != Type_ordinal["address"]) {
      raise << "can't lookup non-address: " << r.original_string << '\n' << end();
      return false;
    }
    r.types.erase(r.types.begin());
    drop_one_lookup(r);
  }
  return true;
}

void drop_one_lookup(reagent& r) {
  for (vector<pair<string, vector<string> > >::iterator p = r.properties.begin(); p != r.properties.end(); ++p) {
    if (p->first == "lookup") {
      r.properties.erase(p);
      return;
    }
  }
  assert(false);
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

//:: abbreviation for '/lookup': a prefix '*'

:(scenario lookup_abbreviation)
recipe main [
  1:address:number <- copy 2/raw
  2:number <- copy 34
  3:number <- copy *1:address:number
]
+mem: storing 34 in location 3

:(before "End Parsing reagent")
{
  while (!name.empty() && name.at(0) == '*') {
    name.erase(0, 1);
    properties.push_back(pair<string, vector<string> >("lookup", vector<string>()));
  }
  if (name.empty())
    raise << "illegal name " << original_string << '\n' << end();
}

//:: helpers for debugging

:(before "End Primitive Recipe Declarations")
_DUMP,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["$dump"] = _DUMP;
:(before "End Primitive Recipe Implementations")
case _DUMP: {
  reagent after_canonize = canonize(current_instruction().ingredients.at(0));
  cerr << maybe(current_recipe_name()) << "" << current_instruction().ingredients.at(0).name << ' ' << no_scientific(current_instruction().ingredients.at(0).value) << " => " << no_scientific(after_canonize.value) << " => " << no_scientific(Memory[after_canonize.value]) << '\n';
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
    if (foo != -1) cerr << foo << ": " << no_scientific(Memory[foo]) << '\n';
    else cerr << '\n';
  }
  else {
    foo = canonize(current_instruction().ingredients.at(0)).value;
  }
  break;
}

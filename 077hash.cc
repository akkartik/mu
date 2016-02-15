// From http://burtleburtle.net/bob/hash/hashfaq.html
:(before "End Primitive Recipe Declarations")
HASH,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "hash", HASH);
:(before "End Primitive Recipe Checks")
case HASH: {
  if (SIZE(inst.ingredients) != 1) {
    raise_error << maybe(get(Recipe, r).name) << "'hash' takes exactly one ingredient rather than '" << inst.to_string() << "'\n" << end();
    break;
  }
  if (!is_mu_string(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'hash' currently only supports strings (address:shared:array:character), but got " << inst.ingredients.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case HASH: {
  string input = read_mu_string(ingredients.at(0).at(0));
  size_t h = 0 ;

  for (long long int i = 0; i < SIZE(input); ++i) {
    h += static_cast<size_t>(input.at(i));
    h += (h<<10);
    h ^= (h>>6);

    h += (h<<3);
    h ^= (h>>11);
    h += (h<<15);
  }

  products.resize(1);
  products.at(0).push_back(h);
  break;
}

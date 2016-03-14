//: Boolean primitives

:(before "End Primitive Recipe Declarations")
AND,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "and", AND);
:(before "End Primitive Recipe Checks")
case AND: {
  for (int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (!is_mu_scalar(inst.ingredients.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'and' requires boolean ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise << maybe(get(Recipe, r).name) << "'and' yields exactly one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_boolean(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'and' should yield a boolean, but got " << inst.products.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case AND: {
  bool result = true;
  for (int i = 0; i < SIZE(ingredients); ++i)
    result = result && ingredients.at(i).at(0);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario and)
def main [
  1:boolean <- copy 1
  2:boolean <- copy 0
  3:boolean <- and 1:boolean, 2:boolean
]
+mem: storing 0 in location 3

:(scenario and_2)
def main [
  1:boolean <- and 1, 1
]
+mem: storing 1 in location 1

:(scenario and_multiple)
def main [
  1:boolean <- and 1, 1, 0
]
+mem: storing 0 in location 1

:(scenario and_multiple_2)
def main [
  1:boolean <- and 1, 1, 1
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
OR,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "or", OR);
:(before "End Primitive Recipe Checks")
case OR: {
  for (int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (!is_mu_scalar(inst.ingredients.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'and' requires boolean ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise << maybe(get(Recipe, r).name) << "'or' yields exactly one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_boolean(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'or' should yield a boolean, but got " << inst.products.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case OR: {
  bool result = false;
  for (int i = 0; i < SIZE(ingredients); ++i)
    result = result || ingredients.at(i).at(0);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario or)
def main [
  1:boolean <- copy 1
  2:boolean <- copy 0
  3:boolean <- or 1:boolean, 2:boolean
]
+mem: storing 1 in location 3

:(scenario or_2)
def main [
  1:boolean <- or 0, 0
]
+mem: storing 0 in location 1

:(scenario or_multiple)
def main [
  1:boolean <- and 0, 0, 0
]
+mem: storing 0 in location 1

:(scenario or_multiple_2)
def main [
  1:boolean <- or 0, 0, 1
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
NOT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "not", NOT);
:(before "End Primitive Recipe Checks")
case NOT: {
  if (SIZE(inst.products) > SIZE(inst.ingredients)) {
    raise << maybe(get(Recipe, r).name) << "'not' cannot have fewer ingredients than products in '" << to_string(inst) << "'\n" << end();
    break;
  }
  for (int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (!is_mu_scalar(inst.ingredients.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'not' requires boolean ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  for (int i = 0; i < SIZE(inst.products); ++i) {
    if (is_dummy(inst.products.at(i))) continue;
    if (!is_mu_boolean(inst.products.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'not' should yield a boolean, but got " << inst.products.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case NOT: {
  products.resize(SIZE(ingredients));
  for (int i = 0; i < SIZE(ingredients); ++i) {
    products.at(i).push_back(!ingredients.at(i).at(0));
  }
  break;
}

:(scenario not)
def main [
  1:boolean <- copy 1
  2:boolean <- not 1:boolean
]
+mem: storing 0 in location 2

:(scenario not_multiple)
def main [
  1:boolean, 2:boolean, 3:boolean <- not 1, 0, 1
]
+mem: storing 0 in location 1
+mem: storing 1 in location 2
+mem: storing 0 in location 3

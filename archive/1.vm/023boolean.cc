//: Boolean primitives

:(before "End Primitive Recipe Declarations")
AND,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "and", AND);
:(before "End Primitive Recipe Checks")
case AND: {
  for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
    if (!is_mu_scalar(inst.ingredients.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'and' requires boolean ingredients, but got '" << inst.ingredients.at(i).original_string << "'\n" << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise << maybe(get(Recipe, r).name) << "'and' yields exactly one product in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_boolean(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'and' should yield a boolean, but got '" << inst.products.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case AND: {
  bool result = true;
  for (int i = 0;  i < SIZE(ingredients);  ++i)
    result = result && scalar_ingredient(ingredients, i);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}
:(code)
double scalar_ingredient(const vector<vector<double> >& ingredients, int i) {
  if (is_mu_address(current_instruction().ingredients.at(i)))
    return ingredients.at(i).at(/*skip alloc id*/1);
  return ingredients.at(i).at(0);
}

void test_and() {
  run(
      "def main [\n"
      "  1:bool <- copy true\n"
      "  2:bool <- copy false\n"
      "  3:bool <- and 1:bool, 2:bool\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 3\n"
  );
}

void test_and_2() {
  run(
      "def main [\n"
      "  1:bool <- and true, true\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 1\n"
  );
}

void test_and_multiple() {
  run(
      "def main [\n"
      "  1:bool <- and true, true, false\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 1\n"
  );
}

void test_and_multiple_2() {
  run(
      "def main [\n"
      "  1:bool <- and true, true, true\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 1\n"
  );
}

:(before "End Primitive Recipe Declarations")
OR,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "or", OR);
:(before "End Primitive Recipe Checks")
case OR: {
  for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
    if (!is_mu_scalar(inst.ingredients.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'and' requires boolean ingredients, but got '" << inst.ingredients.at(i).original_string << "'\n" << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise << maybe(get(Recipe, r).name) << "'or' yields exactly one product in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_boolean(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "'or' should yield a boolean, but got '" << inst.products.at(0).original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case OR: {
  bool result = false;
  for (int i = 0;  i < SIZE(ingredients);  ++i)
    result = result || scalar_ingredient(ingredients, i);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(code)
void test_or() {
  run(
      "def main [\n"
      "  1:bool <- copy true\n"
      "  2:bool <- copy false\n"
      "  3:bool <- or 1:bool, 2:bool\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 3\n"
  );
}

void test_or_2() {
  run(
      "def main [\n"
      "  1:bool <- or false, false\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 1\n"
  );
}

void test_or_multiple() {
  run(
      "def main [\n"
      "  1:bool <- or false, false, false\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 1\n"
  );
}

void test_or_multiple_2() {
  run(
      "def main [\n"
      "  1:bool <- or false, false, true\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 1 in location 1\n"
  );
}

:(before "End Primitive Recipe Declarations")
NOT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "not", NOT);
:(before "End Primitive Recipe Checks")
case NOT: {
  if (SIZE(inst.products) != SIZE(inst.ingredients)) {
    raise << "ingredients and products should match in '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
    if (!is_mu_scalar(inst.ingredients.at(i)) && !is_mu_address(inst.ingredients.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'not' requires ingredients that can be interpreted as boolean, but got '" << inst.ingredients.at(i).original_string << "'\n" << end();
      goto finish_checking_instruction;
    }
  }
  for (int i = 0;  i < SIZE(inst.products);  ++i) {
    if (is_dummy(inst.products.at(i))) continue;
    if (!is_mu_boolean(inst.products.at(i))) {
      raise << maybe(get(Recipe, r).name) << "'not' should yield a boolean, but got '" << inst.products.at(i).original_string << "'\n" << end();
      goto finish_checking_instruction;
    }
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case NOT: {
  products.resize(SIZE(ingredients));
  for (int i = 0;  i < SIZE(ingredients);  ++i) {
    products.at(i).push_back(!scalar_ingredient(ingredients, i));
  }
  break;
}

:(code)
void test_not() {
  run(
      "def main [\n"
      "  1:bool <- copy true\n"
      "  2:bool <- not 1:bool\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 2\n"
  );
}

void test_not_multiple() {
  run(
      "def main [\n"
      "  1:bool, 2:bool, 3:bool <- not true, false, true\n"
      "]\n"
  );
  CHECK_TRACE_CONTENTS(
      "mem: storing 0 in location 1\n"
      "mem: storing 1 in location 2\n"
      "mem: storing 0 in location 3\n"
  );
}

//: Boolean primitives

:(before "End Primitive Recipe Declarations")
AND,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["and"] = AND;
:(before "End Primitive Recipe Implementations")
case AND: {
  bool result = true;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    if (!scalar(ingredients.at(i))) {
      raise << current_recipe_name() << ": 'and' requires boolean ingredients, but got " << current_instruction().ingredients.at(i).original_string << '\n' << end();
      goto finish_instruction;
    }
    result = result && ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario and)
recipe main [
  1:boolean <- copy 1
  2:boolean <- copy 0
  3:boolean <- and 1:boolean, 2:boolean
]
+mem: storing 0 in location 3

:(scenario and_2)
recipe main [
  1:boolean <- and 1, 1
]
+mem: storing 1 in location 1

:(scenario and_multiple)
recipe main [
  1:boolean <- and 1, 1, 0
]
+mem: storing 0 in location 1

:(scenario and_multiple_2)
recipe main [
  1:boolean <- and 1, 1, 1
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
OR,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["or"] = OR;
:(before "End Primitive Recipe Implementations")
case OR: {
  bool result = false;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    if (!scalar(ingredients.at(i))) {
      raise << current_recipe_name() << ": 'or' requires boolean ingredients, but got " << current_instruction().ingredients.at(i).original_string << '\n' << end();
      goto finish_instruction;
    }
    result = result || ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario or)
recipe main [
  1:boolean <- copy 1
  2:boolean <- copy 0
  3:boolean <- or 1:boolean, 2:boolean
]
+mem: storing 1 in location 3

:(scenario or_2)
recipe main [
  1:boolean <- or 0, 0
]
+mem: storing 0 in location 1

:(scenario or_multiple)
recipe main [
  1:boolean <- and 0, 0, 0
]
+mem: storing 0 in location 1

:(scenario or_multiple_2)
recipe main [
  1:boolean <- or 0, 0, 1
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
NOT,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["not"] = NOT;
:(before "End Primitive Recipe Implementations")
case NOT: {
  products.resize(SIZE(ingredients));
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    if (!scalar(ingredients.at(i))) {
      raise << current_recipe_name() << ": 'not' requires boolean ingredients, but got " << current_instruction().ingredients.at(i).original_string << '\n' << end();
      goto finish_instruction;
    }
    products.at(i).push_back(!ingredients.at(i).at(0));
  }
  break;
}

:(scenario not)
recipe main [
  1:boolean <- copy 1
  2:boolean <- not 1:boolean
]
+mem: storing 0 in location 2

:(scenario not_multiple)
recipe main [
  1:boolean, 2:boolean, 3:boolean <- not 1, 0, 1
]
+mem: storing 0 in location 1
+mem: storing 1 in location 2
+mem: storing 0 in location 3

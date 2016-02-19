//: Arithmetic primitives

:(before "End Primitive Recipe Declarations")
ADD,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "add", ADD);
:(before "End Primitive Recipe Checks")
case ADD: {
  // primary goal of these checks is to forbid address arithmetic
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (!is_mu_number(inst.ingredients.at(i))) {
      raise_error << maybe(get(Recipe, r).name) << "'add' requires number ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'add' yields exactly one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'add' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case ADD: {
  double result = 0;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    result += ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario add_literal)
recipe main [
  1:number <- add 23, 34
]
+mem: storing 57 in location 1

:(scenario add)
recipe main [
  1:number <- copy 23
  2:number <- copy 34
  3:number <- add 1:number, 2:number
]
+mem: storing 57 in location 3

:(scenario add_multiple)
recipe main [
  1:number <- add 3, 4, 5
]
+mem: storing 12 in location 1

:(scenario add_checks_type)
% Hide_errors = true;
recipe main [
  1:number <- add 2:boolean, 1
]
+error: main: 'add' requires number ingredients, but got 2:boolean

:(scenario add_checks_return_type)
% Hide_errors = true;
recipe main [
  1:address:number <- add 2, 2
]
+error: main: 'add' should yield a number, but got 1:address:number

:(before "End Primitive Recipe Declarations")
SUBTRACT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "subtract", SUBTRACT);
:(before "End Primitive Recipe Checks")
case SUBTRACT: {
  if (inst.ingredients.empty()) {
    raise_error << maybe(get(Recipe, r).name) << "'subtract' has no ingredients\n" << end();
    break;
  }
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (is_raw(inst.ingredients.at(i))) continue;  // permit address offset computations in tests
    if (!is_mu_number(inst.ingredients.at(i))) {
      raise_error << maybe(get(Recipe, r).name) << "'subtract' requires number ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'subtract' yields exactly one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'subtract' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case SUBTRACT: {
  double result = ingredients.at(0).at(0);
  for (long long int i = 1; i < SIZE(ingredients); ++i)
    result -= ingredients.at(i).at(0);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}
:(code)
bool is_raw(const reagent& r) {
  return has_property(r, "raw");
}

:(scenario subtract_literal)
recipe main [
  1:number <- subtract 5, 2
]
+mem: storing 3 in location 1

:(scenario subtract)
recipe main [
  1:number <- copy 23
  2:number <- copy 34
  3:number <- subtract 1:number, 2:number
]
+mem: storing -11 in location 3

:(scenario subtract_multiple)
recipe main [
  1:number <- subtract 6, 3, 2
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
MULTIPLY,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "multiply", MULTIPLY);
:(before "End Primitive Recipe Checks")
case MULTIPLY: {
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (!is_mu_number(inst.ingredients.at(i))) {
      raise_error << maybe(get(Recipe, r).name) << "'multiply' requires number ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'multiply' yields exactly one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'multiply' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case MULTIPLY: {
  double result = 1;
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    result *= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario multiply_literal)
recipe main [
  1:number <- multiply 2, 3
]
+mem: storing 6 in location 1

:(scenario multiply)
recipe main [
  1:number <- copy 4
  2:number <- copy 6
  3:number <- multiply 1:number, 2:number
]
+mem: storing 24 in location 3

:(scenario multiply_multiple)
recipe main [
  1:number <- multiply 2, 3, 4
]
+mem: storing 24 in location 1

:(before "End Primitive Recipe Declarations")
DIVIDE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "divide", DIVIDE);
:(before "End Primitive Recipe Checks")
case DIVIDE: {
  if (inst.ingredients.empty()) {
    raise_error << maybe(get(Recipe, r).name) << "'divide' has no ingredients\n" << end();
    break;
  }
  for (long long int i = 0; i < SIZE(inst.ingredients); ++i) {
    if (!is_mu_number(inst.ingredients.at(i))) {
      raise_error << maybe(get(Recipe, r).name) << "'divide' requires number ingredients, but got " << inst.ingredients.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'divide' yields exactly one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'divide' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case DIVIDE: {
  double result = ingredients.at(0).at(0);
  for (long long int i = 1; i < SIZE(ingredients); ++i)
    result /= ingredients.at(i).at(0);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario divide_literal)
recipe main [
  1:number <- divide 8, 2
]
+mem: storing 4 in location 1

:(scenario divide)
recipe main [
  1:number <- copy 27
  2:number <- copy 3
  3:number <- divide 1:number, 2:number
]
+mem: storing 9 in location 3

:(scenario divide_multiple)
recipe main [
  1:number <- divide 12, 3, 2
]
+mem: storing 2 in location 1

//: Integer division

:(before "End Primitive Recipe Declarations")
DIVIDE_WITH_REMAINDER,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "divide-with-remainder", DIVIDE_WITH_REMAINDER);
:(before "End Primitive Recipe Checks")
case DIVIDE_WITH_REMAINDER: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'divide-with-remainder' requires exactly two ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "'divide-with-remainder' requires number ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 2) {
    raise_error << maybe(get(Recipe, r).name) << "'divide-with-remainder' yields two products in '" << to_string(inst) << "'\n" << end();
    break;
  }
  for (long long int i = 0; i < SIZE(inst.products); ++i) {
    if (!is_dummy(inst.products.at(i)) && !is_mu_number(inst.products.at(i))) {
      raise_error << maybe(get(Recipe, r).name) << "'divide-with-remainder' should yield a number, but got " << inst.products.at(i).original_string << '\n' << end();
      goto finish_checking_instruction;
    }
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case DIVIDE_WITH_REMAINDER: {
  products.resize(2);
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  long long int b = static_cast<long long int>(ingredients.at(1).at(0));
  if (b == 0) {
    raise_error << maybe(current_recipe_name()) << "divide by zero in '" << to_string(current_instruction()) << "'\n" << end();
    products.resize(2);
    products.at(0).push_back(0);
    products.at(1).push_back(0);
    break;
  }
  long long int quotient = a / b;
  long long int remainder = a % b;
  // very large integers will lose precision
  products.at(0).push_back(quotient);
  products.at(1).push_back(remainder);
  break;
}

:(scenario divide_with_remainder_literal)
recipe main [
  1:number, 2:number <- divide-with-remainder 9, 2
]
+mem: storing 4 in location 1
+mem: storing 1 in location 2

:(scenario divide_with_remainder)
recipe main [
  1:number <- copy 27
  2:number <- copy 11
  3:number, 4:number <- divide-with-remainder 1:number, 2:number
]
+mem: storing 2 in location 3
+mem: storing 5 in location 4

:(scenario divide_with_decimal_point)
recipe main [
  1:number <- divide 5, 2
]
+mem: storing 2.5 in location 1

:(scenario divide_by_zero)
recipe main [
  1:number <- divide 4, 0
]
+mem: storing inf in location 1

:(scenario divide_by_zero_2)
% Hide_errors = true;
recipe main [
  1:number <- divide-with-remainder 4, 0
]
# integer division can't return floating-point infinity
+error: main: divide by zero in '1:number <- divide-with-remainder 4, 0'

//: Bitwise shifts

:(before "End Primitive Recipe Declarations")
SHIFT_LEFT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "shift-left", SHIFT_LEFT);
:(before "End Primitive Recipe Checks")
case SHIFT_LEFT: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-left' requires exactly two ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-left' requires number ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-left' yields one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-left' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    goto finish_checking_instruction;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case SHIFT_LEFT: {
  // ingredients must be integers
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  long long int b = static_cast<long long int>(ingredients.at(1).at(0));
  products.resize(1);
  if (b < 0) {
    raise_error << maybe(current_recipe_name()) << "second ingredient can't be negative in '" << to_string(current_instruction()) << "'\n" << end();
    products.at(0).push_back(0);
    break;
  }
  products.at(0).push_back(a<<b);
  break;
}

:(scenario shift_left_by_zero)
recipe main [
  1:number <- shift-left 1, 0
]
+mem: storing 1 in location 1

:(scenario shift_left_1)
recipe main [
  1:number <- shift-left 1, 4
]
+mem: storing 16 in location 1

:(scenario shift_left_2)
recipe main [
  1:number <- shift-left 3, 2
]
+mem: storing 12 in location 1

:(scenario shift_left_by_negative)
% Hide_errors = true;
recipe main [
  1:number <- shift-left 3, -1
]
+error: main: second ingredient can't be negative in '1:number <- shift-left 3, -1'

:(scenario shift_left_ignores_fractional_part)
recipe main [
  1:number <- divide 3, 2
  2:number <- shift-left 1:number, 1
]
+mem: storing 2 in location 2

:(before "End Primitive Recipe Declarations")
SHIFT_RIGHT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "shift-right", SHIFT_RIGHT);
:(before "End Primitive Recipe Checks")
case SHIFT_RIGHT: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-right' requires exactly two ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-right' requires number ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-right' yields one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'shift-right' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    goto finish_checking_instruction;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case SHIFT_RIGHT: {
  // ingredients must be integers
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  long long int b = static_cast<long long int>(ingredients.at(1).at(0));
  products.resize(1);
  if (b < 0) {
    raise_error << maybe(current_recipe_name()) << "second ingredient can't be negative in '" << to_string(current_instruction()) << "'\n" << end();
    products.at(0).push_back(0);
    break;
  }
  products.at(0).push_back(a>>b);
  break;
}

:(scenario shift_right_by_zero)
recipe main [
  1:number <- shift-right 1, 0
]
+mem: storing 1 in location 1

:(scenario shift_right_1)
recipe main [
  1:number <- shift-right 1024, 1
]
+mem: storing 512 in location 1

:(scenario shift_right_2)
recipe main [
  1:number <- shift-right 3, 1
]
+mem: storing 1 in location 1

:(scenario shift_right_by_negative)
% Hide_errors = true;
recipe main [
  1:number <- shift-right 4, -1
]
+error: main: second ingredient can't be negative in '1:number <- shift-right 4, -1'

:(scenario shift_right_ignores_fractional_part)
recipe main [
  1:number <- divide 3, 2
  2:number <- shift-right 1:number, 1
]
+mem: storing 0 in location 2

:(before "End Primitive Recipe Declarations")
AND_BITS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "and-bits", AND_BITS);
:(before "End Primitive Recipe Checks")
case AND_BITS: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'and-bits' requires exactly two ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "'and-bits' requires number ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'and-bits' yields one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'and-bits' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    goto finish_checking_instruction;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case AND_BITS: {
  // ingredients must be integers
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  long long int b = static_cast<long long int>(ingredients.at(1).at(0));
  products.resize(1);
  products.at(0).push_back(a&b);
  break;
}

:(scenario and_bits_1)
recipe main [
  1:number <- and-bits 8, 3
]
+mem: storing 0 in location 1

:(scenario and_bits_2)
recipe main [
  1:number <- and-bits 3, 2
]
+mem: storing 2 in location 1

:(scenario and_bits_3)
recipe main [
  1:number <- and-bits 14, 3
]
+mem: storing 2 in location 1

:(scenario and_bits_negative)
recipe main [
  1:number <- and-bits -3, 4
]
+mem: storing 4 in location 1

:(before "End Primitive Recipe Declarations")
OR_BITS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "or-bits", OR_BITS);
:(before "End Primitive Recipe Checks")
case OR_BITS: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'or-bits' requires exactly two ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "'or-bits' requires number ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'or-bits' yields one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'or-bits' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    goto finish_checking_instruction;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case OR_BITS: {
  // ingredients must be integers
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  long long int b = static_cast<long long int>(ingredients.at(1).at(0));
  products.resize(1);
  products.at(0).push_back(a|b);
  break;
}

:(scenario or_bits_1)
recipe main [
  1:number <- or-bits 3, 8
]
+mem: storing 11 in location 1

:(scenario or_bits_2)
recipe main [
  1:number <- or-bits 3, 10
]
+mem: storing 11 in location 1

:(scenario or_bits_3)
recipe main [
  1:number <- or-bits 4, 6
]
+mem: storing 6 in location 1

:(before "End Primitive Recipe Declarations")
XOR_BITS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "xor-bits", XOR_BITS);
:(before "End Primitive Recipe Checks")
case XOR_BITS: {
  if (SIZE(inst.ingredients) != 2) {
    raise_error << maybe(get(Recipe, r).name) << "'xor-bits' requires exactly two ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(1))) {
    raise_error << maybe(get(Recipe, r).name) << "'xor-bits' requires number ingredients, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'xor-bits' yields one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'xor-bits' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    goto finish_checking_instruction;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case XOR_BITS: {
  // ingredients must be integers
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  long long int b = static_cast<long long int>(ingredients.at(1).at(0));
  products.resize(1);
  products.at(0).push_back(a^b);
  break;
}

:(scenario xor_bits_1)
recipe main [
  1:number <- xor-bits 3, 8
]
+mem: storing 11 in location 1

:(scenario xor_bits_2)
recipe main [
  1:number <- xor-bits 3, 10
]
+mem: storing 9 in location 1

:(scenario xor_bits_3)
recipe main [
  1:number <- xor-bits 4, 6
]
+mem: storing 2 in location 1

:(before "End Primitive Recipe Declarations")
FLIP_BITS,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "flip-bits", FLIP_BITS);
:(before "End Primitive Recipe Checks")
case FLIP_BITS: {
  if (SIZE(inst.ingredients) != 1) {
    raise_error << maybe(get(Recipe, r).name) << "'flip-bits' requires exactly one ingredient, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'flip-bits' requires a number ingredient, but got '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) > 1) {
    raise_error << maybe(get(Recipe, r).name) << "'flip-bits' yields one product in '" << to_string(inst) << "'\n" << end();
    break;
  }
  if (!inst.products.empty() && !is_dummy(inst.products.at(0)) && !is_mu_number(inst.products.at(0))) {
    raise_error << maybe(get(Recipe, r).name) << "'flip-bits' should yield a number, but got " << inst.products.at(0).original_string << '\n' << end();
    goto finish_checking_instruction;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case FLIP_BITS: {
  // ingredient must be integer
  long long int a = static_cast<long long int>(ingredients.at(0).at(0));
  products.resize(1);
  products.at(0).push_back(~a);
  break;
}

:(scenario flip_bits_zero)
recipe main [
  1:number <- flip-bits 0
]
+mem: storing -1 in location 1

:(scenario flip_bits_negative)
recipe main [
  1:number <- flip-bits -1
]
+mem: storing 0 in location 1

:(scenario flip_bits_1)
recipe main [
  1:number <- flip-bits 3
]
+mem: storing -4 in location 1

:(scenario flip_bits_2)
recipe main [
  1:number <- flip-bits 12
]
+mem: storing -13 in location 1

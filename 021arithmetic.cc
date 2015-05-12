//: Arithmetic primitives

:(before "End Primitive Recipe Declarations")
ADD,
:(before "End Primitive Recipe Numbers")
Recipe_number["add"] = ADD;
:(before "End Primitive Recipe Implementations")
case ADD: {
  long long int result = 0;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result += ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario add_literal)
recipe main [
  1:integer <- add 23:literal, 34:literal
]
+run: instruction main/0
+run: ingredient 0 is 23
+run: ingredient 1 is 34
+run: product 0 is 1
+mem: storing 57 in location 1

:(scenario add)
recipe main [
  1:integer <- copy 23:literal
  2:integer <- copy 34:literal
  3:integer <- add 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 23
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 3
+mem: storing 57 in location 3

:(scenario add_multiple)
recipe main [
  1:integer <- add 3:literal, 4:literal, 5:literal
]
+mem: storing 12 in location 1

:(before "End Primitive Recipe Declarations")
SUBTRACT,
:(before "End Primitive Recipe Numbers")
Recipe_number["subtract"] = SUBTRACT;
:(before "End Primitive Recipe Implementations")
case SUBTRACT: {
  assert(ingredients.at(0).size() == 1);  // scalar
  long long int result = ingredients.at(0).at(0);
  for (index_t i = 1; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result -= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario subtract_literal)
recipe main [
  1:integer <- subtract 5:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 5
+run: ingredient 1 is 2
+run: product 0 is 1
+mem: storing 3 in location 1

:(scenario subtract)
recipe main [
  1:integer <- copy 23:literal
  2:integer <- copy 34:literal
  3:integer <- subtract 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 23
+run: ingredient 1 is 2
+mem: location 2 is 34
+run: product 0 is 3
+mem: storing -11 in location 3

:(scenario subtract_multiple)
recipe main [
  1:integer <- subtract 6:literal, 3:literal, 2:literal
]
+mem: storing 1 in location 1

:(before "End Primitive Recipe Declarations")
MULTIPLY,
:(before "End Primitive Recipe Numbers")
Recipe_number["multiply"] = MULTIPLY;
:(before "End Primitive Recipe Implementations")
case MULTIPLY: {
  long long int result = 1;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result *= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario multiply_literal)
recipe main [
  1:integer <- multiply 2:literal, 3:literal
]
+run: instruction main/0
+run: ingredient 0 is 2
+run: ingredient 1 is 3
+run: product 0 is 1
+mem: storing 6 in location 1

:(scenario multiply)
recipe main [
  1:integer <- copy 4:literal
  2:integer <- copy 6:literal
  3:integer <- multiply 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 4
+run: ingredient 1 is 2
+mem: location 2 is 6
+run: product 0 is 3
+mem: storing 24 in location 3

:(scenario multiply_multiple)
recipe main [
  1:integer <- multiply 2:literal, 3:literal, 4:literal
]
+mem: storing 24 in location 1

:(before "End Primitive Recipe Declarations")
DIVIDE,
:(before "End Primitive Recipe Numbers")
Recipe_number["divide"] = DIVIDE;
:(before "End Primitive Recipe Implementations")
case DIVIDE: {
  assert(ingredients.at(0).size() == 1);  // scalar
  long long int result = ingredients.at(0).at(0);
  for (index_t i = 1; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result /= ingredients.at(i).at(0);
  }
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(scenario divide_literal)
recipe main [
  1:integer <- divide 8:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 8
+run: ingredient 1 is 2
+run: product 0 is 1
+mem: storing 4 in location 1

:(scenario divide)
recipe main [
  1:integer <- copy 27:literal
  2:integer <- copy 3:literal
  3:integer <- divide 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 27
+run: ingredient 1 is 2
+mem: location 2 is 3
+run: product 0 is 3
+mem: storing 9 in location 3

:(scenario divide_multiple)
recipe main [
  1:integer <- divide 12:literal, 3:literal, 2:literal
]
+mem: storing 2 in location 1

:(before "End Primitive Recipe Declarations")
DIVIDE_WITH_REMAINDER,
:(before "End Primitive Recipe Numbers")
Recipe_number["divide-with-remainder"] = DIVIDE_WITH_REMAINDER;
:(before "End Primitive Recipe Implementations")
case DIVIDE_WITH_REMAINDER: {
  long long int quotient = ingredients.at(0).at(0) / ingredients.at(1).at(0);
  long long int remainder = ingredients.at(0).at(0) % ingredients.at(1).at(0);
  products.resize(2);
  products.at(0).push_back(quotient);
  products.at(1).push_back(remainder);
  break;
}

:(scenario divide_with_remainder_literal)
recipe main [
  1:integer, 2:integer <- divide-with-remainder 9:literal, 2:literal
]
+run: instruction main/0
+run: ingredient 0 is 9
+run: ingredient 1 is 2
+run: product 0 is 1
+mem: storing 4 in location 1
+run: product 1 is 2
+mem: storing 1 in location 2

:(scenario divide_with_remainder)
recipe main [
  1:integer <- copy 27:literal
  2:integer <- copy 11:literal
  3:integer, 4:integer <- divide-with-remainder 1:integer, 2:integer
]
+run: instruction main/2
+run: ingredient 0 is 1
+mem: location 1 is 27
+run: ingredient 1 is 2
+mem: location 2 is 11
+run: product 0 is 3
+mem: storing 2 in location 3
+run: product 1 is 4
+mem: storing 5 in location 4

//:: Support for non-integer numbers.

//: Supporting non-integers is hopefully the only place where we need to think
//: about the size of each location of memory.
:(after "int main")
assert(sizeof(long long int) == 8);
assert(sizeof(double) == 8);

:(before "End Globals")
//: Conventional hardware uses the most significant bit to represent the sign
//: in both (2's complement) integers, and so-called floating-point numbers
//: (with sign, exponent and fraction regions: https://en.wikipedia.org/wiki/Double-precision_floating-point_format)
static const long long int HOST_SET_NEGATIVE = 0x8000000000000000LL;
//: Floating-point numbers store the sign of the exponent in the second-most
//: significant bit.
static const long long int HOST_SET_FLOAT_NEGATIVE_EXPONENT = 0x4000000000000000LL;

//: As an experiment, we'd like to not have to distinguish between the two in
//: mu. So we'll use the most-significant bit to represent whether a number is
//: an integer (MSB 0) or a float (MSB 1). This will halve the set of numbers
//: we can represent, whether integers or non-integers, but that price seems
//: reasonable right now.
const long long int MU_NUMBER_TYPE_MASK = 0x8000000000000000LL;
//: As a result, the sign bit is now pushed to the second-most significant
//: bit..
const long long int MU_NUMBER_SIGN_MASK = 0x4000000000000000LL;
//: ..and the sign of the exponent for floating-point is pushed to the
//: third-most significant bit.
const long long int MU_FLOAT_EXPONENT_SIGN_MASK = 0x2000000000000000LL;

//: One nice side-effect of this mergek

:(after "int main")
assert(MU_NUMBER_TYPE_MASK == HOST_SET_NEGATIVE);
assert(MU_NUMBER_SIGN_MASK == HOST_SET_FLOAT_NEGATIVE_EXPONENT);

:(code)
inline bool is_float(long long int number) {
  return number & MU_NUMBER_TYPE_MASK;
}

inline bool is_integer(long long int number) {
  return !is_float(number);
}

// both floats and integers use the most significant bit for the sign
inline bool is_negative(long long int number) {
  return number & MU_NUMBER_SIGN_MASK;
}

inline bool float_has_negative_exponent(long long int number) {
  return number & MU_FLOAT_EXPONENT_SIGN_MASK;
}

long long int to_integer(long long int number) {
  assert(is_integer(number));
  if (is_negative(number)) {
    // slide the sign over by one bit
    number = number | HOST_SET_NEGATIVE;
    // clear the old sign bit
    number = number & (~MU_NUMBER_SIGN_MASK);
  }
  return number;
}

double to_float(long long int number) {
  assert(is_float(number));
//?   cerr << "0: " << std::hex << number << std::dec << ' ' << *reinterpret_cast<double*>(&number) << '\n'; //? 1
  if (is_negative(number)) {
    // slide the sign over by one bit
    number = number | HOST_SET_NEGATIVE;
//?     cerr << "1: " << std::hex << number << std::dec << ' ' << *reinterpret_cast<double*>(&number) << '\n'; //? 1
    // clear the old sign bit
    number = number & (~MU_NUMBER_SIGN_MASK);
//?     cerr << "2: " << std::hex << number << std::dec << ' ' << *reinterpret_cast<double*>(&number) << '\n'; //? 1
  }
  if (float_has_negative_exponent(number)) {
    // slide the sign of the exponent over by one bit
    number = number | HOST_SET_FLOAT_NEGATIVE_EXPONENT;
//?     cerr << "3: " << std::hex << number << std::dec << ' ' << *reinterpret_cast<double*>(&number) << '\n'; //? 1
//?     // clear the old exponent sign bit
//?     number = number & (~MU_FLOAT_EXPONENT_SIGN_MASK);
//?     cerr << "4: " << std::hex << number << std::dec << ' ' << *reinterpret_cast<double*>(&number) << '\n';
  }
  double result = *reinterpret_cast<double*>(&number);
  return result;
}

void test_integer_representation() {
  // Assuming long long int is 8 bytes:
  static const long long int nbits = 64;
//?   cerr << '\n'; //? 1
//?   cerr << nbits << " iterations\n"; //? 1
//?   cerr << std::hex; //? 1
//?   cerr << "type mask: " << MU_NUMBER_TYPE_MASK << '\n'; //? 1
//?   cerr << "sign mask: " << MU_NUMBER_SIGN_MASK << '\n'; //? 1
//?   cerr << std::dec; //? 1
  // until the last 2 bits all integers retain their value
  for (int i = 0; i < nbits-2; ++i) {
    long long int n = (0x1LL << i);
//?     cerr << i << ": " << "0x" << std::hex << n << std::dec << ' ' << n << " => " << to_integer(n) << '\n'; //? 1
    CHECK(is_integer(n));
    CHECK(n == to_integer(n));
  }
  long long int n = (0x1LL << (nbits-2));
  CHECK(is_integer(n));
//?   cerr << nbits-2 << ": " << "0x" << std::hex << n << std::dec << ' ' << n << " => " << to_integer(n) << '\n'; //? 1
  CHECK(is_negative(n));
}

void test_noninteger_representation() {
  // Assuming long long int is 8 bytes:
  static const long long int nbits = 64;
  static const long long int FLOAT_MASK = (0x1LL << (nbits-1));
  double f = -2.0;
  printf("0x%llx\n", *(long long int*)&f);
  cout << '\n';
  for (int fraction = 0; fraction < 52; ++fraction) {
    for (int exponent = 52; exponent < 63; ++exponent) {
      long long int n = (0x1LL << fraction) | (0x1LL << exponent) | FLOAT_MASK;
      CHECK(is_float(n));
      double result_on_host = *reinterpret_cast<double*>(&n);
      double result = to_float(n);
      printf("%02d %d: 0x%llx %.30e\n", fraction, exponent, n, result_on_host);
      printf("=>                        %.30e\n", result);
    }
  }
//?   long long int n = ((0x1LL << (nbits-2)) | FLOAT_MASK);
//?   CHECK(is_float(n));
//?   double result_on_host = *reinterpret_cast<double*>(&n);
//?   double result = to_float(n);
//?   cout << nbits-2 << ": " << "0x" << std::hex << n << std::dec << ' ' << result_on_host
//?        << " => " << result << '\n';
}

:(before "End Includes")
#include<iomanip>
#include<limits>

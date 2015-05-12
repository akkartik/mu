//: Arithmetic primitives

:(before "End Primitive Recipe Declarations")
ADD,
:(before "End Primitive Recipe Numbers")
Recipe_number["add"] = ADD;
:(before "End Primitive Recipe Implementations")
case ADD: {
  double result = 0;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result += value(ingredients.at(i).at(0));
  }
  products.resize(1);
  products.at(0).push_back(mu_noninteger(result));
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
  double result = value(ingredients.at(0).at(0));
  for (index_t i = 1; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result -= value(ingredients.at(i).at(0));
  }
  products.resize(1);
  products.at(0).push_back(mu_noninteger(result));
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
  double result = 1;
  for (index_t i = 0; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result *= value(ingredients.at(i).at(0));
  }
  products.resize(1);
  products.at(0).push_back(mu_noninteger(result));
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
  double result = value(ingredients.at(0).at(0));
  for (index_t i = 1; i < ingredients.size(); ++i) {
    assert(ingredients.at(i).size() == 1);  // scalar
    result /= value(ingredients.at(i).at(0));
  }
  products.resize(1);
  products.at(0).push_back(mu_noninteger(result));
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
  assert(ingredients.at(0).size() == 1);  // scalar
  long long int a = value(ingredients.at(0).at(0));
  assert(ingredients.at(1).size() == 1);  // scalar
  long long int b = value(ingredients.at(1).at(0));
  long long int quotient = a / b;
  long long int remainder = a % b;
  products.resize(2);
  products.at(0).push_back(mu_integer(quotient));
  products.at(1).push_back(mu_integer(remainder));
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

:(scenario divide_with_decimal_point)
recipe main [
  # todo: literal floats?
  1:integer <- divide 5:literal, 2:literal
]
+mem: storing 2.5 in location 1

//: Supporting non-integers is hopefully the only place where we need to think
//: about the size of each location of memory.
:(after "int main")
assert(sizeof(long long int) == 8);
assert(sizeof(double) == 8);

:(before "End Globals")
//: Conventional hardware uses the most significant bit to represent the sign
//: in both (2's complement) integers, and so-called floating-point numbers
//: (with sign, exponent and fraction regions: https://en.wikipedia.org/wiki/Double-precision_floating-point_format)

//: Watch out: perform bitwise operations only on unsigned values to avoid
//: undefined behavior.
//: For similar reasons, don't coerce between signed and unsigned, instead
//: manually interpret the bit-pattern

const unsigned long long int HOST_SET_NEGATIVE = (0x1ULL << 63ULL);

//: As an experiment, we'd like to not have to distinguish between the two in
//: mu. So we'll use the most-significant bit to represent whether a number is
//: an integer (MSB 0) or a float (MSB 1). This will halve the set of numbers
//: we can represent, whether integers or non-integers, but that price seems
//: reasonable right now.
const unsigned long long int MU_NUMBER_NONINTEGER_MASK = (0x1ULL << 63ULL);
//: As a result, the sign bit is now pushed to the second-most significant
//: bit..
const unsigned long long int MU_NUMBER_SIGN_MASK = (0x1ULL << 62ULL);

:(after "int main")
assert(MU_NUMBER_NONINTEGER_MASK == HOST_SET_NEGATIVE);

:(code)
inline bool is_float(long long int number) {
  unsigned long long int tmp = *reinterpret_cast<unsigned long long int*>(&number);
  return tmp & MU_NUMBER_NONINTEGER_MASK;
}

inline bool is_integer(long long int number) {
  return !is_float(number);
}

inline bool is_negative(long long int number) {
  unsigned long long int tmp = *reinterpret_cast<unsigned long long int*>(&number);
  return tmp & MU_NUMBER_SIGN_MASK;
}

inline double value(long long int number) {
  return is_integer(number) ? to_int(number) : to_float(number);
}

// convert a mu integer to host representation
long long int to_int(long long int number) {
  assert(is_integer(number));
  if (!is_negative(number)) return number;
  // negative number
  unsigned long long int tmp = *reinterpret_cast<unsigned long long int*>(&number);
  // slide the sign over by one bit
  tmp = tmp | HOST_SET_NEGATIVE;
//?   // clear the old sign bit
//?   // so the range of numbers we can represent shrinks by half
//?   tmp = tmp & (~MU_NUMBER_SIGN_MASK);
  // reinterpret back as signed
  long long int result = *reinterpret_cast<long long int*>(&tmp);
  return result;
}

// convert an integer from host representation to mu representation
long long int mu_integer(long long int n) {
  unsigned long long int tmp = *reinterpret_cast<unsigned long long int*>(&n);
  // slide the sign to the right
  if (tmp & HOST_SET_NEGATIVE) tmp = tmp | MU_NUMBER_SIGN_MASK;
  // clear the old sign bit
  tmp = tmp & (~HOST_SET_NEGATIVE);
  // reinterpret back as signed
  long long int result = *reinterpret_cast<long long int*>(&tmp);
  assert(is_integer(result));
//?   printf("%llx\n", result); //? 1
  return result;
}

// convert a mu non-integer to host representation
double to_float(long long int number) {
  assert(is_float(number));
  unsigned long long int tmp = *reinterpret_cast<unsigned long long int*>(&number);
  // slide the entire number over the most significant bit
  // so the precision of numbers we can represent shrinks by 1 bit
  tmp = (tmp << 1);
  double result = *reinterpret_cast<double*>(&tmp);
  return result;
}

// convert a float from host representation to mu representation
long long int mu_noninteger(double n) {
  unsigned long long int tmp = *reinterpret_cast<unsigned long long int*>(&n);
  tmp = (tmp >> 1);
  tmp = (tmp | MU_NUMBER_NONINTEGER_MASK);
  long long int result = *reinterpret_cast<long long int*>(&tmp);
  assert(is_float(result));
  return result;
}

// Spot-check some bit-patterns and make sure they convert back to themselves.
void test_integer_representation() {
  // Assuming long long int is 8 bytes:
  static const int nbits = 64;
//?   cerr << '\n'; //? 1
//?   cerr << nbits << " iterations\n"; //? 1
//?   cerr << std::hex; //? 1
//?   cerr << "type mask: " << MU_NUMBER_NONINTEGER_MASK << '\n'; //? 1
//?   cerr << "sign mask: " << MU_NUMBER_SIGN_MASK << '\n'; //? 1
//?   cerr << std::dec; //? 1
  // until the last 2 bits all integers retain their value
  for (int i = 0; i < nbits-2; ++i) {
    unsigned long long int x = (0x1ULL << i);
    long long int n = *reinterpret_cast<long long int*>(&x);
//?     cerr << i << ": " << "0x" << std::hex << n << std::dec << ' ' << n << " => " << to_int(n) << '\n'; //? 2
    CHECK(is_integer(n));
    CHECK_EQ(n, to_int(n));
//?     printf("0x%llx\n", mu_integer(to_int(n))); //? 1
    CHECK_EQ(n, mu_integer(to_int(n)));
  }
  // second-last bit
  unsigned long long int x = (0x1ULL << (nbits-2));
  long long int n = *reinterpret_cast<long long int*>(&x);
  CHECK(is_integer(n));
//?   cerr << nbits-2 << ": " << "0x" << std::hex << n << std::dec << ' ' << n << " => " << to_int(n) << '\n'; //? 1
  CHECK(is_negative(n));
  CHECK_EQ(n, mu_integer(to_int(n)));
  // most significant bit is for non-integers below
}

// Now go the other way; spot-check a few mu integers and make sure they
// convert back to themselves.
void test_small_integers() {
  for (long long int n = -1000; n < 1000; ++n) {
//?     printf("0x%llx vs 0x%llx\n", n, to_int(mu_integer(n))); //? 1
    CHECK_EQ(n, to_int(mu_integer(n)));
  }
}

// Spot-check some bit-patterns and make sure they convert back to themselves.
void test_noninteger_representation() {
  // Assuming long long int is 8 bytes:
  static const int nbits = 64;
  static const long long int FLOAT_MASK = (0x1ULL << (nbits-1));
//?   double f = -2.0; //? 1
//?   printf("0x%llx\n", *(long long int*)&f); //? 1
//?   printf("\n"); //? 1
  for (int fraction = 0; fraction < 52; ++fraction) {
    for (int exponent = 52; exponent < 63; ++exponent) {
      long long int n = (0x1ULL << fraction) | (0x1ULL << exponent) | FLOAT_MASK;
      CHECK(is_float(n));
      double result = to_float(n);
//?       double result_on_host = *reinterpret_cast<double*>(&n); //? 1
//?       printf("%02d %d: 0x%llx %.30e\n", fraction, exponent, n, result_on_host); //? 1
//?       printf("=>                        %.30e\n", result); //? 1
//?       printf("=>     0x%llx\n", mu_noninteger(result)); //? 1
      CHECK_EQ(n, mu_noninteger(result));
    }
    int exponent = 63;
    long long int n = ((0x1ULL << 62) | (0x1ULL << exponent) | FLOAT_MASK);
    CHECK(is_float(n));
    double result = to_float(n);
//?     double result_on_host = *reinterpret_cast<double*>(&n); //? 1
//?     printf("%02d %d: 0x%llx %.30e\n", fraction, nbits-1, n, result_on_host); //? 1
//?     printf("=>                        %.30e\n", result); //? 1
//?     printf("=>     0x%llx\n", mu_noninteger(result)); //? 1
    CHECK_EQ(n, mu_noninteger(result));
  }
}

:(code)
// Now go the other way; spot-check a few mu non-integers and make sure they
// convert back to themselves.
void test_small_nonintegers() {
  for (double n = -1000.0; n < 1000.0; n += 0.001) {
//?     printf("%.30e vs %.30e\n", n, to_float(mu_noninteger(n))); //? 1
    CHECK(fabs(n - to_float(mu_noninteger(n))) < epsilon);
  }
}

:(before "End Globals")
const double epsilon = 1e-13;

:(before "End Includes")
#include<iomanip>
#include<limits>
#include<math.h>

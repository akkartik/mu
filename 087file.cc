//: Interacting with the file system.
//:   '$open-file-for-reading' returns a FILE* as a number (ugh)
//:   '$read-from-file' accepts a number, interprets it as a FILE* (double ugh) and reads a character from it
//: Similarly for writing files.
//: These interfaces are ugly and tied to the current (Linux) host Mu happens
//: to be implemented atop. Later layers will wrap them with better, more
//: testable interfaces.
//:
//: Clearly we don't care about performance or any of that so far.
//: todo: reading/writing binary files

:(before "End Primitive Recipe Declarations")
_OPEN_FILE_FOR_READING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$open-file-for-reading", _OPEN_FILE_FOR_READING);
:(before "End Primitive Recipe Checks")
case _OPEN_FILE_FOR_READING: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$open-file-for-reading' requires exactly one ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_text(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$open-file-for-reading' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$open-file-for-reading' requires exactly one product, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first product of '$open-file-for-reading' should be a number (file handle), but got '" << to_string(inst.products.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _OPEN_FILE_FOR_READING: {
  string filename = read_mu_text(ingredients.at(0).at(0));
  assert(sizeof(long long int) >= sizeof(FILE*));
  FILE* f = fopen(filename.c_str(), "r");
  long long int result = reinterpret_cast<long long int>(f);
  products.resize(1);
  products.at(0).push_back(static_cast<double>(result));
  break;
}

:(before "End Primitive Recipe Declarations")
_OPEN_FILE_FOR_WRITING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$open-file-for-writing", _OPEN_FILE_FOR_WRITING);
:(before "End Primitive Recipe Checks")
case _OPEN_FILE_FOR_WRITING: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$open-file-for-writing' requires exactly one ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_text(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$open-file-for-writing' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$open-file-for-writing' requires exactly one product, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first product of '$open-file-for-writing' should be a number (file handle), but got '" << to_string(inst.products.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _OPEN_FILE_FOR_WRITING: {
  string filename = read_mu_text(ingredients.at(0).at(0));
  assert(sizeof(long long int) >= sizeof(FILE*));
  long long int result = reinterpret_cast<long long int>(fopen(filename.c_str(), "w"));
  products.resize(1);
  products.at(0).push_back(static_cast<double>(result));
  break;
}

:(before "End Primitive Recipe Declarations")
_READ_FROM_FILE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$read-from-file", _READ_FROM_FILE);
:(before "End Primitive Recipe Checks")
case _READ_FROM_FILE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$read-from-file' requires exactly one ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$read-from-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$read-from-file' requires exactly two products, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_character(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first product of '$read-from-file' should be a character, but got '" << to_string(inst.products.at(0)) << "'\n" << end();
    break;
  }
  if (!is_mu_boolean(inst.products.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second product of '$read-from-file' should be a boolean, but got '" << to_string(inst.products.at(1)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _READ_FROM_FILE: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  FILE* f = reinterpret_cast<FILE*>(x);
  if (f == NULL) {
    raise << maybe(current_recipe_name()) << "can't read from null file in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  products.resize(2);
  if (feof(f)) {
    products.at(0).push_back(0);
    products.at(1).push_back(1);  // eof
    break;
  }
  if (ferror(f)) {
    raise << maybe(current_recipe_name()) << "file in invalid state in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  char c = getc(f);  // todo: unicode
  if (c == EOF) {
    products.at(0).push_back(0);
    products.at(1).push_back(1);  // eof
    break;
  }
  if (ferror(f)) {
    raise << maybe(current_recipe_name()) << "couldn't read from file in '" << to_string(current_instruction()) << "'\n" << end();
    raise << "  errno: " << errno << '\n' << end();
    break;
  }
  products.at(0).push_back(c);
  products.at(1).push_back(0);  // not eof
  break;
}
:(before "End Includes")
#include <errno.h>

:(before "End Primitive Recipe Declarations")
_WRITE_TO_FILE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$write-to-file", _WRITE_TO_FILE);
:(before "End Primitive Recipe Checks")
case _WRITE_TO_FILE: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$write-to-file' requires exactly two ingredients, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$write-to-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (!is_mu_character(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of '$write-to-file' should be a character, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (!inst.products.empty()) {
    raise << maybe(get(Recipe, r).name) << "'$write-to-file' writes to no products, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _WRITE_TO_FILE: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  FILE* f = reinterpret_cast<FILE*>(x);
  if (f == NULL) {
    raise << maybe(current_recipe_name()) << "can't write to null file in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  if (feof(f)) break;
  if (ferror(f)) {
    raise << maybe(current_recipe_name()) << "file in invalid state in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  long long int y = static_cast<long long int>(ingredients.at(1).at(0));
  char c = static_cast<char>(y);
  putc(c, f);  // todo: unicode
  if (ferror(f)) {
    raise << maybe(current_recipe_name()) << "couldn't write to file in '" << to_string(current_instruction()) << "'\n" << end();
    raise << "  errno: " << errno << '\n' << end();
    break;
  }
  break;
}

:(before "End Primitive Recipe Declarations")
_CLOSE_FILE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$close-file", _CLOSE_FILE);
:(before "End Primitive Recipe Checks")
case _CLOSE_FILE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$close-file' requires exactly one ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$close-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$close-file' requires exactly one product, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  if (inst.products.at(0).name != inst.ingredients.at(0).name) {
    raise << maybe(get(Recipe, r).name) << "'$close-file' requires its product to be the same as its ingredient, but got '" << to_original_string(inst) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _CLOSE_FILE: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  FILE* f = reinterpret_cast<FILE*>(x);
  fclose(f);
  products.resize(1);
  products.at(0).push_back(0);  // todo: ensure that caller always resets the ingredient
  break;
}

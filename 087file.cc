//: Interacting with the file system.
//:   'real-open-file-for-reading' returns a FILE* as a number (ugh)
//:   'real-read-from-file' accepts a number, interprets it as a FILE* (double ugh) and reads a character from it
//: Similarly for writing files.
//:
//: Clearly we don't care about performance or any of that so far.
//: todo: reading/writing binary files

:(before "End Primitive Recipe Declarations")
REAL_OPEN_FILE_FOR_READING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "real-open-file-for-reading", REAL_OPEN_FILE_FOR_READING);
:(before "End Primitive Recipe Checks")
case REAL_OPEN_FILE_FOR_READING: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'real-open-file-for-reading' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  string filename;
  if (!is_mu_string(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'real-open-file-for-reading' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case REAL_OPEN_FILE_FOR_READING: {
  string filename = read_mu_string(ingredients.at(0).at(0));
  assert(sizeof(long long int) >= sizeof(FILE*));
  FILE* f = fopen(filename.c_str(), "r");
  long long int result = reinterpret_cast<long long int>(f);
  products.resize(1);
  products.at(0).push_back(static_cast<double>(result));
  break;
}

:(before "End Primitive Recipe Declarations")
REAL_OPEN_FILE_FOR_WRITING,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "real-open-file-for-writing", REAL_OPEN_FILE_FOR_WRITING);
:(before "End Primitive Recipe Checks")
case REAL_OPEN_FILE_FOR_WRITING: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'real-open-file-for-writing' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  string filename;
  if (!is_mu_string(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'real-open-file-for-writing' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case REAL_OPEN_FILE_FOR_WRITING: {
  string filename = read_mu_string(ingredients.at(0).at(0));
  assert(sizeof(long long int) >= sizeof(FILE*));
  long long int result = reinterpret_cast<long long int>(fopen(filename.c_str(), "w"));
  products.resize(1);
  products.at(0).push_back(static_cast<double>(result));
  break;
}

:(before "End Primitive Recipe Declarations")
REAL_READ_FROM_FILE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "real-read-from-file", REAL_READ_FROM_FILE);
:(before "End Primitive Recipe Checks")
case REAL_READ_FROM_FILE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'real-read-from-file' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  string filename;
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'real-read-from-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case REAL_READ_FROM_FILE: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  FILE* f = reinterpret_cast<FILE*>(x);
  if (f == NULL) {
    raise << maybe(current_recipe_name()) << "can't read from null file in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  products.resize(1);
  if (feof(f)) {
    products.at(0).push_back(0);
    break;
  }
  if (ferror(f)) {
    raise << maybe(current_recipe_name()) << "file in invalid state in '" << to_string(current_instruction()) << "'\n" << end();
    break;
  }
  char c = getc(f);  // todo: unicode
  if (ferror(f)) {
    raise << maybe(current_recipe_name()) << "couldn't read to file in '" << to_string(current_instruction()) << "'\n" << end();
    raise << "  errno: " << errno << '\n' << end();
    break;
  }
  products.at(0).push_back(c);
  break;
}

:(before "End Primitive Recipe Declarations")
REAL_WRITE_TO_FILE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "real-write-to-file", REAL_WRITE_TO_FILE);
:(before "End Primitive Recipe Checks")
case REAL_WRITE_TO_FILE: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'real-write-to-file' requires exactly two ingredients, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  string filename;
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'real-write-to-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'real-write-to-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case REAL_WRITE_TO_FILE: {
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
REAL_CLOSE_FILE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "real-close-file", REAL_CLOSE_FILE);
:(before "End Primitive Recipe Checks")
case REAL_CLOSE_FILE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'real-close-file' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  string filename;
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'real-close-file' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case REAL_CLOSE_FILE: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  FILE* f = reinterpret_cast<FILE*>(x);
  fclose(f);
  products.resize(1);
  products.at(0).push_back(0);  // todo: ensure that caller always resets the ingredient
  break;
}

//: Dead simple persistence.
//:   'restore' - reads string from a file
//:   'save' - writes string to a file

:(before "End Primitive Recipe Declarations")
RESTORE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "restore", RESTORE);
:(before "End Primitive Recipe Checks")
case RESTORE: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'restore' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  string filename;
  if (is_literal_text(inst.ingredients.at(0))) {
    ;
  }
  else if (is_mu_text(inst.ingredients.at(0))) {
    ;
  }
  else {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'restore' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case RESTORE: {
  string filename;
  if (is_literal_text(current_instruction().ingredients.at(0))) {
    filename = current_instruction().ingredients.at(0).name;
  }
  else if (is_mu_text(current_instruction().ingredients.at(0))) {
    filename = read_mu_text(ingredients.at(0).at(0));
  }
  if (Current_scenario) {
    // do nothing in tests
    products.resize(1);
    products.at(0).push_back(0);
    break;
  }
  string contents = slurp("lesson/"+filename);
  products.resize(1);
  if (contents.empty())
    products.at(0).push_back(0);
  else
    products.at(0).push_back(new_mu_text(contents));
  break;
}

:(code)
// http://cpp.indi.frih.net/blog/2014/09/how-to-read-an-entire-file-into-memory-in-cpp
string slurp(const string& filename) {
  ifstream fin(filename.c_str());
  fin.peek();
  if (!fin) return "";  // don't bother checking errno
  ostringstream result;
  result << fin.rdbuf();
  fin.close();
  return result.str();
}

:(before "End Primitive Recipe Declarations")
SAVE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "save", SAVE);
:(before "End Primitive Recipe Checks")
case SAVE: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'save' requires exactly two ingredients, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (is_literal_text(inst.ingredients.at(0))) {
    ;
  }
  else if (is_mu_text(inst.ingredients.at(0))) {
    ;
  }
  else {
    raise << maybe(get(Recipe, r).name) << "first ingredient of 'save' should be a string, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (!is_mu_text(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of 'save' should be an address:array:character, but got '" << to_string(inst.ingredients.at(1)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case SAVE: {
  if (Current_scenario) break;  // do nothing in tests
  string filename;
  if (is_literal_text(current_instruction().ingredients.at(0))) {
    filename = current_instruction().ingredients.at(0).name;
  }
  else if (is_mu_text(current_instruction().ingredients.at(0))) {
    filename = read_mu_text(ingredients.at(0).at(0));
  }
  ofstream fout(("lesson/"+filename).c_str());
  string contents = read_mu_text(ingredients.at(1).at(0));
  fout << contents;
  fout.close();
  if (!exists("lesson/.git")) break;
  // bug in git: git diff -q messes up --exit-code
  // explicitly say '--all' for git 1.9
  int status = system("cd lesson; git add --all .; git diff HEAD --exit-code >/dev/null || git commit -a -m . >/dev/null");
  if (status != 0)
    raise << "error in commit: contents " << contents << '\n' << end();
  break;
}

:(code)
bool exists(const string& filename) {
  struct stat dummy;
  return 0 == stat(filename.c_str(), &dummy);
}

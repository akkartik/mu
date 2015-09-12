//: Dead simple persistence.
//:   'restore' - reads string from a file
//:   'save' - writes string to a file

:(before "End Primitive Recipe Declarations")
RESTORE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["restore"] = RESTORE;
:(before "End Primitive Recipe Implementations")
case RESTORE: {
  if (SIZE(ingredients) != 1) {
    raise << current_recipe_name() << ": 'restore' requires exactly one ingredient, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  string filename;
  if (is_literal_string(current_instruction().ingredients.at(0))) {
    filename = current_instruction().ingredients.at(0).name;
  }
  else if (is_mu_string(current_instruction().ingredients.at(0))) {
    filename = read_mu_string(ingredients.at(0).at(0));
  }
  else {
    raise << current_recipe_name() << ": first ingredient of 'restore' should be a string, but got " << current_instruction().ingredients.at(0).to_string() << '\n' << end();
    break;
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
    products.at(0).push_back(new_mu_string(contents));
  break;
}

:(code)
string slurp(const string& filename) {
  ostringstream result;
  ifstream fin(filename.c_str());
  fin.peek();
  if (!fin) return result.str();  // don't bother checking errno
  const int N = 1024;
  char buf[N];
  while (!fin.eof()) {
    bzero(buf, N);
    fin.read(buf, N-1);  // leave at least one null
    result << buf;
  }
  fin.close();
  return result.str();
}

:(before "End Primitive Recipe Declarations")
SAVE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["save"] = SAVE;
:(before "End Primitive Recipe Implementations")
case SAVE: {
  if (SIZE(ingredients) != 2) {
    raise << current_recipe_name() << ": 'save' requires exactly two ingredients, but got " << current_instruction().to_string() << '\n' << end();
    break;
  }
  if (Current_scenario) break;  // do nothing in tests
  string filename;
  if (is_literal_string(current_instruction().ingredients.at(0))) {
    filename = current_instruction().ingredients.at(0).name;
  }
  else if (is_mu_string(current_instruction().ingredients.at(0))) {
    filename = read_mu_string(ingredients.at(0).at(0));
  }
  else {
    raise << current_recipe_name() << ": first ingredient of 'save' should be a string, but got " << current_instruction().ingredients.at(0).to_string() << '\n' << end();
    break;
  }
  if (!scalar(ingredients.at(1))) {
    raise << current_recipe_name() << ": second ingredient of 'save' should be an address:array:character, but got " << current_instruction().ingredients.at(1).to_string() << '\n' << end();
    break;
  }
  ofstream fout(("lesson/"+filename).c_str());
  string contents = read_mu_string(ingredients.at(1).at(0));
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

:(before "End Includes")
#include<sys/stat.h>

//: Dead simple persistence.
//:   'read' - reads string from a hardcoded file
//:   'save' - writes string to a hardcoded file

:(before "End Primitive Recipe Declarations")
READ,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["read"] = READ;
:(before "End Primitive Recipe Implementations")
case READ: {
  products.resize(1);
  products.at(0).push_back(new_string(slurp("lesson/recipe.mu")));
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
  if (!scalar(ingredients.at(0)))
    raise << "save: illegal operand " << current_instruction().ingredients.at(0).to_string() << '\n';
  string contents = to_string(ingredients.at(0).at(0));
  ofstream fout("lesson/recipe.mu");
  fout << contents;
  fout.close();
  if (!exists("lesson/.git")) break;
  // bug in git: git diff -q messes up --exit-code
  int status = system("cd lesson; git diff --exit-code >/dev/null || git commit -a -m . >/dev/null");
  if (status != 0)
    raise << "error in commit: contents " << contents << '\n';
  break;
}

:(code)
bool exists(const string& filename) {
  struct stat dummy;
  return 0 == stat(filename.c_str(), &dummy);
}

:(before "End Includes")
#include<sys/stat.h>

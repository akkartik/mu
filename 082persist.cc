//: Dead simple persistence.
//:   'restore' - reads string from a file
//:   'save' - writes string to a file

:(before "End Primitive Recipe Declarations")
RESTORE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["restore"] = RESTORE;
:(before "End Primitive Recipe Implementations")
case RESTORE: {
  if (!scalar(ingredients.at(0)))
    raise << "restore: illegal operand " << current_instruction().ingredients.at(0).to_string() << '\n';
  products.resize(1);
  products.at(0).push_back(new_mu_string(slurp("lesson/"+current_instruction().ingredients.at(0).name)));
  break;
}

:(code)
string slurp(const string& filename) {
//?   cerr << filename << '\n'; //? 1
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
//?   cerr << "=> " << result.str(); //? 1
  return result.str();
}

:(before "End Primitive Recipe Declarations")
SAVE,
:(before "End Primitive Recipe Numbers")
Recipe_ordinal["save"] = SAVE;
:(before "End Primitive Recipe Implementations")
case SAVE: {
  if (!scalar(ingredients.at(0)))
    raise << "save: illegal operand 0 " << current_instruction().ingredients.at(0).to_string() << '\n';
  string filename = current_instruction().ingredients.at(0).name;
  if (!is_literal(current_instruction().ingredients.at(0))) {
    ostringstream tmp;
    tmp << ingredients.at(0).at(0);
    filename = tmp.str();
  }
  ofstream fout(("lesson/"+filename).c_str());
  if (!scalar(ingredients.at(1)))
    raise << "save: illegal operand 1 " << current_instruction().ingredients.at(1).to_string() << '\n';
  string contents = read_mu_string(ingredients.at(1).at(0));
  fout << contents;
  fout.close();
  if (!exists("lesson/.git")) break;
  // bug in git: git diff -q messes up --exit-code
  int status = system("cd lesson; git add .; git diff HEAD --exit-code >/dev/null || git commit -a -m . >/dev/null");
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

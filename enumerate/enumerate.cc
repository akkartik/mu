#include<cstdlib>
#include<dirent.h>
#include<vector>
using std::vector;
#include<string>
using std::string;
#include<iostream>
using std::cout;

int enumerate_files_in_cwd_until(string last_file);
string flag_value(const string& flag, int argc, const char* argv[]);

int main(int argc, const char* argv[]) {
  return enumerate_files_in_cwd_until(flag_value("--until", argc, argv));
}

int enumerate_files_in_cwd_until(string last_file) {
  dirent** files;
  int num_files = scandir(".", &files, NULL, alphasort);
  for (int i = 0; i < num_files; ++i) {
    string curr_file = files[i]->d_name;
    if (!isdigit(curr_file.at(0))) continue;
    if (!last_file.empty() && curr_file > last_file) break;
    cout << curr_file << '\n';
  }
  // don't bother freeing files
  return 0;
}

string flag_value(const string& flag, int argc, const char* argv[]) {
  for (int i = 1; i < argc-1; ++i)
    if (string(argv[i]) == flag)
      return argv[i+1];
  return "";
}

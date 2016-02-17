#include<assert.h>
#include<cstdlib>
#include<dirent.h>
#include<vector>
using std::vector;
#include<string>
using std::string;
#include<iostream>
using std::cout;

int main(int argc, const char* argv[]) {
  assert(argc == 3);
  assert(string(argv[1]) == "--until");
  string last_file(argv[2]);

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

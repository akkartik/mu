:(before "End One-time Setup")
Transform.push_back(skip_whitespace_and_comments);

:(code)
void skip_whitespace_and_comments(const string& input, string& output) {
  cerr << "running compiler phase\n";
  istringstream in(input);
  in >> std::noskipws;
  ostringstream out;
  while (has_data(in)) {
    string word = next_word(in);
    out << word << ' ';
  }
  out.str().swap(output);
}

string next_word(istream& in) {
  skip_whitespace_and_comments(in);
  string result;
  in >> result;
  return result;
}

void skip_whitespace_and_comments(istream& in) {
  while (true) {
    char c = in.peek();
    if (isspace(c)) { in.get();  continue; }
    else if (c == '#') skip_comment(in);
    else return;
  }
}

void skip_comment(istream& in) {
  assert(in.peek() == '#');
  char c = '\0';
  do {
    in >> c;
  } while (c != '\n');
}

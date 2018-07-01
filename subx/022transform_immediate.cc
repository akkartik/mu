:(before "End One-time Setup")
Transform.push_back(identity);

:(code)
void identity(const string& input, string& output) {
  cerr << "running compiler phase\n";
  output = input;
}

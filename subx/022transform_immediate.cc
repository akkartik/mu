//: Having to manually translate numbers into hex and enter them in
//: little-endian order is tedious and error-prone. Let's automate the
//: translation.

:(scenario translate_immediate_constants)
# opcode        ModR/M                    SIB                   displacement    immediate
# instruction   mod, reg, Reg/Mem bits    scale, index, base
# 1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                            42/imm32
+translate: converting '42/imm32' to '2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

#: we don't have a testable instruction using 8-bit immediates yet, so can't run this instruction
:(scenarios transform)
:(scenario translate_imm8)
  cd 128/imm8
+translate: converting '128/imm8' to '80'
:(scenarios run)

:(before "End One-time Setup")
Transform.push_back(transform_immediate);

:(code)
void transform_immediate(const string& input, string& output) {
  istringstream in(input);
  ostringstream out;
  while (has_data(in)) {
    string line_data;
    getline(in, line_data);
    istringstream line(line_data);
    while (has_data(line)) {
      string word;
      line >> word;
      if (word.empty()) continue;
      if (word[0] == '#') {
        // skip comment
        break;
      }
      if (word.find("/imm") == string::npos) {
        out << word << ' ';
      }
      else {
        string output = transform_immediate(word);
        trace("translate") << "converting '" << word << "' to '" << output << "'" << end();
        out << output << ' ';
      }
    }
    out << '\n';
  }
  out.str().swap(output);
}

string transform_immediate(const string& word) {
  istringstream in(word);  // 'word' is guaranteed to have no whitespace
  string data = slurp_until(in, '/');
  istringstream in2(data);
  int value = 0;
  in2 >> value;
  ostringstream out;
  string type = next_word(in);
  if (type == "imm32") emit_octets(value, 4, out);
  else if (type == "imm8") emit_octets(value, 1, out);
  else raise << "unknown immediate tag /" << type << '\n' << end();
  return out.str();
}

void emit_octets(int value, int num_octets, ostream& out) {
  for (int i = 0;  i < num_octets;  ++i) {
    if (i > 0) out << ' ';
    out << HEXBYTE << (value & 0xff);
    value = value >> 8;
  }
}

string slurp_until(istream& in, char delim) {
  ostringstream out;
  char c;
  while (in >> c) {
    if (c == delim) {
      // drop the delim
      break;
    }
    out << c;
  }
  return out.str();
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

// helper
void transform(string/*copy*/ in) {
  perform_all_transforms(in);
}

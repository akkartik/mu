//: Having to manually translate numbers into hex and enter them in
//: little-endian order is tedious and error-prone. Let's automate the
//: translation.
//:
//: We'll convert any immediate operands from decimal to hex and emit the
//: appropriate number of bytes. If they occur in a non-code segment we'll
//: raise an error.

:(scenario translate_immediate_constants)
== 0x1
# opcode        ModR/M                    SIB                   displacement    immediate
# instruction   mod, reg, Reg/Mem bits    scale, index, base
# 1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                            42/imm32      # copy 42 to EBX
+translate: converting '42/imm32' to '2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

#: we don't have a testable instruction using 8-bit immediates yet, so can't run this instruction
:(scenarios transform)
:(scenario translate_imm8)
== 0x1
  cd 128/imm8
+translate: converting '128/imm8' to '80'
:(scenarios run)

:(before "End One-time Setup")
Transform.push_back(transform_immediate);

:(code)
void transform_immediate(program& p) {
  if (p.segments.empty()) return;
  transform_immediate(p.segments.at(0));
  for (int i = 1;  i < SIZE(p.segments);  ++i)
    flag_immediate(p.segments.at(i));
}

void transform_immediate(segment& seg) {
  for (int i = 0;  i < SIZE(seg.lines);  ++i)
    for (int j = 0;  j < SIZE(seg.lines.at(i).words);  ++j)
      transform_immediate(seg.lines.at(i).words, j);
}

void transform_immediate(vector<word>& line, int index) {
  assert(index < SIZE(line));
  if (contains_metadata(line.at(index), "imm32"))
    transform_imm32(line, index);
  else if (contains_metadata(line.at(index), "imm8"))
    transform_imm8(line.at(index));
}

bool contains_metadata(const word& curr, const string& m) {
  for (int k = 0;  k < SIZE(curr.metadata);  ++k)
    if (curr.metadata.at(k) == m)
      return true;
  return false;
}

void transform_imm8(word& w) {
  // convert decimal to hex
  uint32_t val = parse_int(w.data);
  if (trace_contains_errors()) return;
  if (val > 0xff) {
    raise << "invalid /imm8 word " << w.data << '\n' << end();
    return;
  }
  w.data = serialize_hex(val);
  trace("translate") << "converting '" << w.original << "' to '" << w.data << "'" << end();
}

void transform_imm32(vector<word>& line, int index) {
  vector<word>::iterator find(vector<word>&, int);
  vector<word>::iterator x = find(line, index);
  uint32_t val = parse_int(x->data);
  if (trace_contains_errors()) return;
  string orig = x->original;
  x = line.erase(x);
  emit_octets(line, x, val, orig);
}

vector<word>::iterator find(vector<word>& l, int index) {
  if (index >= SIZE(l)) {
    raise << "find: index too large: " << index << " vs " << SIZE(l) << '\n' << end();
    return l.end();
  }
  vector<word>::iterator result = l.begin();
  for (int i = 0;  i < index;  ++i)
    ++result;
  return result;
}

void emit_octets(vector<word>& line, vector<word>::iterator pos, uint32_t val, const string& orig) {
  vector<word> new_data;
  for (int i = 0;  i < /*num bytes*/4;  ++i) {
    word tmp;
    tmp.data = serialize_hex(val & 0xff);  // little-endian
    new_data.push_back(tmp);
    val = val >> 8;
  }
  trace("translate") << "converting '" << orig << "' to '" << to_string(new_data) << "'" << end();
  line.insert(pos, new_data.begin(), new_data.end());
}

string to_string(const vector<word>& in) {
  ostringstream out;
  for (int i = 0;  i < SIZE(in);  ++i) {
    if (i > 0) out << ' ';
    out << HEXBYTE << in.at(i).data;
  }
  return out.str();
}

uint32_t parse_int(const string& s) {
  istringstream in(s);
  uint32_t result = 0;
  if (starts_with(s, "0x"))
    in >> std::hex;
  in >> result;
  if (!in) {
    raise << "not a number: " << s << '\n' << end();
    return 0;
  }
  return result;
}

string serialize_hex(const int val) {
  ostringstream out;
  out << std::hex << val;
  return out.str();
}

void flag_immediate(const segment& seg) {
  for (int i = 0;  i < SIZE(seg.lines);  ++i) {
    const vector<word>& line = seg.lines.at(i).words;
    for (int j = 0;  j < SIZE(line);  ++j) {
      if (contains_metadata(line.at(j), "imm32")
          || contains_metadata(line.at(j), "imm8"))
        raise << "/imm8 and /imm32 only permitted in code segments, and we currently only allow the very first segment to be code.\n" << end();
    }
  }
}

// helper
void transform(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;
  transform(p);
}

:(scenario translate_immediate_constants_hex)
== 0x1
# opcode        ModR/M                    SIB                   displacement    immediate
# instruction   mod, reg, Reg/Mem bits    scale, index, base
# 1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                            0x2a/imm32    # copy 42 to EBX
+translate: converting '0x2a/imm32' to '2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

//: Metadata for fields of an x86 instruction.
//:
//: The x86 instruction set is variable-length, and how a byte is interpreted
//: affects later instruction boundaries. A lot of the pain in programming
//: machine code stems from computer and programmer going out of sync on what
//: a byte means. The miscommunication is usually not immediately caught, and
//: metastasizes at runtime into kilobytes of misinterpreted instructions.
//:
//: To mitigate these issues, we'll start programming in terms of logical
//: arguments rather than physical bytes. Some arguments are smaller than a
//: byte, and others may consist of multiple bytes. This layer will correctly
//: pack and order the bytes corresponding to the arguments in an instruction.

:(before "End Help Texts")
put_new(Help, "instructions",
  "Each x86 instruction consists of an instruction or opcode and some number\n"
  "of arguments.\n"
  "Each argument has a type. An instruction won't have more than one argument of\n"
  "any type.\n"
  "Each instruction has some set of allowed argument types. It'll reject others.\n"
  "The complete list of argument types: mod, subop, r32 (integer register),\n"
  "rm32 (integer register or memory), x32 (floating point register),\n"
  "xm32 (floating point register or memory), scale, index, base, disp8, disp16,\n"
  "disp32,imm8,imm32.\n"
  "Each of these has its own help page. Try reading 'bootstrap help mod' next.\n"
);
:(before "End Help Contents")
cerr << "  instructions\n";

:(before "Running Test Program")
transform(p);
if (trace_contains_errors()) return;

:(code)
void test_pack_immediate_constants() {
  run(
      "== code 0x1\n"
      "bb  0x2a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'bb 0x2a/imm32'\n"
      "transform: instruction after packing: 'bb 2a 00 00 00'\n"
      "run: copy imm32 0x0000002a to EBX\n"
  );
}

//: complete set of valid argument types

:(before "End Globals")
set<string> Instruction_arguments;
:(before "End One-time Setup")
Instruction_arguments.insert("subop");
Instruction_arguments.insert("mod");
Instruction_arguments.insert("rm32");
Instruction_arguments.insert("xm32");
Instruction_arguments.insert("base");
Instruction_arguments.insert("index");
Instruction_arguments.insert("scale");
Instruction_arguments.insert("r32");
Instruction_arguments.insert("x32");
Instruction_arguments.insert("disp8");
Instruction_arguments.insert("disp16");
Instruction_arguments.insert("disp32");
Instruction_arguments.insert("imm8");
Instruction_arguments.insert("imm32");

:(before "End Help Texts")
init_argument_type_help();
:(code)
void init_argument_type_help() {
  put(Help, "mod",
    "2-bit argument controlling the _addressing mode_ of many instructions,\n"
    "to determine how to compute the _effective address_ to look up memory at\n"
    "based on the 'rm32' argument and potentially others.\n"
    "\n"
    "If mod = 3, just operate on the contents of the register specified by rm32\n"
    "            (direct mode)\n"
    "If mod = 2, effective address is usually* rm32 + disp32\n"
    "            (indirect mode with displacement)\n"
    "If mod = 1, effective address is usually* rm32 + disp8\n"
    "            (indirect mode with displacement)\n"
    "If mod = 0, effective address is usually* rm32\n"
    "            (indirect mode)\n"
    "\n"
    "* - The exception is when rm32 is '4'. Register 4 is the stack pointer (ESP).\n"
    "    Using it as an address gets more involved. For more details,\n"
    "    try reading the help pages for 'base', 'index' and 'scale'.\n"
    "\n"
    "For complete details, spend some time with two tables in the IA-32 software\n"
    "developer's manual that are also included in this repo:\n"
    "  - modrm.pdf: volume 2, table 2-2, \"32-bit addressing with the ModR/M byte.\".\n"
    "  - sib.pdf: volume 2, table 2-3, \"32-bit addressing with the SIB byte.\".\n"
  );
  put(Help, "subop",
    "Additional 3-bit argument for determining the instruction when the opcode\n"
    "is 81, 8f, d3, f7 or ff.\n"
    "Can't coexist with argument of type 'r32' in a single instruction, because\n"
    "the two use the same bits.\n"
  );
  put(Help, "r32",
    "3-bit argument specifying an integer register argument used directly,\n"
    "without any further addressing modes.\n"
  );
  put(Help, "x32",
    "3-bit argument specifying a floating-point register argument used directly,\n"
    "without any further addressing modes.\n"
  );
  put(Help, "rm32",
    "32-bit value in an integer register or memory. The precise details of its\n"
    "construction depend on the eponymous 3-bit 'rm32' argument, the 'mod' argument,\n"
    "and also potentially the 'SIB' arguments ('scale', 'index' and 'base')\n"
    "and a displacement ('disp8' or 'disp32').\n"
    "\n"
    "For complete details, spend some time with two tables in the IA-32 software\n"
    "developer's manual that are also included in this repo:\n"
    "  - modrm.pdf: volume 2, table 2-2, \"32-bit addressing with the ModR/M byte.\".\n"
    "  - sib.pdf: volume 2, table 2-3, \"32-bit addressing with the SIB byte.\".\n"
  );
  put(Help, "xm32",
    "32-bit value in a floating-point register or memory. The precise details of its\n"
    "construction depend on the eponymous 3-bit 'xm32' argument, the 'mod' argument,\n"
    "and also potentially the 'SIB' arguments ('scale', 'index' and 'base')\n"
    "and a displacement ('disp8' or 'disp32').\n"
    "\n"
    "For complete details, spend some time with two tables in the IA-32 software\n"
    "developer's manual that are also included in this repo:\n"
    "  - modrm.pdf: volume 2, table 2-2, \"32-bit addressing with the ModR/M byte.\".\n"
    "  - sib.pdf: volume 2, table 2-3, \"32-bit addressing with the SIB byte.\".\n"
    "\n"
    "One subtlety here: while /xm32 refers to floating-point registers in direct mode\n"
    "(when /mod is 3), other addressing modes to construct memory addresses use integer registers\n"
    "(just like /rm32). Other than direct mode, its behavior is identical to /rm32.\n"
  );
  put(Help, "base",
    "Additional 3-bit argument (when 'rm32' is 4, unless 'mod' is 3) specifying the\n"
    "register containing an address to look up.\n"
    "This address may be further modified by 'index' and 'scale' arguments.\n"
    "  effective address = base + index*scale + displacement (disp8 or disp32)\n"
    "For complete details, spend some time with the IA-32 software developer's manual,\n"
    "volume 2, table 2-3, \"32-bit addressing with the SIB byte\".\n"
    "It is included in this repository as 'sib.pdf'.\n"
  );
  put(Help, "index",
    "Optional 3-bit argument (when 'rm32' is 4 unless 'mod' is 3) that can be added to\n"
    "the 'base' argument to compute the 'effective address' at which to look up memory.\n"
    "  effective address = base + index*scale + displacement (disp8 or disp32)\n"
    "For complete details, spend some time with the IA-32 software developer's manual,\n"
    "volume 2, table 2-3, \"32-bit addressing with the SIB byte\".\n"
    "It is included in this repository as 'sib.pdf'.\n"
  );
  put(Help, "scale",
    "Optional 2-bit argument (when 'rm32' is 4 unless 'mod' is 3) that encodes a\n"
    "power of 2 to be multiplied to the 'index' argument before adding the result to\n"
    "the 'base' argument to compute the _effective address_ to operate on.\n"
    "  effective address = base + index * scale + displacement (disp8 or disp32)\n"
    "\n"
    "When scale is 0, use index unmodified.\n"
    "When scale is 1, multiply index by 2.\n"
    "When scale is 2, multiply index by 4.\n"
    "When scale is 3, multiply index by 8.\n"
    "\n"
    "For complete details, spend some time with the IA-32 software developer's manual,\n"
    "volume 2, table 2-3, \"32-bit addressing with the SIB byte\".\n"
    "It is included in this repository as 'sib.pdf'.\n"
  );
  put(Help, "disp8",
    "8-bit value to be added in many instructions.\n"
  );
  put(Help, "disp16",
    "16-bit value to be added in many instructions.\n"
    "Currently not used in any SubX instructions.\n"
  );
  put(Help, "disp32",
    "32-bit value to be added in many instructions.\n"
  );
  put(Help, "imm8",
    "8-bit value for many instructions.\n"
  );
  put(Help, "imm32",
    "32-bit value for many instructions.\n"
  );
}

//:: transform packing arguments into bytes in the right order

:(after "Begin Transforms")
Transform.push_back(pack_arguments);

:(code)
void pack_arguments(program& p) {
  if (p.segments.empty()) return;
  segment& code = *find(p, "code");
  // Pack Operands(segment code)
  trace(3, "transform") << "-- pack arguments" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    if (all_hex_bytes(inst)) continue;
    trace(99, "transform") << "packing instruction '" << to_string(/*with metadata*/inst) << "'" << end();
    pack_arguments(inst);
    trace(99, "transform") << "instruction after packing: '" << to_string(/*without metadata*/inst.words) << "'" << end();
  }
}

void pack_arguments(line& inst) {
  line new_inst;
  add_opcodes(inst, new_inst);
  add_modrm_byte(inst, new_inst);
  add_sib_byte(inst, new_inst);
  add_disp_bytes(inst, new_inst);
  add_imm_bytes(inst, new_inst);
  inst.words.swap(new_inst.words);
}

void add_opcodes(const line& in, line& out) {
  out.words.push_back(in.words.at(0));
  if (in.words.at(0).data == "0f" || in.words.at(0).data == "f2" || in.words.at(0).data == "f3")
    out.words.push_back(in.words.at(1));
  if (in.words.at(0).data == "f3" && in.words.at(1).data == "0f")
    out.words.push_back(in.words.at(2));
  if (in.words.at(0).data == "f2" && in.words.at(1).data == "0f")
    out.words.push_back(in.words.at(2));
}

void add_modrm_byte(const line& in, line& out) {
  uint8_t mod=0, reg_subop=0, rm32=0;
  bool emit = false;
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_argument_metadata(curr, "mod")) {
      mod = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "rm32")) {
      rm32 = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "r32")) {
      reg_subop = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "xm32")) {
      rm32 = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "x32")) {
      reg_subop = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "subop")) {
      reg_subop = hex_byte(curr.data);
      emit = true;
    }
  }
  if (emit)
    out.words.push_back(hex_byte_text((mod << 6) | (reg_subop << 3) | rm32));
}

void add_sib_byte(const line& in, line& out) {
  uint8_t scale=0, index=0, base=0;
  bool emit = false;
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_argument_metadata(curr, "scale")) {
      scale = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "index")) {
      index = hex_byte(curr.data);
      emit = true;
    }
    else if (has_argument_metadata(curr, "base")) {
      base = hex_byte(curr.data);
      emit = true;
    }
  }
  if (emit)
    out.words.push_back(hex_byte_text((scale << 6) | (index << 3) | base));
}

void add_disp_bytes(const line& in, line& out) {
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_argument_metadata(curr, "disp8"))
      emit_hex_bytes(out, curr, 1);
    if (has_argument_metadata(curr, "disp16"))
      emit_hex_bytes(out, curr, 2);
    else if (has_argument_metadata(curr, "disp32"))
      emit_hex_bytes(out, curr, 4);
  }
}

void add_imm_bytes(const line& in, line& out) {
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_argument_metadata(curr, "imm8"))
      emit_hex_bytes(out, curr, 1);
    else if (has_argument_metadata(curr, "imm32"))
      emit_hex_bytes(out, curr, 4);
  }
}

void emit_hex_bytes(line& out, const word& w, int num) {
  assert(num <= 4);
  bool is_number = looks_like_hex_int(w.data);
  if (num == 1 || !is_number) {
    out.words.push_back(w);  // preserve existing metadata
    if (is_number)
      out.words.back().data = hex_byte_to_string(parse_int(w.data));
    return;
  }
  emit_hex_bytes(out, static_cast<uint32_t>(parse_int(w.data)), num);
}

void emit_hex_bytes(line& out, uint32_t val, int num) {
  assert(num <= 4);
  for (int i = 0;  i < num;  ++i) {
    out.words.push_back(hex_byte_text(val & 0xff));
    val = val >> 8;
  }
}

word hex_byte_text(uint8_t val) {
  word result;
  result.data = hex_byte_to_string(val);
  result.original = result.data+"/auto";
  return result;
}

string hex_byte_to_string(uint8_t val) {
  ostringstream out;
  // uint8_t prints without padding, but int8_t will expand to 32 bits again
  out << HEXBYTE << NUM(val);
  return out.str();
}

string to_string(const vector<word>& in) {
  ostringstream out;
  for (int i = 0;  i < SIZE(in);  ++i) {
    if (i > 0) out << ' ';
    out << in.at(i).data;
  }
  return out.str();
}

:(before "End Unit Tests")
void test_preserve_metadata_when_emitting_single_byte() {
  word in;
  in.data = "f0";
  in.original = "f0/foo";
  line out;
  emit_hex_bytes(out, in, 1);
  CHECK_EQ(out.words.at(0).data, "f0");
  CHECK_EQ(out.words.at(0).original, "f0/foo");
}

:(code)
void test_pack_disp8() {
  run(
      "== code 0x1\n"
      "74 2/disp8\n"  // jump 2 bytes away if ZF is set
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction '74 2/disp8'\n"
      "transform: instruction after packing: '74 02'\n"
  );
}

void test_pack_disp8_negative() {
  transform(
      "== code 0x1\n"
      // running this will cause an infinite loop
      "74 -1/disp8\n"  // jump 1 byte before if ZF is set
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction '74 -1/disp8'\n"
      "transform: instruction after packing: '74 ff'\n"
  );
}

void test_pack_rm32_direct() {
  run(
      "== code 0x1\n"
      // instruction                     effective address                                                   operand     displacement    immediate\n"
      // op          subop               mod             rm32          base        index         scale       r32\n"
      // 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes\n"
      "  01                              3/mod/direct    3/rm32/ebx                                          0/r32/eax                                \n"  // add EAX to EBX
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction '01 3/mod/direct 3/rm32/ebx 0/r32/eax'\n"
      "transform: instruction after packing: '01 c3'\n"
  );
}

void test_pack_rm32_indirect() {
  transform(
      "== code 0x1\n"
      // instruction                     effective address                                                   operand     displacement    immediate\n"
      // op          subop               mod             rm32          base        index         scale       r32\n"
      // 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes\n"
      "  01                              0/mod/indirect  3/rm32/ebx                                          0/r32/eax                                \n"  // add EAX to *EBX
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction '01 0/mod/indirect 3/rm32/ebx 0/r32/eax'\n"
      "transform: instruction after packing: '01 03'\n"
  );
}

void test_pack_x32() {
  run(
      "== code 0x1\n"
      // instruction                     effective address                                                   operand     displacement    immediate\n"
      // op          subop               mod             rm32          base        index         scale       r32\n"
      // 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes\n"
      "  f3 0f 2a                        3/mod/direct    3/rm32/ebx                                          1/x32                                    \n"  // convert EBX to XMM1
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'f3 0f 2a 3/mod/direct 3/rm32/ebx 1/x32'\n"
      "transform: instruction after packing: 'f3 0f 2a cb'\n"
  );
}

void test_pack_xm32_direct() {
  transform(
      "== code 0x1\n"
      // instruction                     effective address                                                   operand     displacement    immediate\n"
      // op          subop               mod             rm32          base        index         scale       r32\n"
      // 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes\n"
      "  f3 0f 5e                        3/mod/direct    3/xm32                                              1/x32                                    \n"  // divide XMM1 by XMM3
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'f3 0f 5e 3/mod/direct 3/xm32 1/x32'\n"
      "transform: instruction after packing: 'f3 0f 5e cb'\n"
  );
}

void test_pack_xm32_indirect() {
  transform(
      "== code 0x1\n"
      // instruction                     effective address                                                   operand     displacement    immediate\n"
      // op          subop               mod             rm32          base        index         scale       r32\n"
      // 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes\n"
      "  f3 0f 5e                        0/mod/indirect  3/rm32/ebx                                          1/x32                                    \n"  // divide XMM1 by *EBX
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'f3 0f 5e 0/mod/indirect 3/rm32/ebx 1/x32'\n"
      "transform: instruction after packing: 'f3 0f 5e 0b'\n"
  );
}

//: helper for scenario
void transform(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;
  transform(p);
}

void test_pack_modrm_imm32() {
  run(
      "== code 0x1\n"
      // instruction                     effective address                                                   operand     displacement    immediate\n"
      // op          subop               mod             rm32          base        index         scale       r32\n"
      // 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes\n"
      "  81          0/add/subop         3/mod/direct    3/rm32/ebx                                                                      1/imm32      \n"  // add 1 to EBX
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction '81 0/add/subop 3/mod/direct 3/rm32/ebx 1/imm32'\n"
      "transform: instruction after packing: '81 c3 01 00 00 00'\n"
  );
}

void test_pack_imm32_large() {
  run(
      "== code 0x1\n"
      "b9  0x080490a7/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'b9 0x080490a7/imm32'\n"
      "transform: instruction after packing: 'b9 a7 90 04 08'\n"
  );
}

void test_pack_immediate_constants_hex() {
  run(
      "== code 0x1\n"
      "b9  0x2a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'b9 0x2a/imm32'\n"
      "transform: instruction after packing: 'b9 2a 00 00 00'\n"
      "run: copy imm32 0x0000002a to ECX\n"
  );
}

void test_pack_silently_ignores_non_hex() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "b9  foo/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'b9 foo/imm32'\n"
      // no change (we're just not printing metadata to the trace)
      "transform: instruction after packing: 'b9 foo'\n"
  );
}

void test_pack_flags_bad_hex() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "b9  0xfoo/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: not a number: 0xfoo\n"
  );
}

void test_pack_flags_uppercase_hex() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "b9 0xAb/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: uppercase hex not allowed: 0xAb\n"
  );
}

//:: helpers

bool all_hex_bytes(const line& inst) {
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    if (!is_hex_byte(inst.words.at(i)))
      return false;
  return true;
}

bool is_hex_byte(const word& curr) {
  if (contains_any_argument_metadata(curr))
    return false;
  if (SIZE(curr.data) != 2)
    return false;
  if (curr.data.find_first_not_of("0123456789abcdef") != string::npos)
    return false;
  return true;
}

bool contains_any_argument_metadata(const word& word) {
  for (int i = 0;  i < SIZE(word.metadata);  ++i)
    if (Instruction_arguments.find(word.metadata.at(i)) != Instruction_arguments.end())
      return true;
  return false;
}

bool has_argument_metadata(const line& inst, const string& m) {
  bool result = false;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (!has_argument_metadata(inst.words.at(i), m)) continue;
    if (result) {
      raise << "'" << to_string(inst) << "' has conflicting " << m << " arguments\n" << end();
      return false;
    }
    result = true;
  }
  return result;
}

bool has_argument_metadata(const word& w, const string& m) {
  bool result = false;
  bool metadata_found = false;
  for (int i = 0;  i < SIZE(w.metadata);  ++i) {
    const string& curr = w.metadata.at(i);
    if (Instruction_arguments.find(curr) == Instruction_arguments.end()) continue;  // ignore unrecognized metadata
    if (metadata_found) {
      raise << "'" << w.original << "' has conflicting argument types; it should have only one\n" << end();
      return false;
    }
    metadata_found = true;
    result = (curr == m);
  }
  return result;
}

word metadata(const line& inst, const string& m) {
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    if (has_argument_metadata(inst.words.at(i), m))
      return inst.words.at(i);
  assert(false);
}

bool looks_like_hex_int(const string& s) {
  if (s.empty()) return false;
  if (s.at(0) == '-' || s.at(0) == '+') return true;
  if (isdigit(s.at(0))) return true;  // includes '0x' prefix
  // End looks_like_hex_int(s) Detectors
  return false;
}

string to_string(const line& inst) {
  ostringstream out;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (i > 0) out << ' ';
    out << inst.words.at(i).original;
  }
  return out.str();
}

int32_t parse_int(const string& s) {
  if (s.empty()) return 0;
  if (contains_uppercase(s)) {
    raise << "uppercase hex not allowed: " << s << '\n' << end();
    return 0;
  }
  istringstream in(s);
  in >> std::hex;
  if (s.at(0) == '-') {
    int32_t result = 0;
    in >> result;
    if (!in || !in.eof()) {
      raise << "not a number: " << s << '\n' << end();
      return 0;
    }
    return result;
  }
  uint32_t uresult = 0;
  in >> uresult;
  if (!in || !in.eof()) {
    raise << "not a number: " << s << '\n' << end();
    return 0;
  }
  return static_cast<int32_t>(uresult);
}
:(before "End Unit Tests")
void test_parse_int() {
  CHECK_EQ(0, parse_int("0"));
  CHECK_EQ(0, parse_int("0x0"));
  CHECK_EQ(0, parse_int("0x0"));
  CHECK_EQ(16, parse_int("10"));  // hex always
  CHECK_EQ(-1, parse_int("-1"));
  CHECK_EQ(-1, parse_int("0xffffffff"));
}

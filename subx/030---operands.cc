//: Beginning of "level 2": tagging bytes with metadata around what field of
//: an x86 instruction they're for.
//:
//: The x86 instruction set is variable-length, and how a byte is interpreted
//: affects later instruction boundaries. A lot of the pain in programming
//: machine code stems from computer and programmer going out of sync on what
//: a byte means. The miscommunication is usually not immediately caught, and
//: metastasizes at runtime into kilobytes of misinterpreted instructions.
//:
//: To mitigate these issues, we'll start programming in terms of logical
//: operands rather than physical bytes. Some operands are smaller than a
//: byte, and others may consist of multiple bytes. This layer will correctly
//: pack and order the bytes corresponding to the operands in an instruction.

:(before "End Help Texts")
put(Help, "instructions",
  "Each x86 instruction consists of an instruction or opcode and some number\n"
  "of operands.\n"
  "Each operand has a type. An instruction won't have more than one operand of\n"
  "any type.\n"
  "Each instruction has some set of allowed operand types. It'll reject others.\n"
  "The complete list of operand types: mod, subop, r32 (register), rm32\n"
  "(register or memory), scale, index, base, disp8, disp16, disp32, imm8,\n"
  "imm32.\n"
  "Each of these has its own help page. Try reading 'subx help mod' next.\n"
);
:(before "End Help Contents")
cerr << "  instructions\n";

:(scenario pack_immediate_constants)
== 0x1
# instruction                     effective address                                                   operand     displacement    immediate
# op          subop               mod             rm32          base        index         scale       r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                                                                              0x2a/imm32        # copy 42 to EBX
+transform: packing instruction 'bb 0x2a/imm32'
+transform: instruction after packing: 'bb 2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

//: complete set of valid operand types

:(before "End Globals")
set<string> Instruction_operands;
:(before "End One-time Setup")
Instruction_operands.insert("subop");
Instruction_operands.insert("mod");
Instruction_operands.insert("rm32");
Instruction_operands.insert("base");
Instruction_operands.insert("index");
Instruction_operands.insert("scale");
Instruction_operands.insert("r32");
Instruction_operands.insert("disp8");
Instruction_operands.insert("disp16");
Instruction_operands.insert("disp32");
Instruction_operands.insert("imm8");
Instruction_operands.insert("imm32");

:(before "End Help Texts")
init_operand_type_help();
:(code)
void init_operand_type_help() {
  put(Help, "mod",
    "2-bit operand controlling the _addressing mode_ of many instructions,\n"
    "to determine how to compute the _effective address_ to look up memory at\n"
    "based on the 'rm32' operand and potentially others.\n"
    "\n"
    "If mod = 3, just operate on the contents of the register specified by rm32\n"
    "            (direct mode).\n"
    "If mod = 2, effective address is usually* rm32 + disp32\n"
    "            (indirect mode with displacement).\n"
    "If mod = 1, effective address is usually* rm32 + disp8\n"
    "            (indirect mode with displacement).\n"
    "If mod = 0, effective address is usually* rm32 (indirect mode).\n"
    "(* - The exception is when rm32 is '4'. Register 4 is the stack pointer (ESP).\n"
    "     Using it as an address gets more involved. For more details,\n"
    "     try reading the help pages for 'base', 'index' and 'scale'.)\n"
    "\n"
    "For complete details consult the IA-32 software developer's manual, table 2-2,\n"
    "\"32-bit addressing forms with the ModR/M byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "subop",
    "Additional 3-bit operand for determining the instruction when the opcode is 81, 8f or ff.\n"
    "Can't coexist with operand of type 'r32' in a single instruction, because the two use the same bits.\n"
  );
  put(Help, "r32",
    "3-bit operand specifying a register operand used directly, without any further addressing modes.\n"
  );
  put(Help, "rm32",
    "3-bit operand specifying a register operand whose precise interpretation interacts with 'mod'.\n"
    "For complete details consult the IA-32 software developer's manual, table 2-2,\n"
    "\"32-bit addressing forms with the ModR/M byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "base",
    "Additional 3-bit operand (when 'rm32' is 4 unless 'mod' is 3) specifying the register containing an address to look up.\n"
    "This address may be further modified by 'index' and 'scale' operands.\n"
    "  effective address = base + index*scale + displacement (disp8 or disp32)\n"
    "For complete details consult the IA-32 software developer's manual, table 2-3,\n"
    "\"32-bit addressing forms with the SIB byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "index",
    "Optional 3-bit operand (when 'rm32' is 4 unless 'mod' is 3) that can be added to the 'base' operand to compute the 'effective address' at which to look up memory.\n"
    "  effective address = base + index*scale + displacement (disp8 or disp32)\n"
    "For complete details consult the IA-32 software developer's manual, table 2-3,\n"
    "\"32-bit addressing forms with the SIB byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "scale",
    "Optional 2-bit operand (when 'rm32' is 4 unless 'mod' is 3) that can be multiplied to the 'index' operand before adding the result to the 'base' operand to compute the _effective address_ to operate on.\n"
    "  effective address = base + index * scale + displacement (disp8 or disp32)\n"
    "For complete details consult the IA-32 software developer's manual, table 2-3,\n"
    "\"32-bit addressing forms with the SIB byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "disp8",
    "8-bit value to be added in many instructions.\n"
  );
  put(Help, "disp16",
    "16-bit value to be added in many instructions.\n"
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

//:: transform packing operands into bytes in the right order

:(before "End Transforms")
// Begin Level-2 Transforms
Transform.push_back(pack_operands);
// End Level-2 Transforms

:(code)
void pack_operands(program& p) {
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  // Pack Operands(segment code)
  trace(99, "transform") << "-- pack operands" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    if (all_hex_bytes(inst)) continue;
    trace(99, "transform") << "packing instruction '" << to_string(/*with metadata*/inst) << "'" << end();
    pack_operands(inst);
    trace(99, "transform") << "instruction after packing: '" << to_string(/*without metadata*/inst.words) << "'" << end();
  }
}

void pack_operands(line& inst) {
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
    if (has_metadata(curr, "mod")) {
      mod = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "rm32")) {
      rm32 = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "r32")) {
      reg_subop = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "subop")) {
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
    if (has_metadata(curr, "scale")) {
      scale = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "index")) {
      index = hex_byte(curr.data);
      emit = true;
    }
    else if (has_metadata(curr, "base")) {
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
    if (has_metadata(curr, "disp8"))
      emit_hex_bytes(out, curr, 1);
    if (has_metadata(curr, "disp16"))
      emit_hex_bytes(out, curr, 2);
    else if (has_metadata(curr, "disp32"))
      emit_hex_bytes(out, curr, 4);
  }
}

void add_imm_bytes(const line& in, line& out) {
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    const word& curr = in.words.at(i);
    if (has_metadata(curr, "imm8"))
      emit_hex_bytes(out, curr, 1);
    else if (has_metadata(curr, "imm32"))
      emit_hex_bytes(out, curr, 4);
  }
}

void emit_hex_bytes(line& out, const word& w, int num) {
  assert(num <= 4);
  if (num == 1 || !is_hex_int(w.data)) {
    out.words.push_back(w);
    if (is_hex_int(w.data))
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

:(scenario pack_disp8)
== 0x1
74 2/disp8  # jump 2 bytes away if ZF is set
+transform: packing instruction '74 2/disp8'
+transform: instruction after packing: '74 02'

:(scenarios transform)
:(scenario pack_disp8_negative)
== 0x1
# running this will cause an infinite loop
74 -1/disp8  # jump 1 byte before if ZF is set
+transform: packing instruction '74 -1/disp8'
+transform: instruction after packing: '74 ff'
:(scenarios run)

//: helper for scenario
:(code)
void transform(const string& text_bytes) {
  program p;
  istringstream in(text_bytes);
  parse(in, p);
  if (trace_contains_errors()) return;
  transform(p);
}

:(scenario pack_modrm_imm32)
== 0x1
# instruction                     effective address                                                   operand     displacement    immediate
# op          subop               mod             rm32          base        index         scale       r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  81          0/add/subop         3/mod/direct    3/ebx/rm32                                                                      1/imm32           # add 1 to EBX
+transform: packing instruction '81 0/add/subop 3/mod/direct 3/ebx/rm32 1/imm32'
+transform: instruction after packing: '81 c3 01 00 00 00'

:(scenario pack_imm32_large)
== 0x1
b9 0x080490a7/imm32  # copy to ECX
+transform: packing instruction 'b9 0x080490a7/imm32'
+transform: instruction after packing: 'b9 a7 90 04 08'

:(scenario pack_immediate_constants_hex)
== 0x1
# instruction                     effective address                                                   operand     displacement    immediate
# op          subop               mod             rm32          base        index         scale       r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                                                                              0x2a/imm32        # copy 42 to EBX
+transform: packing instruction 'bb 0x2a/imm32'
+transform: instruction after packing: 'bb 2a 00 00 00'
+run: copy imm32 0x0000002a to EBX

:(scenarios transform)
:(scenario pack_silently_ignores_non_hex)
== 0x1
# instruction                     effective address                                                   operand     displacement    immediate
# op          subop               mod             rm32          base        index         scale       r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  bb                                                                                                                              foo/imm32         # copy foo to EBX
+transform: packing instruction 'bb foo/imm32'
# no change (we're just not printing metadata to the trace)
+transform: instruction after packing: 'bb foo'
$error: 0
:(scenarios run)

//:: helpers

:(code)
bool all_hex_bytes(const line& inst) {
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    if (!is_hex_byte(inst.words.at(i)))
      return false;
  return true;
}

bool is_hex_byte(const word& curr) {
  if (contains_any_operand_metadata(curr))
    return false;
  if (SIZE(curr.data) != 2)
    return false;
  if (curr.data.find_first_not_of("0123456789abcdefABCDEF") != string::npos)
    return false;
  return true;
}

bool contains_any_operand_metadata(const word& word) {
  for (int i = 0;  i < SIZE(word.metadata);  ++i)
    if (Instruction_operands.find(word.metadata.at(i)) != Instruction_operands.end())
      return true;
  return false;
}

bool has_metadata(const line& inst, const string& m) {
  bool result = false;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (!has_metadata(inst.words.at(i), m)) continue;
    if (result) {
      raise << "'" << to_string(inst) << "' has conflicting " << m << " operands\n" << end();
      return false;
    }
    result = true;
  }
  return result;
}

bool has_metadata(const word& w, const string& m) {
  bool result = false;
  bool metadata_found = false;
  for (int i = 0;  i < SIZE(w.metadata);  ++i) {
    const string& curr = w.metadata.at(i);
    if (Instruction_operands.find(curr) == Instruction_operands.end()) continue;  // ignore unrecognized metadata
    if (metadata_found) {
      raise << "'" << w.original << "' has conflicting operand types; it should have only one\n" << end();
      return false;
    }
    metadata_found = true;
    result = (curr == m);
  }
  return result;
}

word metadata(const line& inst, const string& m) {
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    if (has_metadata(inst.words.at(i), m))
      return inst.words.at(i);
  assert(false);
}

bool is_hex_int(const string& s) {
  if (s.empty()) return false;
  size_t pos = 0;
  if (s.at(0) == '-' || s.at(0) == '+') pos++;
  if (s.substr(pos, pos+2) == "0x") pos += 2;
  return s.find_first_not_of("0123456789abcdefABCDEF", pos) == string::npos;
}

int32_t parse_int(const string& s) {
  istringstream in(s);
  int32_t result = 0;
  in >> std::hex >> result;
  if (!in || !in.eof()) {
    raise << "not a number: " << s << '\n' << end();
    return 0;
  }
  return result;
}

string to_string(const line& inst) {
  ostringstream out;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (i > 0) out << ' ';
    out << inst.words.at(i).original;
  }
  return out.str();
}

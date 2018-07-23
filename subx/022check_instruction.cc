//: Catch instructions with the wrong size or type (metadata) of operands.

:(before "End Help Texts")
put(Help, "instructions",
  "Each x86 instruction consists of an instruction or opcode and some number of operands.\n"
  "Each operand has a type. An instruction won't have more than one of any type.\n"
  "Each instruction has some set of allowed operand types. It'll reject others.\n"
  "The complete list of operand types: mod, subop, r32 (register), rm32 (register or memory), scale, index, base, disp8, disp16, disp32, imm8, imm32.\n"
  "Each of these has its own help page. Try reading 'subx help mod' next.\n"
);
:(before "End Help Contents")
cerr << "  instructions\n";

//:: Check for 'syntax errors'; missing or unexpected operands.

:(scenario check_missing_imm8_operand)
% Hide_errors = true;
== 0x1
# opcode        ModR/M                    SIB                   displacement    immediate
# instruction   mod, reg, Reg/Mem bits    scale, index, base
# 1-3 bytes     0/1 byte                  0/1 byte              0/1/2/4 bytes   0/1/2/4 bytes
  cd                                                                                          # int ??
+error: 'cd' (software interrupt): missing imm8 operand

:(before "End One-time Setup")
Transform.push_back(check_operands);

:(code)
void check_operands(/*const*/ program& p) {
  if (p.segments.empty()) return;
  const segment& seg = p.segments.at(0);
  for (int i = 0;  i < SIZE(seg.lines);  ++i) {
    check_operands(seg.lines.at(i));
    if (trace_contains_errors()) return;  // stop at the first mal-formed instruction
  }
}

void check_operands(const line& inst) {
  uint8_t op = hex_byte(inst.words.at(0).data);
  if (trace_contains_errors()) return;
  if (op == 0x0f) {
    check_operands_0f(inst);
    return;
  }
  if (op == 0xf3) {
    check_operands_f3(inst);
    return;
  }
  if (!contains_key(name, op)) {
    raise << "unknown opcode '" << std::hex << op << "'\n" << end();
    return;
  }
  check_operands(op, inst);
}

//: To check the operands for an opcode, we'll track the permitted operands
//: for each supported opcode in a bitvector. That way we can often compute the
//: bitvector for each instruction's operands and compare it with the expected.

:(before "End Types")
enum operand_type {
  // start from the least significant bit
  MODRM,  // more complex, may also involve disp8 or disp32
  SUBOP,
  DISP8,
  DISP16,
  DISP32,
  IMM8,
  IMM32,
  NUM_OPERAND_TYPES
};
:(before "End Globals")
vector<string> Operand_type_name;
map<string, operand_type> Operand_type;
:(before "End One-time Setup")
init_op_types();
:(code)
void init_op_types() {
  assert(NUM_OPERAND_TYPES <= /*bits in a uint8_t*/8);
  Operand_type_name.resize(NUM_OPERAND_TYPES);
  #define DEF(type) Operand_type_name.at(type) = tolower(#type), put(Operand_type, tolower(#type), type);
  DEF(MODRM);
  DEF(SUBOP);
  DEF(DISP8);
  DEF(DISP16);
  DEF(DISP32);
  DEF(IMM8);
  DEF(IMM32);
  #undef DEF
}

:(before "End Globals")
map</*op*/uint8_t, /*bitvector*/uint8_t> Permitted_operands;
const uint8_t INVALID_OPERANDS = 0xff;  // no instruction uses all the operands
:(before "End One-time Setup")
init_permitted_operands();
:(code)
void init_permitted_operands() {
  //// Class A: just op, no operands
  // halt
  put(Permitted_operands, 0xf4, 0x00);
  // push
  put(Permitted_operands, 0x50, 0x00);
  put(Permitted_operands, 0x51, 0x00);
  put(Permitted_operands, 0x52, 0x00);
  put(Permitted_operands, 0x53, 0x00);
  put(Permitted_operands, 0x54, 0x00);
  put(Permitted_operands, 0x55, 0x00);
  put(Permitted_operands, 0x56, 0x00);
  put(Permitted_operands, 0x57, 0x00);
  // pop
  put(Permitted_operands, 0x58, 0x00);
  put(Permitted_operands, 0x59, 0x00);
  put(Permitted_operands, 0x5a, 0x00);
  put(Permitted_operands, 0x5b, 0x00);
  put(Permitted_operands, 0x5c, 0x00);
  put(Permitted_operands, 0x5d, 0x00);
  put(Permitted_operands, 0x5e, 0x00);
  put(Permitted_operands, 0x5f, 0x00);
  // return
  put(Permitted_operands, 0xc3, 0x00);

  //// Class B: just op and disp8
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       1     0     0

  // jump
  put(Permitted_operands, 0xeb, 0x04);
  put(Permitted_operands, 0x74, 0x04);
  put(Permitted_operands, 0x75, 0x04);
  put(Permitted_operands, 0x7c, 0x04);
  put(Permitted_operands, 0x7d, 0x04);
  put(Permitted_operands, 0x7e, 0x04);
  put(Permitted_operands, 0x7f, 0x04);

  //// Class C: just op and disp16
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |1       0     0     0
  put(Permitted_operands, 0xe8, 0x08);  // jump

  //// Class D: just op and disp32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     1      |0       0     0     0
  put(Permitted_operands, 0xe9, 0x10);  // call

  //// Class E: just op and imm8
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     1     0      |0       0     0     0
  put(Permitted_operands, 0xcd, 0x20);  // software interrupt

  //// Class F: just op and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     0     0
  put(Permitted_operands, 0x05, 0x40);  // add
  put(Permitted_operands, 0x2d, 0x40);  // subtract
  put(Permitted_operands, 0x25, 0x40);  // and
  put(Permitted_operands, 0x0d, 0x40);  // or
  put(Permitted_operands, 0x35, 0x40);  // xor
  put(Permitted_operands, 0x3d, 0x40);  // compare
  put(Permitted_operands, 0x68, 0x40);  // push
  // copy
  put(Permitted_operands, 0xb8, 0x40);
  put(Permitted_operands, 0xb9, 0x40);
  put(Permitted_operands, 0xba, 0x40);
  put(Permitted_operands, 0xbb, 0x40);
  put(Permitted_operands, 0xbc, 0x40);
  put(Permitted_operands, 0xbd, 0x40);
  put(Permitted_operands, 0xbe, 0x40);
  put(Permitted_operands, 0xbf, 0x40);

  //// Class M: using ModR/M byte
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       0     0     1

  // add
  put(Permitted_operands, 0x01, 0x01);
  put(Permitted_operands, 0x03, 0x01);
  // subtract
  put(Permitted_operands, 0x29, 0x01);
  put(Permitted_operands, 0x2b, 0x01);
  // and
  put(Permitted_operands, 0x21, 0x01);
  put(Permitted_operands, 0x23, 0x01);
  // or
  put(Permitted_operands, 0x09, 0x01);
  put(Permitted_operands, 0x0b, 0x01);
  // complement
  put(Permitted_operands, 0xf7, 0x01);
  // xor
  put(Permitted_operands, 0x31, 0x01);
  put(Permitted_operands, 0x33, 0x01);
  // compare
  put(Permitted_operands, 0x39, 0x01);
  put(Permitted_operands, 0x3b, 0x01);
  // copy
  put(Permitted_operands, 0x89, 0x01);
  put(Permitted_operands, 0x8b, 0x01);
  // swap
  put(Permitted_operands, 0x87, 0x01);
  // pop
  put(Permitted_operands, 0x8f, 0x01);

  //// Class O: op, ModR/M and subop (not r32)
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       0     1     1
  put(Permitted_operands, 0xff, 0x03);  // jump/push/call

  //// Class N: op, ModR/M and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     0     1
  put(Permitted_operands, 0xc7, 0x41);  // copy

  //// Class P: op, ModR/M, subop (not r32) and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     1     1
  put(Permitted_operands, 0x81, 0x43);  // combine
}

:(before "End Includes")
#define HAS(bitvector, bit)  ((bitvector) & (1 << (bit)))
#define SET(bitvector, bit)  ((bitvector) | (1 << (bit)))
#define CLEAR(bitvector, bit)  ((bitvector) & (~(1 << (bit))))

:(code)
void check_operands(uint8_t op, const line& inst) {
  uint8_t expected_bitvector = get(Permitted_operands, op);
  if (HAS(expected_bitvector, MODRM))
    check_operands_modrm(inst, op);
  compare_bitvector(op, inst, CLEAR(expected_bitvector, MODRM));
}

//: Many instructions can be checked just by comparing bitvectors.

void compare_bitvector(uint8_t op, const line& inst, uint8_t expected) {
  uint8_t bitvector = compute_operand_bitvector(inst);
  if (trace_contains_errors()) return;  // duplicate operand type
  if (bitvector == 0 && expected != 0 && has_operands(inst) && all_hex_bytes(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  if (bitvector == expected) return;  // all good with this instruction
  for (int i = 0;  i < NUM_OPERAND_TYPES;  ++i, bitvector >>= 1, expected >>= 1) {
//?     cerr << "comparing " << HEXBYTE << NUM(bitvector) << " with " << NUM(expected) << '\n';
    if ((bitvector & 0x1) == (expected & 0x1)) continue;  // all good with this operand
    const string& optype = Operand_type_name.at(i);
    if ((bitvector & 0x1) > (expected & 0x1))
      raise << "'" << to_string(inst) << "' (" << get(name, op) << "): unexpected " << optype << " operand\n" << end();
    else
      raise << "'" << to_string(inst) << "' (" << get(name, op) << "): missing " << optype << " operand\n" << end();
    // continue giving all errors for a single instruction
  }
  // ignore settings in any unused bits
}

bool has_operands(const line& inst) {
  return SIZE(inst.words) > first_operand(inst);
}

int first_operand(const line& inst) {
  if (inst.words.at(0).data == "0f") return 2;
  if (inst.words.at(0).data == "f3") {
    if (inst.words.at(1).data == "0f")
      return 3;
    else
      return 2;
  }
  return 1;
}

bool all_hex_bytes(const line& inst) {
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (SIZE(inst.words.at(i).data) != 2)
      return false;
    if (inst.words.at(i).data.find_first_not_of("0123456789abcdefABCDEF") != string::npos)
      return false;
  }
  return true;
}

uint32_t compute_operand_bitvector(const line& inst) {
  uint32_t bitvector = 0;
  for (int i = /*skip op*/1;  i < SIZE(inst.words);  ++i) {
    bitvector = bitvector | bitvector_for_operand(inst.words.at(i));
    if (trace_contains_errors()) return INVALID_OPERANDS;  // duplicate operand type
  }
  return bitvector;
}

// Scan the metadata of 'w' and return the bit corresponding to any operand type.
// Also raise an error if metadata contains multiple operand types.
uint32_t bitvector_for_operand(const word& w) {
  uint32_t bv = 0;
  bool found = false;
  for (int i = 0;  i < SIZE(w.metadata);  ++i) {
    const string& curr = w.metadata.at(i);
    if (!contains_key(Operand_type, curr)) continue;  // ignore unrecognized metadata
    if (found) {
      raise << "'" << w.original << "' has conflicting operand types; it should have only one\n" << end();
      return INVALID_OPERANDS;
    }
    bv = (1 << get(Operand_type, curr));
    found = true;
  }
  return bv;
}

:(scenario conflicting_operand_type)
% Hide_errors = true;
== 0x1
cd/software-interrupt 80/imm8/imm32
+error: '80/imm8/imm32' has conflicting operand types; it should have only one

//: Instructions computing effective addresses have more complex rules, so
//: we'll hard-code a common set of instruction-decoding rules.

:(scenario check_missing_mod_operand)
% Hide_errors = true;
== 0x1
81 0/add/subop       3/rm32/ebx 1/imm32
+error: '81 0/add/subop 3/rm32/ebx 1/imm32' (combine rm32 with imm32 based on subop): missing mod operand

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

:(code)
void check_operands_modrm(const line& inst, uint8_t op) {
  if (all_hex_bytes(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  check_metadata_present(inst, "mod", op);
  check_metadata_present(inst, "rm32", op);
  // no check for r32; some instructions don't use it; just assume it's 0 if missing
  if (op == 0x81 || op == 0x8f || op == 0xff) {  // keep sync'd with 'help subop'
    check_metadata_present(inst, "subop", op);
    if (has_metadata(inst, "r32", op))
      raise << "'" << to_string(inst) << "' (" << get(name, op) << "): unexpected r32 operand (should be replaced by subop)\n" << end();
  }
  if (trace_contains_errors()) return;
  if (metadata(inst, "rm32").data != "4") return;
  // SIB byte checks
  check_metadata_present(inst, "base", op);
  check_metadata_present(inst, "index", op);  // otherwise why go to SIB?
  // no check for scale; 0 (2**0 = 1) by default
}

void check_metadata_present(const line& inst, const string& type, uint8_t op) {
  if (!has_metadata(inst, type, op))
    raise << "'" << to_string(inst) << "' (" << get(name, op) << "): missing " << type << " operand\n" << end();
}

bool has_metadata(const line& inst, const string& m, uint8_t op) {
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
    if (!contains_key(Instruction_operands, curr)) continue;  // ignore unrecognized metadata
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

:(scenario conflicting_operands_in_modrm_instruction)
% Hide_errors = true;
== 0x1
01/add 0/mod 3/mod
+error: '01/add 0/mod 3/mod' has conflicting mod operands

:(scenario conflicting_operand_type_modrm)
% Hide_errors = true;
== 0x1
01/add 0/mod 3/rm32/r32
+error: '3/rm32/r32' has conflicting operand types; it should have only one

:(scenario check_missing_rm32_operand)
% Hide_errors = true;
== 0x1
81 0/add/subop 0/mod            1/imm32
+error: '81 0/add/subop 0/mod 1/imm32' (combine rm32 with imm32 based on subop): missing rm32 operand

:(scenario check_missing_subop_operand)
% Hide_errors = true;
== 0x1
81             0/mod 3/rm32/ebx 1/imm32
+error: '81 0/mod 3/rm32/ebx 1/imm32' (combine rm32 with imm32 based on subop): missing subop operand

:(scenario check_missing_base_operand)
% Hide_errors = true;
== 0x1
81 0/add/subop 0/mod/indirect 4/rm32/use-sib 1/imm32
+error: '81 0/add/subop 0/mod/indirect 4/rm32/use-sib 1/imm32' (combine rm32 with imm32 based on subop): missing base operand

:(scenario check_missing_index_operand)
% Hide_errors = true;
== 0x1
81 0/add/subop 0/mod/indirect 4/rm32/use-sib 0/base 1/imm32
+error: '81 0/add/subop 0/mod/indirect 4/rm32/use-sib 0/base 1/imm32' (combine rm32 with imm32 based on subop): missing index operand

:(scenario check_missing_base_operand_2)
% Hide_errors = true;
== 0x1
81 0/add/subop 0/mod/indirect 4/rm32/use-sib 2/index 3/scale 1/imm32
+error: '81 0/add/subop 0/mod/indirect 4/rm32/use-sib 2/index 3/scale 1/imm32' (combine rm32 with imm32 based on subop): missing base operand

//:: similarly handle multi-byte opcodes

:(code)
void check_operands_0f(const line& inst) {
  assert(inst.words.at(0).data == "0f");
  if (SIZE(inst.words) == 1) {
    raise << "no 2-byte opcode specified starting with '0f'\n" << end();
    return;
  }
  uint8_t op = hex_byte(inst.words.at(1).data);
  if (!contains_key(name_0f, op)) {
    raise << "unknown 2-byte opcode '0f " << std::hex << op << "'\n" << end();
    return;
  }
  check_operands_0f(op, inst);
}

void check_operands_f3(const line& inst) {
  raise << "no supported opcodes starting with f3\n" << end();
}

void check_operands_0f(uint8_t op, const line& inst) {
}

string to_string(const line& inst) {
  ostringstream out;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (i > 0) out << ' ';
    out << inst.words.at(i).original;
  }
  return out.str();
}

string tolower(const char* s) {
  ostringstream out;
  for (/*nada*/;  *s;  ++s)
    out << static_cast<char>(tolower(*s));
  return out.str();
}

//:: docs on each operand type

:(before "End Help Texts")
init_operand_type_help();
:(code)
void init_operand_type_help() {
  put(Help, "mod",
    "2-bit operand controlling the _addressing mode_ of many instructions,\n"
    "to determine how to compute the _effective address_ to look up memory at\n"
    "based on the 'rm32' operand and potentially others.\n"
    "\n"
    "If mod = 3, just operate on the contents of the register specified by rm32 (direct mode).\n"
    "If mod = 2, effective address is usually* rm32 + disp32 (indirect mode with displacement).\n"
    "If mod = 1, effective address is usually* rm32 + disp8 (indirect mode with displacement).\n"
    "If mod = 0, effective address is usually* rm32 (indirect mode).\n"
    "(* - The exception is when rm32 is '4'. Register 4 is the stack pointer (ESP). Using it as an address gets more involved.\n"
    "     For more details, try reading the help pages for 'base', 'index' and 'scale'.)\n"
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

:(before "End Includes")
#include<cctype>

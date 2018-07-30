//: Beginning of "level 2": tagging bytes with metadata around what field of
//: an x86 instruction they're for.
//:
//: The x86 instruction set is variable-length, and how a byte is interpreted
//: affects later instruction boundaries. A lot of the pain in programming machine code
//: stems from computer and programmer going out of sync on what a byte
//: means. The miscommunication is usually not immediately caught, and
//: metastasizes at runtime into kilobytes of misinterpreted instructions.
//: Tagging bytes with what the programmer expects them to be interpreted as
//: helps the computer catch miscommunication immediately.
//:
//: This is one way SubX is going to be different from a 'language': we
//: typically think of languages as less verbose than machine code. Here we're
//: making machine code *more* verbose.
//:
//: ---
//:
//: While we're here, we'll also improve a couple of other things:
//:
//: a) Machine code often packs logically separate operands into bitfields of
//: a single byte. We'll start writing out each operand separately, and the
//: translator will construct the right bytes out of operands.
//:
//: SubX now gets still more verbose. What used to be a single byte, say 'c3',
//: can now expand to '3/mod 0/subop 3/rm32'.
//:
//: b) Since each operand is tagged, we can loosen ordering restrictions and
//: allow writing out the operands in any order, like keyword arguments.
//:
//: c) Operand values can be expressed in either decimal or hex (when prefixed
//: with '0x'. Raw 2-character hex bytes without the '0x' are only valid when
//: tagged without any operand metadata. (This may be a bad idea.)
//:
//: Coda: the actual opcodes (1-3 bytes) will continue to be at the start of
//: each line, in hex, and untagged. The x86 instruction set is a mess, and
//: instructions don't admit good names.

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

//:: Check for 'syntax errors'; missing or unexpected operands.

:(scenario check_missing_imm8_operand)
% Hide_errors = true;
== 0x1
# instruction                     effective address                                           operand     displacement    immediate
# op          subop               mod             rm32          base      index     scale     r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  cd                                                                                                                                        # int ??
+error: 'cd' (software interrupt): missing imm8 operand

:(before "End One-time Setup")
Transform.push_back(check_operands);

:(code)
void check_operands(/*const*/ program& p) {
  trace(99, "transform") << "-- check operands" << end();
  if (p.segments.empty()) return;
  const segment& code = p.segments.at(0);
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    check_operands(code.lines.at(i));
    if (trace_contains_errors()) return;  // stop at the first mal-formed instruction
  }
}

void check_operands(const line& inst) {
  word op = preprocess_op(inst.words.at(0));
  if (op.data == "0f") {
    check_operands_0f(inst);
    return;
  }
  if (op.data == "f3") {
    check_operands_f3(inst);
    return;
  }
  check_operands(inst, op);
}

word preprocess_op(word/*copy*/ op) {
  op.data = tolower(op.data.c_str());
  if (starts_with(op.data, "0x"))
    op.data = op.data.substr(2);
  return op;
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
map</*op*/string, /*bitvector*/uint8_t> Permitted_operands;
const uint8_t INVALID_OPERANDS = 0xff;  // no instruction uses all the operand types
:(before "End One-time Setup")
init_permitted_operands();
:(code)
void init_permitted_operands() {
  //// Class A: just op, no operands
  // halt
  put(Permitted_operands, "f4", 0x00);
  // push
  put(Permitted_operands, "50", 0x00);
  put(Permitted_operands, "51", 0x00);
  put(Permitted_operands, "52", 0x00);
  put(Permitted_operands, "53", 0x00);
  put(Permitted_operands, "54", 0x00);
  put(Permitted_operands, "55", 0x00);
  put(Permitted_operands, "56", 0x00);
  put(Permitted_operands, "57", 0x00);
  // pop
  put(Permitted_operands, "58", 0x00);
  put(Permitted_operands, "59", 0x00);
  put(Permitted_operands, "5a", 0x00);
  put(Permitted_operands, "5b", 0x00);
  put(Permitted_operands, "5c", 0x00);
  put(Permitted_operands, "5d", 0x00);
  put(Permitted_operands, "5e", 0x00);
  put(Permitted_operands, "5f", 0x00);
  // return
  put(Permitted_operands, "c3", 0x00);

  //// Class B: just op and disp8
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       1     0     0

  // jump
  put(Permitted_operands, "eb", 0x04);
  put(Permitted_operands, "74", 0x04);
  put(Permitted_operands, "75", 0x04);
  put(Permitted_operands, "7c", 0x04);
  put(Permitted_operands, "7d", 0x04);
  put(Permitted_operands, "7e", 0x04);
  put(Permitted_operands, "7f", 0x04);

  //// Class C: just op and disp16
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |1       0     0     0
  put(Permitted_operands, "e9", 0x08);  // jump

  //// Class D: just op and disp32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     1      |0       0     0     0
  put(Permitted_operands, "e8", 0x10);  // call

  //// Class E: just op and imm8
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     1     0      |0       0     0     0
  put(Permitted_operands, "cd", 0x20);  // software interrupt

  //// Class F: just op and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     0     0
  put(Permitted_operands, "05", 0x40);  // add
  put(Permitted_operands, "2d", 0x40);  // subtract
  put(Permitted_operands, "25", 0x40);  // and
  put(Permitted_operands, "0d", 0x40);  // or
  put(Permitted_operands, "35", 0x40);  // xor
  put(Permitted_operands, "3d", 0x40);  // compare
  put(Permitted_operands, "68", 0x40);  // push
  // copy
  put(Permitted_operands, "b8", 0x40);
  put(Permitted_operands, "b9", 0x40);
  put(Permitted_operands, "ba", 0x40);
  put(Permitted_operands, "bb", 0x40);
  put(Permitted_operands, "bc", 0x40);
  put(Permitted_operands, "bd", 0x40);
  put(Permitted_operands, "be", 0x40);
  put(Permitted_operands, "bf", 0x40);

  //// Class M: using ModR/M byte
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       0     0     1

  // add
  put(Permitted_operands, "01", 0x01);
  put(Permitted_operands, "03", 0x01);
  // subtract
  put(Permitted_operands, "29", 0x01);
  put(Permitted_operands, "2b", 0x01);
  // and
  put(Permitted_operands, "21", 0x01);
  put(Permitted_operands, "23", 0x01);
  // or
  put(Permitted_operands, "09", 0x01);
  put(Permitted_operands, "0b", 0x01);
  // complement
  put(Permitted_operands, "f7", 0x01);
  // xor
  put(Permitted_operands, "31", 0x01);
  put(Permitted_operands, "33", 0x01);
  // compare
  put(Permitted_operands, "39", 0x01);
  put(Permitted_operands, "3b", 0x01);
  // copy
  put(Permitted_operands, "89", 0x01);
  put(Permitted_operands, "8b", 0x01);
  // swap
  put(Permitted_operands, "87", 0x01);
  // pop
  put(Permitted_operands, "8f", 0x01);

  //// Class O: op, ModR/M and subop (not r32)
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       0     1     1
  put(Permitted_operands, "ff", 0x03);  // jump/push/call

  //// Class N: op, ModR/M and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     0     1
  put(Permitted_operands, "c7", 0x41);  // copy

  //// Class P: op, ModR/M, subop (not r32) and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     1     1
  put(Permitted_operands, "81", 0x43);  // combine

  // End Init Permitted Operands
}

:(code)
#define HAS(bitvector, bit)  ((bitvector) & (1 << (bit)))
#define SET(bitvector, bit)  ((bitvector) | (1 << (bit)))
#define CLEAR(bitvector, bit)  ((bitvector) & (~(1 << (bit))))

void check_operands(const line& inst, const word& op) {
  if (!is_hex_byte(op)) return;
  uint8_t expected_bitvector = get(Permitted_operands, op.data);
  if (HAS(expected_bitvector, MODRM)) {
    check_operands_modrm(inst, op);
    compare_bitvector_modrm(inst, expected_bitvector, op);
  }
  else {
    compare_bitvector(inst, expected_bitvector, op);
  }
}

//: Many instructions can be checked just by comparing bitvectors.

void compare_bitvector(const line& inst, uint8_t expected, const word& op) {
  if (all_hex_bytes(inst) && has_operands(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  uint8_t bitvector = compute_operand_bitvector(inst);
  if (trace_contains_errors()) return;  // duplicate operand type
  if (bitvector == expected) return;  // all good with this instruction
  for (int i = 0;  i < NUM_OPERAND_TYPES;  ++i, bitvector >>= 1, expected >>= 1) {
//?     cerr << "comparing " << HEXBYTE << NUM(bitvector) << " with " << NUM(expected) << '\n';
    if ((bitvector & 0x1) == (expected & 0x1)) continue;  // all good with this operand
    const string& optype = Operand_type_name.at(i);
    if ((bitvector & 0x1) > (expected & 0x1))
      raise << "'" << to_string(inst) << "'" << maybe_name(op) << ": unexpected " << optype << " operand\n" << end();
    else
      raise << "'" << to_string(inst) << "'" << maybe_name(op) << ": missing " << optype << " operand\n" << end();
    // continue giving all errors for a single instruction
  }
  // ignore settings in any unused bits
}

string maybe_name(const word& op) {
  if (!is_hex_byte(op)) return "";
  if (!contains_key(name, op.data)) return "";
  return " ("+get(name, op.data)+')';
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

uint32_t compute_operand_bitvector(const line& inst) {
  uint32_t bitvector = 0;
  for (int i = /*skip op*/1;  i < SIZE(inst.words);  ++i) {
    bitvector = bitvector | bitvector_for_operand(inst.words.at(i));
    if (trace_contains_errors()) return INVALID_OPERANDS;  // duplicate operand type
  }
  return bitvector;
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
  for (int i = 0;  i < SIZE(inst.words);  ++i)
    if (!is_hex_byte(inst.words.at(i)))
      return false;
  return true;
}

bool contains_any_operand_metadata(const word& word) {
  for (int i = 0;  i < SIZE(word.metadata);  ++i)
    if (Instruction_operands.find(word.metadata.at(i)) != Instruction_operands.end())
      return true;
  return false;
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
void check_operands_modrm(const line& inst, const word& op) {
  if (all_hex_bytes(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  check_metadata_present(inst, "mod", op);
  check_metadata_present(inst, "rm32", op);
  // no check for r32; some instructions don't use it; just assume it's 0 if missing
  if (op.data == "81" || op.data == "8f" || op.data == "ff") {  // keep sync'd with 'help subop'
    check_metadata_present(inst, "subop", op);
    check_metadata_absent(inst, "r32", op, "should be replaced by subop");
  }
  if (trace_contains_errors()) return;
  if (metadata(inst, "rm32").data != "4") return;
  // SIB byte checks
  uint8_t mod = hex_byte(metadata(inst, "mod").data);
  if (mod != /*direct*/3) {
    check_metadata_present(inst, "base", op);
    check_metadata_present(inst, "index", op);  // otherwise why go to SIB?
  }
  else {
    check_metadata_absent(inst, "base", op, "direct mode");
    check_metadata_absent(inst, "index", op, "direct mode");
  }
  // no check for scale; 0 (2**0 = 1) by default
}

// same as compare_bitvector, with a couple of exceptions for modrm-based instructions
//   exception 1: ignore modrm bit since we already checked it above
//   exception 2: modrm instructions can use a displacement on occasion
void compare_bitvector_modrm(const line& inst, uint8_t expected, const word& op) {
  if (all_hex_bytes(inst) && has_operands(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  uint8_t bitvector = compute_operand_bitvector(inst);
  if (trace_contains_errors()) return;  // duplicate operand type
  expected = CLEAR(expected, MODRM);  // exception 1
  if (bitvector == expected) return;  // all good with this instruction
  for (int i = 0;  i < NUM_OPERAND_TYPES;  ++i, bitvector >>= 1, expected >>= 1) {
//?     cerr << "comparing for modrm " << HEXBYTE << NUM(bitvector) << " with " << NUM(expected) << '\n';
    if ((bitvector & 0x1) == (expected & 0x1)) continue;  // all good with this operand
    if (i == DISP8 || i == DISP16 || i == DISP32) continue;  // exception 2
    const string& optype = Operand_type_name.at(i);
    if ((bitvector & 0x1) > (expected & 0x1))
      raise << "'" << to_string(inst) << "'" << maybe_name(op) << ": unexpected " << optype << " operand\n" << end();
    else
      raise << "'" << to_string(inst) << "'" << maybe_name(op) << ": missing " << optype << " operand\n" << end();
    // continue giving all errors for a single instruction
  }
  // ignore settings in any unused bits
}

void check_metadata_present(const line& inst, const string& type, const word& op) {
  if (!has_metadata(inst, type))
    raise << "'" << to_string(inst) << "' (" << get(name, op.data) << "): missing " << type << " operand\n" << end();
}

void check_metadata_absent(const line& inst, const string& type, const word& op, const string& msg) {
  if (has_metadata(inst, type))
    raise << "'" << to_string(inst) << "' (" << get(name, op.data) << "): unexpected " << type << " operand (" << msg << ")\n" << end();
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

:(scenarios transform)
:(scenario modrm_with_displacement)
% Reg[EAX].u = 0x1;
== 0x1
# just avoid null pointer
8b/copy 1/mod/lookup+disp8 0/rm32/eax 2/r32/edx 4/disp8  # copy *(EAX+4) to EDX
$error: 0
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

:(scenario check_base_operand_not_needed_in_direct_mode)
== 0x1
81 0/add/subop 3/mod/indirect 4/rm32/use-sib 1/imm32
$error: 0

//:: similarly handle multi-byte opcodes

:(code)
void check_operands_0f(const line& inst) {
  assert(inst.words.at(0).data == "0f");
  if (SIZE(inst.words) == 1) {
    raise << "opcode '0f' requires a second opcode\n" << end();
    return;
  }
  word op = preprocess_op(inst.words.at(1));
  if (!contains_key(name_0f, op.data)) {
    raise << "unknown 2-byte opcode '0f " << op.data << "'\n" << end();
    return;
  }
  check_operands_0f(inst, op);
}

void check_operands_f3(const line& /*unused*/) {
  raise << "no supported opcodes starting with f3\n" << end();
}

:(scenario check_missing_disp16_operand)
% Hide_errors = true;
== 0x1
# instruction                     effective address                                           operand     displacement    immediate
# op          subop               mod             rm32          base      index     scale     r32
# 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
  0f 84                                                                                                                                     # jmp if ZF to ??
+error: '0f 84' (jump disp16 bytes away if ZF is set): missing disp16 operand

:(before "End Globals")
map</*op*/string, /*bitvector*/uint8_t> Permitted_operands_0f;
:(before "End Init Permitted Operands")
//// Class C: just op and disp16
//  imm32 imm8  disp32 |disp16  disp8 subop modrm
//  0     0     0      |1       0     0     0
put(Permitted_operands_0f, "84", 0x08);
put(Permitted_operands_0f, "85", 0x08);
put(Permitted_operands_0f, "8c", 0x08);
put(Permitted_operands_0f, "8d", 0x08);
put(Permitted_operands_0f, "8e", 0x08);
put(Permitted_operands_0f, "8f", 0x08);

//// Class M: using ModR/M byte
//  imm32 imm8  disp32 |disp16  disp8 subop modrm
//  0     0     0      |0       0     0     1
put(Permitted_operands_0f, "af", 0x01);

:(code)
void check_operands_0f(const line& inst, const word& op) {
  uint8_t expected_bitvector = get(Permitted_operands_0f, op.data);
  if (HAS(expected_bitvector, MODRM))
    check_operands_modrm(inst, op);
  compare_bitvector_0f(inst, CLEAR(expected_bitvector, MODRM), op);
}

void compare_bitvector_0f(const line& inst, uint8_t expected, const word& op) {
  if (all_hex_bytes(inst) && has_operands(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  uint8_t bitvector = compute_operand_bitvector(inst);
  if (trace_contains_errors()) return;  // duplicate operand type
  if (bitvector == expected) return;  // all good with this instruction
  for (int i = 0;  i < NUM_OPERAND_TYPES;  ++i, bitvector >>= 1, expected >>= 1) {
//?     cerr << "comparing " << HEXBYTE << NUM(bitvector) << " with " << NUM(expected) << '\n';
    if ((bitvector & 0x1) == (expected & 0x1)) continue;  // all good with this operand
    const string& optype = Operand_type_name.at(i);
    if ((bitvector & 0x1) > (expected & 0x1))
      raise << "'" << to_string(inst) << "' (" << get(name_0f, op.data) << "): unexpected " << optype << " operand\n" << end();
    else
      raise << "'" << to_string(inst) << "' (" << get(name_0f, op.data) << "): missing " << optype << " operand\n" << end();
    // continue giving all errors for a single instruction
  }
  // ignore settings in any unused bits
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

#undef HAS
#undef SET
#undef CLEAR

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

:(before "End Includes")
#include<cctype>

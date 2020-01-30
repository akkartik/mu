//: Since we're tagging operands with their types, let's start checking these
//: operand types for each instruction.

void test_check_missing_imm8_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "cd\n"  // interrupt ??
  );
  CHECK_TRACE_CONTENTS(
      "error: 'cd' (software interrupt): missing imm8 operand\n"
  );
}

:(before "Pack Operands(segment code)")
check_operands(code);
if (trace_contains_errors()) return;

:(code)
void check_operands(const segment& code) {
  trace(3, "transform") << "-- check operands" << end();
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
  // opcodes can't be negative
  if (starts_with(op.data, "0x"))
    op.data = op.data.substr(2);
  if (SIZE(op.data) == 1)
    op.data = string("0")+op.data;
  return op;
}

void test_preprocess_op() {
  word w1;  w1.data = "0xf";
  word w2;  w2.data = "0f";
  CHECK_EQ(preprocess_op(w1).data, preprocess_op(w2).data);
}

//: To check the operands for an opcode, we'll track the permitted operands
//: for each supported opcode in a bitvector. That way we can often compute the
//: 'received' operand bitvector for each instruction's operands and compare
//: it with the 'expected' bitvector.
//:
//: The 'expected' and 'received' bitvectors can be different; the MODRM bit
//: in the 'expected' bitvector maps to multiple 'received' operand types in
//: an instruction. We deal in expected bitvectors throughout.

:(before "End Types")
enum expected_operand_type {
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
map<string, expected_operand_type> Operand_type;
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
  // inc
  put(Permitted_operands, "40", 0x00);
  put(Permitted_operands, "41", 0x00);
  put(Permitted_operands, "42", 0x00);
  put(Permitted_operands, "43", 0x00);
  put(Permitted_operands, "44", 0x00);
  put(Permitted_operands, "45", 0x00);
  put(Permitted_operands, "46", 0x00);
  put(Permitted_operands, "47", 0x00);
  // dec
  put(Permitted_operands, "48", 0x00);
  put(Permitted_operands, "49", 0x00);
  put(Permitted_operands, "4a", 0x00);
  put(Permitted_operands, "4b", 0x00);
  put(Permitted_operands, "4c", 0x00);
  put(Permitted_operands, "4d", 0x00);
  put(Permitted_operands, "4e", 0x00);
  put(Permitted_operands, "4f", 0x00);
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
  // sign-extend EAX into EDX
  put(Permitted_operands, "99", 0x00);
  // return
  put(Permitted_operands, "c3", 0x00);

  //// Class B: just op and disp8
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       1     0     0

  // jump
  put(Permitted_operands, "eb", 0x04);
  put(Permitted_operands, "72", 0x04);
  put(Permitted_operands, "73", 0x04);
  put(Permitted_operands, "74", 0x04);
  put(Permitted_operands, "75", 0x04);
  put(Permitted_operands, "76", 0x04);
  put(Permitted_operands, "77", 0x04);
  put(Permitted_operands, "7c", 0x04);
  put(Permitted_operands, "7d", 0x04);
  put(Permitted_operands, "7e", 0x04);
  put(Permitted_operands, "7f", 0x04);

  //// Class D: just op and disp32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     1      |0       0     0     0
  put(Permitted_operands, "e8", 0x10);  // call
  put(Permitted_operands, "e9", 0x10);  // jump

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
  // xor
  put(Permitted_operands, "31", 0x01);
  put(Permitted_operands, "33", 0x01);
  // compare
  put(Permitted_operands, "39", 0x01);
  put(Permitted_operands, "3b", 0x01);
  // copy
  put(Permitted_operands, "88", 0x01);
  put(Permitted_operands, "89", 0x01);
  put(Permitted_operands, "8a", 0x01);
  put(Permitted_operands, "8b", 0x01);
  // swap
  put(Permitted_operands, "87", 0x01);
  // copy address (lea)
  put(Permitted_operands, "8d", 0x01);

  //// Class N: op, ModR/M and subop (not r32)
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     0     0      |0       0     1     1
  put(Permitted_operands, "8f", 0x03);  // pop
  put(Permitted_operands, "d3", 0x03);  // shift
  put(Permitted_operands, "f7", 0x03);  // test/not/mul/div
  put(Permitted_operands, "ff", 0x03);  // jump/push/call

  //// Class O: op, ModR/M, subop (not r32) and imm8
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  0     1     0      |0       0     1     1
  put(Permitted_operands, "c1", 0x23);  // combine
  put(Permitted_operands, "c6", 0x23);  // copy

  //// Class P: op, ModR/M, subop (not r32) and imm32
  //  imm32 imm8  disp32 |disp16  disp8 subop modrm
  //  1     0     0      |0       0     1     1
  put(Permitted_operands, "81", 0x43);  // combine
  put(Permitted_operands, "c7", 0x43);  // copy

  // End Init Permitted Operands
}

#define HAS(bitvector, bit)  ((bitvector) & (1 << (bit)))
#define SET(bitvector, bit)  ((bitvector) | (1 << (bit)))
#define CLEAR(bitvector, bit)  ((bitvector) & (~(1 << (bit))))

void check_operands(const line& inst, const word& op) {
  if (!is_hex_byte(op)) return;
  uint8_t expected_bitvector = get(Permitted_operands, op.data);
  if (HAS(expected_bitvector, MODRM)) {
    check_operands_modrm(inst, op);
    compare_bitvector_modrm(inst, expected_bitvector, maybe_name(op));
  }
  else {
    compare_bitvector(inst, expected_bitvector, maybe_name(op));
  }
}

//: Many instructions can be checked just by comparing bitvectors.

void compare_bitvector(const line& inst, uint8_t expected, const string& maybe_op_name) {
  if (all_hex_bytes(inst) && has_operands(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  uint8_t bitvector = compute_expected_operand_bitvector(inst);
  if (trace_contains_errors()) return;  // duplicate operand type
  if (bitvector == expected) return;  // all good with this instruction
  for (int i = 0;  i < NUM_OPERAND_TYPES;  ++i, bitvector >>= 1, expected >>= 1) {
//?     cerr << "comparing " << HEXBYTE << NUM(bitvector) << " with " << NUM(expected) << '\n';
    if ((bitvector & 0x1) == (expected & 0x1)) continue;  // all good with this operand
    const string& optype = Operand_type_name.at(i);
    if ((bitvector & 0x1) > (expected & 0x1))
      raise << "'" << to_string(inst) << "'" << maybe_op_name << ": unexpected " << optype << " operand\n" << end();
    else
      raise << "'" << to_string(inst) << "'" << maybe_op_name << ": missing " << optype << " operand\n" << end();
    // continue giving all errors for a single instruction
  }
  // ignore settings in any unused bits
}

string maybe_name(const word& op) {
  if (!is_hex_byte(op)) return "";
  if (!contains_key(Name, op.data)) return "";
  // strip stuff in parens from the name
  const string& s = get(Name, op.data);
  return " ("+s.substr(0, s.find(" ("))+')';
}

uint32_t compute_expected_operand_bitvector(const line& inst) {
  set<string> operands_found;
  uint32_t bitvector = 0;
  for (int i = /*skip op*/1;  i < SIZE(inst.words);  ++i) {
    bitvector = bitvector | expected_bit_for_received_operand(inst.words.at(i), operands_found, inst);
    if (trace_contains_errors()) return INVALID_OPERANDS;  // duplicate operand type
  }
  return bitvector;
}

bool has_operands(const line& inst) {
  return SIZE(inst.words) > first_operand(inst);
}

int first_operand(const line& inst) {
  if (inst.words.at(0).data == "0f") return 2;
  if (inst.words.at(0).data == "f2" || inst.words.at(0).data == "f3") {
    if (inst.words.at(1).data == "0f")
      return 3;
    else
      return 2;
  }
  return 1;
}

// Scan the metadata of 'w' and return the expected bit corresponding to any operand type.
// Also raise an error if metadata contains multiple operand types.
uint32_t expected_bit_for_received_operand(const word& w, set<string>& instruction_operands, const line& inst) {
  uint32_t bv = 0;
  bool found = false;
  for (int i = 0;  i < SIZE(w.metadata);  ++i) {
    string/*copy*/ curr = w.metadata.at(i);
    string expected_metadata = curr;
    if (curr == "mod" || curr == "rm32" || curr == "r32" || curr == "scale" || curr == "index" || curr == "base")
      expected_metadata = "modrm";
    else if (!contains_key(Operand_type, curr)) continue;  // ignore unrecognized metadata
    if (found) {
      raise << "'" << w.original << "' has conflicting operand types; it should have only one\n" << end();
      return INVALID_OPERANDS;
    }
    if (instruction_operands.find(curr) != instruction_operands.end()) {
      raise << "'" << to_string(inst) << "': duplicate " << curr << " operand\n" << end();
      return INVALID_OPERANDS;
    }
    instruction_operands.insert(curr);
    bv = (1 << get(Operand_type, expected_metadata));
    found = true;
  }
  return bv;
}

void test_conflicting_operand_type() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "cd/software-interrupt 80/imm8/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '80/imm8/imm32' has conflicting operand types; it should have only one\n"
  );
}

//: Instructions computing effective addresses have more complex rules, so
//: we'll hard-code a common set of instruction-decoding rules.

void test_check_missing_mod_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "81 0/add/subop       3/rm32/ebx 1/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '81 0/add/subop 3/rm32/ebx 1/imm32' (combine rm32 with imm32 based on subop): missing mod operand\n"
  );
}

void check_operands_modrm(const line& inst, const word& op) {
  if (all_hex_bytes(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  check_operand_metadata_present(inst, "mod", op);
  check_operand_metadata_present(inst, "rm32", op);
  // no check for r32; some instructions don't use it; just assume it's 0 if missing
  if (op.data == "81" || op.data == "8f" || op.data == "ff") {  // keep sync'd with 'help subop'
    check_operand_metadata_present(inst, "subop", op);
    check_operand_metadata_absent(inst, "r32", op, "should be replaced by subop");
  }
  if (trace_contains_errors()) return;
  if (metadata(inst, "rm32").data != "4") return;
  // SIB byte checks
  uint8_t mod = hex_byte(metadata(inst, "mod").data);
  if (mod != /*direct*/3) {
    check_operand_metadata_present(inst, "base", op);
    check_operand_metadata_present(inst, "index", op);  // otherwise why go to SIB?
  }
  else {
    check_operand_metadata_absent(inst, "base", op, "direct mode");
    check_operand_metadata_absent(inst, "index", op, "direct mode");
  }
  // no check for scale; 0 (2**0 = 1) by default
}

// same as compare_bitvector, with one additional exception for modrm-based
// instructions: they may use an extra displacement on occasion
void compare_bitvector_modrm(const line& inst, uint8_t expected, const string& maybe_op_name) {
  if (all_hex_bytes(inst) && has_operands(inst)) return;  // deliberately programming in raw hex; we'll raise a warning elsewhere
  uint8_t bitvector = compute_expected_operand_bitvector(inst);
  if (trace_contains_errors()) return;  // duplicate operand type
  // update 'expected' bitvector for the additional exception
  if (has_operand_metadata(inst, "mod")) {
    int32_t mod = parse_int(metadata(inst, "mod").data);
    switch (mod) {
    case 0:
      if (has_operand_metadata(inst, "rm32") && parse_int(metadata(inst, "rm32").data) == 5)
        expected |= (1<<DISP32);
      break;
    case 1:
      expected |= (1<<DISP8);
      break;
    case 2:
      expected |= (1<<DISP32);
      break;
    }
  }
  if (bitvector == expected) return;  // all good with this instruction
  for (int i = 0;  i < NUM_OPERAND_TYPES;  ++i, bitvector >>= 1, expected >>= 1) {
//?     cerr << "comparing for modrm " << HEXBYTE << NUM(bitvector) << " with " << NUM(expected) << '\n';
    if ((bitvector & 0x1) == (expected & 0x1)) continue;  // all good with this operand
    const string& optype = Operand_type_name.at(i);
    if ((bitvector & 0x1) > (expected & 0x1))
      raise << "'" << to_string(inst) << "'" << maybe_op_name << ": unexpected " << optype << " operand\n" << end();
    else
      raise << "'" << to_string(inst) << "'" << maybe_op_name << ": missing " << optype << " operand\n" << end();
    // continue giving all errors for a single instruction
  }
  // ignore settings in any unused bits
}

void check_operand_metadata_present(const line& inst, const string& type, const word& op) {
  if (!has_operand_metadata(inst, type))
    raise << "'" << to_string(inst) << "'" << maybe_name(op) << ": missing " << type << " operand\n" << end();
}

void check_operand_metadata_absent(const line& inst, const string& type, const word& op, const string& msg) {
  if (has_operand_metadata(inst, type))
    raise << "'" << to_string(inst) << "'" << maybe_name(op) << ": unexpected " << type << " operand (" << msg << ")\n" << end();
}

void test_modrm_with_displacement() {
  Reg[EAX].u = 0x1;
  transform(
      "== code 0x1\n"
      // just avoid null pointer
      "8b/copy 1/mod/lookup+disp8 0/rm32/EAX 2/r32/EDX 4/disp8\n"  // copy *(EAX+4) to EDX
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_check_missing_disp8() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "89/copy 1/mod/lookup+disp8 0/rm32/EAX 1/r32/ECX\n"  // missing disp8
  );
  CHECK_TRACE_CONTENTS(
      "error: '89/copy 1/mod/lookup+disp8 0/rm32/EAX 1/r32/ECX' (copy r32 to rm32): missing disp8 operand\n"
  );
}

void test_check_missing_disp32() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "8b/copy 0/mod/indirect 5/rm32/.disp32 2/r32/EDX\n"  // missing disp32
  );
  CHECK_TRACE_CONTENTS(
      "error: '8b/copy 0/mod/indirect 5/rm32/.disp32 2/r32/EDX' (copy rm32 to r32): missing disp32 operand\n"
  );
}

void test_conflicting_operands_in_modrm_instruction() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "01/add 0/mod 3/mod\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '01/add 0/mod 3/mod' has conflicting mod operands\n"
  );
}

void test_conflicting_operand_type_modrm() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "01/add 0/mod 3/rm32/r32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '3/rm32/r32' has conflicting operand types; it should have only one\n"
  );
}

void test_check_missing_rm32_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "81 0/add/subop 0/mod            1/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '81 0/add/subop 0/mod 1/imm32' (combine rm32 with imm32 based on subop): missing rm32 operand\n"
  );
}

void test_check_missing_subop_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "81             0/mod 3/rm32/ebx 1/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '81 0/mod 3/rm32/ebx 1/imm32' (combine rm32 with imm32 based on subop): missing subop operand\n"
  );
}

void test_check_missing_base_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "81 0/add/subop 0/mod/indirect 4/rm32/use-sib 1/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '81 0/add/subop 0/mod/indirect 4/rm32/use-sib 1/imm32' (combine rm32 with imm32 based on subop): missing base operand\n"
  );
}

void test_check_missing_index_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "81 0/add/subop 0/mod/indirect 4/rm32/use-sib 0/base 1/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '81 0/add/subop 0/mod/indirect 4/rm32/use-sib 0/base 1/imm32' (combine rm32 with imm32 based on subop): missing index operand\n"
  );
}

void test_check_missing_base_operand_2() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "81 0/add/subop 0/mod/indirect 4/rm32/use-sib 2/index 3/scale 1/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '81 0/add/subop 0/mod/indirect 4/rm32/use-sib 2/index 3/scale 1/imm32' (combine rm32 with imm32 based on subop): missing base operand\n"
  );
}

void test_check_extra_displacement() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "89/copy 0/mod/indirect 0/rm32/EAX 1/r32/ECX 4/disp8\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '89/copy 0/mod/indirect 0/rm32/EAX 1/r32/ECX 4/disp8' (copy r32 to rm32): unexpected disp8 operand\n"
  );
}

void test_check_duplicate_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "89/copy 0/mod/indirect 0/rm32/EAX 1/r32/ECX 1/r32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '89/copy 0/mod/indirect 0/rm32/EAX 1/r32/ECX 1/r32': duplicate r32 operand\n"
  );
}

void test_check_base_operand_not_needed_in_direct_mode() {
  run(
      "== code 0x1\n"
      "81 0/add/subop 3/mod/indirect 4/rm32/use-sib 1/imm32\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_extra_modrm() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "59/pop-to-ECX  3/mod/direct 1/rm32/ECX 4/r32/ESP\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '59/pop-to-ECX 3/mod/direct 1/rm32/ECX 4/r32/ESP' (pop top of stack to ECX): unexpected modrm operand\n"
  );
}

//:: similarly handle multi-byte opcodes

void check_operands_0f(const line& inst) {
  assert(inst.words.at(0).data == "0f");
  if (SIZE(inst.words) == 1) {
    raise << "opcode '0f' requires a second opcode\n" << end();
    return;
  }
  word op = preprocess_op(inst.words.at(1));
  if (!contains_key(Name_0f, op.data)) {
    raise << "unknown 2-byte opcode '0f " << op.data << "'\n" << end();
    return;
  }
  check_operands_0f(inst, op);
}

void check_operands_f3(const line& /*unused*/) {
  raise << "no supported opcodes starting with f3\n" << end();
}

void test_check_missing_disp32_operand() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "  0f 84  # jmp if ZF to ??\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '0f 84' (jump disp32 bytes away if equal, if ZF is set): missing disp32 operand\n"
  );
}

:(before "End Globals")
map</*op*/string, /*bitvector*/uint8_t> Permitted_operands_0f;
:(before "End Init Permitted Operands")
//// Class D: just op and disp32
//  imm32 imm8  disp32 |disp16  disp8 subop modrm
//  0     0     1      |0       0     0     0
put_new(Permitted_operands_0f, "82", 0x10);
put_new(Permitted_operands_0f, "83", 0x10);
put_new(Permitted_operands_0f, "84", 0x10);
put_new(Permitted_operands_0f, "85", 0x10);
put_new(Permitted_operands_0f, "86", 0x10);
put_new(Permitted_operands_0f, "87", 0x10);
put_new(Permitted_operands_0f, "8c", 0x10);
put_new(Permitted_operands_0f, "8d", 0x10);
put_new(Permitted_operands_0f, "8e", 0x10);
put_new(Permitted_operands_0f, "8f", 0x10);

//// Class M: using ModR/M byte
//  imm32 imm8  disp32 |disp16  disp8 subop modrm
//  0     0     0      |0       0     0     1
put_new(Permitted_operands_0f, "af", 0x01);

:(code)
void check_operands_0f(const line& inst, const word& op) {
  uint8_t expected_bitvector = get(Permitted_operands_0f, op.data);
  if (HAS(expected_bitvector, MODRM))
    check_operands_modrm(inst, op);
  compare_bitvector(inst, CLEAR(expected_bitvector, MODRM), maybe_name_0f(op));
}

string maybe_name_0f(const word& op) {
  if (!is_hex_byte(op)) return "";
  if (!contains_key(Name_0f, op.data)) return "";
  // strip stuff in parens from the name
  const string& s = get(Name_0f, op.data);
  return " ("+s.substr(0, s.find(" ("))+')';
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

:(before "End Includes")
#include<cctype>

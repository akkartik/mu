//:: Check that the different arguments of an instruction aren't too large for their bitfields.

void test_check_bitfield_sizes() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "01/add 4/mod 3/rm32 1/r32\n"  // add ECX to EBX
  );
  CHECK_TRACE_CONTENTS(
      "error: '4/mod' too large to fit in bitfield mod\n"
  );
}

:(before "End Globals")
map<string, uint32_t> Operand_bound;
:(before "End One-time Setup")
put_new(Operand_bound, "subop", 1<<3);
put_new(Operand_bound, "mod", 1<<2);
put_new(Operand_bound, "rm32", 1<<3);
put_new(Operand_bound, "base", 1<<3);
put_new(Operand_bound, "index", 1<<3);
put_new(Operand_bound, "scale", 1<<2);
put_new(Operand_bound, "r32", 1<<3);
put_new(Operand_bound, "disp8", 1<<8);
put_new(Operand_bound, "disp16", 1<<16);
// no bound needed for disp32
put_new(Operand_bound, "imm8", 1<<8);
// no bound needed for imm32

:(before "Pack Operands(segment code)")
check_argument_bounds(code);
if (trace_contains_errors()) return;
:(code)
void check_argument_bounds(const segment& code) {
  trace(3, "transform") << "-- check argument bounds" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    for (int j = first_argument(inst);  j < SIZE(inst.words);  ++j)
      check_argument_bounds(inst.words.at(j));
    if (trace_contains_errors()) return;  // stop at the first mal-formed instruction
  }
}

void check_argument_bounds(const word& w) {
  for (map<string, uint32_t>::iterator p = Operand_bound.begin();  p != Operand_bound.end();  ++p) {
    if (!has_argument_metadata(w, p->first)) continue;
    if (!looks_like_hex_int(w.data)) continue;  // later transforms are on their own to do their own bounds checking
    int32_t x = parse_int(w.data);
    if (x >= 0) {
      if (p->first == "disp8" || p->first == "disp16") {
        if (static_cast<uint32_t>(x) >= p->second/2)
          raise << "'" << w.original << "' too large to fit in signed bitfield " << p->first << '\n' << end();
      }
      else {
        if (static_cast<uint32_t>(x) >= p->second)
          raise << "'" << w.original << "' too large to fit in bitfield " << p->first << '\n' << end();
      }
    }
    else {
      // hacky? assuming bound is a power of 2
      if (x < -1*static_cast<int32_t>(p->second/2))
        raise << "'" << w.original << "' too large to fit in bitfield " << p->first << '\n' << end();
    }
  }
}

void test_check_bitfield_sizes_for_imm8() {
  run(
      "== code 0x1\n"
      "c1/shift 4/subop/left 3/mod/direct 1/rm32/ECX 0xff/imm8"  // shift EBX left
  );
  CHECK(!trace_contains_errors());
}

void test_check_bitfield_sizes_for_imm8_error() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "c1/shift 4/subop/left 3/mod/direct 1/rm32/ECX 0x100/imm8"  // shift EBX left
  );
  CHECK_TRACE_CONTENTS(
      "error: '0x100/imm8' too large to fit in bitfield imm8\n"
  );
}

void test_check_bitfield_sizes_for_negative_imm8() {
  run(
      "== code 0x1\n"
      "c1/shift 4/subop/left 3/mod/direct 1/rm32/ECX -0x80/imm8"  // shift EBX left
  );
  CHECK(!trace_contains_errors());
}

void test_check_bitfield_sizes_for_negative_imm8_error() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "c1/shift 4/subop/left 3/mod/direct 1/rm32/ECX -0x81/imm8"  // shift EBX left
  );
  CHECK_TRACE_CONTENTS(
      "error: '-0x81/imm8' too large to fit in bitfield imm8\n"
  );
}

void test_check_bitfield_sizes_for_disp8() {
  // not bothering to run
  transform(
      "== code 0x1\n"
      "01/add 1/mod/*+disp8 3/rm32 1/r32 0x7f/disp8\n"  // add ECX to *(EBX+0x7f)
  );
  CHECK(!trace_contains_errors());
}

void test_check_bitfield_sizes_for_disp8_error() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "01/add 1/mod/*+disp8 3/rm32 1/r32 0x80/disp8\n"  // add ECX to *(EBX+0x80)
  );
  CHECK_TRACE_CONTENTS(
      "error: '0x80/disp8' too large to fit in signed bitfield disp8\n"
  );
}

void test_check_bitfield_sizes_for_negative_disp8() {
  // not bothering to run
  transform(
      "== code 0x1\n"
      "01/add 1/mod/*+disp8 3/rm32 1/r32 -0x80/disp8\n"  // add ECX to *(EBX-0x80)
  );
  CHECK(!trace_contains_errors());
}

void test_check_bitfield_sizes_for_negative_disp8_error() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "01/add 1/mod/*+disp8 3/rm32 1/r32 -0x81/disp8\n"  // add ECX to *(EBX-0x81)
  );
  CHECK_TRACE_CONTENTS(
      "error: '-0x81/disp8' too large to fit in bitfield disp8\n"
  );
}

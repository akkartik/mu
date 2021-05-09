//: jump to 32-bit offset

//:: jump

:(before "End Initialize Op Names")
put_new(Name, "e9", "jump disp32 bytes away (jmp)");

:(code)
void test_jump_disp32() {
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  e9                   05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: e9\n"
      "run: jump 5\n"
      "run: 0x0000000b opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000006 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0xe9: {  // jump disp32
  const int32_t offset = next32();
  trace(Callstack_depth+1, "run") << "jump " << offset << end();
  EIP += offset;
  break;
}

//:: jump if equal/zero

:(before "End Initialize Op Names")
put_new(Name_0f, "84", "jump disp32 bytes away if equal, if ZF is set (jcc/jz/je)");

:(code)
void test_je_disp32_success() {
  ZF = true;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 84                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x84: {  // jump disp32 if ZF
  const int32_t offset = next32();
  if (ZF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_je_disp32_fail() {
  ZF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 84                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: 0x00000007 opcode: 05\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if not equal/not zero

:(before "End Initialize Op Names")
put_new(Name_0f, "85", "jump disp32 bytes away if not equal, if ZF is not set (jcc/jnz/jne)");

:(code)
void test_jne_disp32_success() {
  ZF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 85                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x85: {  // jump disp32 if !ZF
  const int32_t offset = next32();
  if (!ZF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jne_disp32_fail() {
  ZF = true;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 85                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: 0x00000007 opcode: 05\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if greater

:(before "End Initialize Op Names")
put_new(Name_0f, "8f", "jump disp32 bytes away if greater, if ZF is unset and SF == OF (jcc/jg/jnle)");
put_new(Name_0f, "87", "jump disp32 bytes away if greater (addr, float), if ZF is unset and CF is unset (jcc/ja/jnbe)");

:(code)
void test_jg_disp32_success() {
  ZF = false;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8f                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8f: {  // jump disp32 if !SF and !ZF
  const int32_t offset = next32();
  if (!ZF && SF == OF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}
case 0x87: {  // jump disp32 if !CF and !ZF
  const int32_t offset = next32();
  if (!CF && !ZF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jg_disp32_fail() {
  ZF = false;
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8f                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: 0x00000007 opcode: 05\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if greater or equal

:(before "End Initialize Op Names")
put_new(Name_0f, "8d", "jump disp32 bytes away if greater or equal, if SF == OF (jcc/jge/jnl)");
put_new(Name_0f, "83", "jump disp32 bytes away if greater or equal (addr, float), if CF is unset (jcc/jae/jnb)");

:(code)
void test_jge_disp32_success() {
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8d                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8d: {  // jump disp32 if !SF
  const int32_t offset = next32();
  if (SF == OF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}
case 0x83: {  // jump disp32 if !CF
  const int32_t offset = next32();
  if (!CF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jge_disp32_fail() {
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8d                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: 0x00000007 opcode: 05\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if lesser

:(before "End Initialize Op Names")
put_new(Name_0f, "8c", "jump disp32 bytes away if lesser, if SF != OF (jcc/jl/jnge)");
put_new(Name_0f, "82", "jump disp32 bytes away if lesser (addr, float), if CF is set (jcc/jb/jnae)");

:(code)
void test_jl_disp32_success() {
  ZF = false;
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8c                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8c: {  // jump disp32 if SF and !ZF
  const int32_t offset = next32();
  if (SF != OF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}
case 0x82: {  // jump disp32 if CF
  const int32_t offset = next32();
  if (CF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jl_disp32_fail() {
  ZF = false;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8c                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: 0x00000007 opcode: 05\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if lesser or equal

:(before "End Initialize Op Names")
put_new(Name_0f, "8e", "jump disp32 bytes away if lesser or equal, if ZF is set or SF != OF (jcc/jle/jng)");
put_new(Name_0f, "86", "jump disp32 bytes away if lesser or equal (addr, float), if ZF is set or CF is set (jcc/jbe/jna)");

:(code)
void test_jle_disp32_equal() {
  ZF = true;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8e                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(code)
void test_jle_disp32_lesser() {
  ZF = false;
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8e                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: jump 5\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000007 opcode: 05");
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x8e: {  // jump disp32 if SF or ZF
  const int32_t offset = next32();
  if (ZF || SF != OF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}
case 0x86: {  // jump disp32 if ZF or CF
  const int32_t offset = next32();
  if (ZF || CF) {
    trace(Callstack_depth+1, "run") << "jump " << offset << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jle_disp32_greater() {
  ZF = false;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 8e                05 00 00 00               \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 0f\n"
      "run: 0x00000007 opcode: 05\n"
      "run: 0x0000000c opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if overflow

:(before "End Initialize Op Names")
put_new(Name_0f, "80", "jump disp32 bytes away if OF is set (jcc/jo)");
put_new(Name_0f, "81", "jump disp32 bytes away if OF is unset (jcc/jno)");

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x80: {  // jump disp8 if OF is set
  const int32_t offset = next32();
  if (OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}
case 0x81: {  // jump disp8 if OF is unset
  const int32_t offset = next32();
  if (!OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

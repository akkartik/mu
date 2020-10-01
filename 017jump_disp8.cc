//: jump to 8-bit offset

//:: jump

:(before "End Initialize Op Names")
put_new(Name, "eb", "jump disp8 bytes away (jmp)");

:(code)
void test_jump_disp8() {
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  eb                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: eb\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0xeb: {  // jump disp8
  int8_t offset = static_cast<int>(next());
  trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
  EIP += offset;
  break;
}

//:: jump if equal/zero

:(before "End Initialize Op Names")
put_new(Name, "74", "jump disp8 bytes away if equal, if ZF is set (jcc/jz/je)");

:(code)
void test_je_disp8_success() {
  ZF = true;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  74                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 74\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0x74: {  // jump disp8 if ZF
  const int8_t offset = static_cast<int>(next());
  if (ZF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_je_disp8_fail() {
  ZF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  74                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 74\n"
      "run: 0x00000003 opcode: 05\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if not equal/not zero

:(before "End Initialize Op Names")
put_new(Name, "75", "jump disp8 bytes away if not equal, if ZF is not set (jcc/jnz/jne)");

:(code)
void test_jne_disp8_success() {
  ZF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  75                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 75\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0x75: {  // jump disp8 if !ZF
  const int8_t offset = static_cast<int>(next());
  if (!ZF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jne_disp8_fail() {
  ZF = true;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  75                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 75\n"
      "run: 0x00000003 opcode: 05\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if greater

:(before "End Initialize Op Names")
put_new(Name, "7f", "jump disp8 bytes away if greater, if ZF is unset and SF == OF (jcc/jg/jnle)");
put_new(Name, "77", "jump disp8 bytes away if greater (addr, float), if ZF is unset and CF is unset (jcc/ja/jnbe)");

:(code)
void test_jg_disp8_success() {
  ZF = false;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7f                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7f\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0x7f: {  // jump disp8 if SF == OF and !ZF
  const int8_t offset = static_cast<int>(next());
  if (SF == OF && !ZF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}
case 0x77: {  // jump disp8 if !CF and !ZF
  const int8_t offset = static_cast<int>(next());
  if (!CF && !ZF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jg_disp8_fail() {
  ZF = false;
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7f                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7f\n"
      "run: 0x00000003 opcode: 05\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if greater or equal

:(before "End Initialize Op Names")
put_new(Name, "7d", "jump disp8 bytes away if greater or equal, if SF == OF (jcc/jge/jnl)");
put_new(Name, "73", "jump disp8 bytes away if greater or equal (addr, float), if CF is unset (jcc/jae/jnb)");

:(code)
void test_jge_disp8_success() {
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7d                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7d\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0x7d: {  // jump disp8 if SF == OF
  const int8_t offset = static_cast<int>(next());
  if (SF == OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}
case 0x73: {  // jump disp8 if !CF
  const int8_t offset = static_cast<int>(next());
  if (!CF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jge_disp8_fail() {
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7d                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7d\n"
      "run: 0x00000003 opcode: 05\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if lesser

:(before "End Initialize Op Names")
put_new(Name, "7c", "jump disp8 bytes away if lesser, if SF != OF (jcc/jl/jnge)");
put_new(Name, "72", "jump disp8 bytes away if lesser (addr, float), if CF is set (jcc/jb/jnae)");

:(code)
void test_jl_disp8_success() {
  ZF = false;
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7c                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7c\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0x7c: {  // jump disp8 if SF != OF
  const int8_t offset = static_cast<int>(next());
  if (SF != OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}
case 0x72: {  // jump disp8 if CF
  const int8_t offset = static_cast<int>(next());
  if (CF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jl_disp8_fail() {
  ZF = false;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7c                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7c\n"
      "run: 0x00000003 opcode: 05\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//:: jump if lesser or equal

:(before "End Initialize Op Names")
put_new(Name, "7e", "jump disp8 bytes away if lesser or equal, if ZF is set or SF != OF (jcc/jle/jng)");
put_new(Name, "76", "jump disp8 bytes away if lesser or equal (addr, float), if ZF is set or CF is set (jcc/jbe/jna)");

:(code)
void test_jle_disp8_equal() {
  ZF = true;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7e                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7e\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(code)
void test_jle_disp8_lesser() {
  ZF = false;
  SF = true;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7e                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7e\n"
      "run: jump 5\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: 05");
}

:(before "End Single-Byte Opcodes")
case 0x7e: {  // jump disp8 if ZF or SF != OF
  const int8_t offset = static_cast<int>(next());
  if (ZF || SF != OF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}
case 0x76: {  // jump disp8 if ZF or CF
  const int8_t offset = static_cast<int>(next());
  if (ZF || CF) {
    trace(Callstack_depth+1, "run") << "jump " << NUM(offset) << end();
    EIP += offset;
  }
  break;
}

:(code)
void test_jle_disp8_greater() {
  ZF = false;
  SF = false;
  OF = false;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  7e                   05                        \n"  // skip 1 instruction
      "  05                                 00 00 00 01 \n"
      "  05                                 00 00 00 02 \n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: 7e\n"
      "run: 0x00000003 opcode: 05\n"
      "run: 0x00000008 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: jump 5");
}

//: instructions that (immediately) contain an argument to act with

:(before "End Initialize Op Names")
put_new(Name, "05", "add imm32 to EAX (add)");

:(before "End Single-Byte Opcodes")
case 0x05: {  // add imm32 to EAX
  int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "add imm32 0x" << HEXWORD << signed_arg2 << " to EAX" << end();
  int32_t signed_result = Reg[EAX].i + signed_arg2;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(Reg[EAX].i) + signed_arg2;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg2 = static_cast<uint32_t>(signed_arg2);
  uint32_t unsigned_result = Reg[EAX].u + unsigned_arg2;
  uint64_t unsigned_full_result = static_cast<uint64_t>(Reg[EAX].u) + unsigned_arg2;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  Reg[EAX].i = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[EAX].i << end();
  break;
}

:(code)
void test_add_imm32_to_EAX_signed_overflow() {
  Reg[EAX].i = INT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  05                                 01 00 00 00 \n" // add 1 to EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: add imm32 0x00000001 to EAX\n"
      "run: SF=1; ZF=0; CF=0; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

void test_add_imm32_to_EAX_unsigned_overflow() {
  Reg[EAX].u = UINT32_MAX;
  Reg[EBX].u = 1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  05                                 01 00 00 00 \n" // add 1 to EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: add imm32 0x00000001 to EAX\n"
      "run: SF=0; ZF=1; CF=1; OF=0\n"
      "run: storing 0x00000000\n"
  );
}

void test_add_imm32_to_EAX_unsigned_and_signed_overflow() {
  Reg[EAX].i = INT32_MIN;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  05                                 00 00 00 80 \n" // add 0x80000000 to EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: add imm32 0x80000000 to EAX\n"
      "run: SF=0; ZF=1; CF=1; OF=1\n"
      "run: storing 0x00000000\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "81", "combine rm32 with imm32 based on subop (add/sub/and/or/xor/cmp)");

:(code)
void test_add_imm32_to_r32() {
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     c3                          0a 0b 0c 0d\n"  // add 0x0d0c0b0a to EBX
      // ModR/M in binary: 11 (direct mode) 000 (subop add) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop add\n"
      "run: storing 0x0d0c0b0b\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x81: {  // combine r/m32 with imm32
  trace(Callstack_depth+1, "run") << "combine r/m32 with imm32" << end();
  const uint8_t modrm = next();
  int32_t* signed_arg1 = effective_address(modrm);
  const int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "imm32 is 0x" << HEXWORD << signed_arg2 << end();
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
  case 0: {
    trace(Callstack_depth+1, "run") << "subop add" << end();
    int32_t signed_result = *signed_arg1 + signed_arg2;
    SF = (signed_result < 0);
    ZF = (signed_result == 0);
    int64_t signed_full_result = static_cast<int64_t>(*signed_arg1) + signed_arg2;
    OF = (signed_result != signed_full_result);
    // set CF
    uint32_t unsigned_arg1 = static_cast<uint32_t>(*signed_arg1);
    uint32_t unsigned_arg2 = static_cast<uint32_t>(signed_arg2);
    uint32_t unsigned_result = unsigned_arg1 + unsigned_arg2;
    uint64_t unsigned_full_result = static_cast<uint64_t>(unsigned_arg1) + unsigned_arg2;
    CF = (unsigned_result != unsigned_full_result);
    trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
    *signed_arg1 = signed_result;
    trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
    break;
  }
  // End Op 81 Subops
  default:
    cerr << "unrecognized subop for opcode 81: " << NUM(subop) << '\n';
    exit(1);
  }
  break;
}

:(code)
void test_add_imm32_to_r32_signed_overflow() {
  Reg[EBX].i = INT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     c3                          01 00 00 00\n"  // add 1 to EBX
      // ModR/M in binary: 11 (direct mode) 000 (subop add) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x00000001\n"
      "run: subop add\n"
      "run: SF=1; ZF=0; CF=0; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

void test_add_imm32_to_r32_unsigned_overflow() {
  Reg[EBX].u = UINT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     c3                          01 00 00 00\n"  // add 1 to EBX
      // ModR/M in binary: 11 (direct mode) 011 (subop add) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x00000001\n"
      "run: subop add\n"
      "run: SF=0; ZF=1; CF=1; OF=0\n"
      "run: storing 0x00000000\n"
  );
}

void test_add_imm32_to_r32_unsigned_and_signed_overflow() {
  Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     c3                          00 00 00 80\n"  // add 0x80000000 to EBX
      // ModR/M in binary: 11 (direct mode) 011 (subop add) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x80000000\n"
      "run: subop add\n"
      "run: SF=0; ZF=1; CF=1; OF=1\n"
      "run: storing 0x00000000\n"
  );
}

//:

:(code)
void test_add_imm32_to_mem_at_rm32() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     03                          0a 0b 0c 0d \n"  // add 0x0d0c0b0a to *EBX
      // ModR/M in binary: 00 (indirect mode) 000 (subop add) 011 (dest EBX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop add\n"
      "run: storing 0x0d0c0b0b\n"
  );
}

//:: subtract

:(before "End Initialize Op Names")
put_new(Name, "2d", "subtract imm32 from EAX (sub)");

:(code)
void test_subtract_imm32_from_EAX() {
  Reg[EAX].i = 0x0d0c0baa;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2d                                 0a 0b 0c 0d \n"  // subtract 0x0d0c0b0a from EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract imm32 0x0d0c0b0a from EAX\n"
      "run: storing 0x000000a0\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x2d: {  // subtract imm32 from EAX
  const int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "subtract imm32 0x" << HEXWORD << signed_arg2 << " from EAX" << end();
  int32_t signed_result = Reg[EAX].i - signed_arg2;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(Reg[EAX].i) - signed_arg2;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg2 = static_cast<uint32_t>(signed_arg2);
  uint32_t unsigned_result = Reg[EAX].u - unsigned_arg2;
  uint64_t unsigned_full_result = static_cast<uint64_t>(Reg[EAX].u) - unsigned_arg2;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  Reg[EAX].i = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[EAX].i << end();
  break;
}

:(code)
void test_subtract_imm32_from_EAX_signed_overflow() {
  Reg[EAX].i = INT32_MIN;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2d                                 01 00 00 00 \n"  // subtract 1 from EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract imm32 0x00000001 from EAX\n"
      "run: SF=0; ZF=0; CF=0; OF=1\n"
      "run: storing 0x7fffffff\n"  // INT32_MAX
  );
}

void test_subtract_imm32_from_EAX_unsigned_overflow() {
  Reg[EAX].i = 0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2d                                 01 00 00 00 \n"  // subtract 1 from EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract imm32 0x00000001 from EAX\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
      "run: storing 0xffffffff\n"
  );
}

void test_subtract_imm32_from_EAX_signed_and_unsigned_overflow() {
  Reg[EAX].i = 0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2d                                 00 00 00 80 \n"  // subtract INT32_MIN from EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract imm32 0x80000000 from EAX\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

//:

void test_subtract_imm32_from_mem_at_rm32() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     2b                          01 00 00 00 \n"  // subtract 1 from *EBX
      // ModR/M in binary: 00 (indirect mode) 101 (subop subtract) 011 (dest EBX)
      "== data 0x2000\n"
      "0a 00 00 00\n"  // 0xa
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x00000001\n"
      "run: subop subtract\n"
      "run: storing 0x00000009\n"
  );
}

:(before "End Op 81 Subops")
case 5: {
  trace(Callstack_depth+1, "run") << "subop subtract" << end();
  int32_t signed_result = *signed_arg1 - signed_arg2;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(*signed_arg1) - signed_arg2;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg1 = static_cast<uint32_t>(*signed_arg1);
  uint32_t unsigned_arg2 = static_cast<uint32_t>(signed_arg2);
  uint32_t unsigned_result = unsigned_arg1 - unsigned_arg2;
  uint64_t unsigned_full_result = static_cast<uint64_t>(unsigned_arg1) - unsigned_arg2;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  *signed_arg1 = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  break;
}

:(code)
void test_subtract_imm32_from_mem_at_rm32_signed_overflow() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     2b                          ff ff ff 7f \n"  // subtract INT32_MAX from *EBX
      // ModR/M in binary: 00 (indirect mode) 101 (subop subtract) 011 (dest EBX)
      "== data 0x2000\n"
      "00 00 00 80\n"  // INT32_MIN
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: effective address contains 0x80000000\n"
      "run: imm32 is 0x7fffffff\n"
      "run: subop subtract\n"
      "run: SF=0; ZF=0; CF=0; OF=1\n"
      "run: storing 0x00000001\n"
  );
}

void test_subtract_imm32_from_mem_at_rm32_unsigned_overflow() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     2b                          01 00 00 00 \n"  // subtract 1 from *EBX
      // ModR/M in binary: 00 (indirect mode) 101 (subop subtract) 011 (dest EBX)
      "== data 0x2000\n"
      "00 00 00 00\n"  // 0
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: effective address contains 0x00000000\n"
      "run: imm32 is 0x00000001\n"
      "run: subop subtract\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
      "run: storing 0xffffffff\n"
  );
}

void test_subtract_imm32_from_mem_at_rm32_signed_and_unsigned_overflow() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     2b                          00 00 00 80 \n"  // subtract INT32_MIN from *EBX
      // ModR/M in binary: 00 (indirect mode) 101 (subop subtract) 011 (dest EBX)
      "== data 0x2000\n"
      "00 00 00 00\n"  // 0
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: effective address contains 0x00000000\n"
      "run: imm32 is 0x80000000\n"
      "run: subop subtract\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

//:

void test_subtract_imm32_from_r32() {
  Reg[EBX].i = 10;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     eb                          01 00 00 00 \n"  // subtract 1 from EBX
      // ModR/M in binary: 11 (direct mode) 101 (subop subtract) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x00000001\n"
      "run: subop subtract\n"
      "run: storing 0x00000009\n"
  );
}

//:: shift left

:(before "End Initialize Op Names")
put_new(Name, "c1", "shift rm32 by imm8 bits depending on subop (sal/sar/shl/shr)");

:(code)
void test_shift_left_r32_with_imm8() {
  Reg[EBX].i = 13;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     e3                          01          \n"  // shift EBX left by 1 bit
      // ModR/M in binary: 11 (direct mode) 100 (subop shift left) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift left by CL bits\n"
      "run: storing 0x0000001a\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xc1: {
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "operate on r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
  case 4: {  // shift left r/m32 by CL
    trace(Callstack_depth+1, "run") << "subop: shift left by CL bits" << end();
    uint8_t count = next() & 0x1f;
    // OF is only defined if count is 1
    if (count == 1) {
      bool msb = (*arg1 & 0x80000000) >> 1;
      bool pnsb = (*arg1 & 0x40000000);
      OF = (msb != pnsb);
    }
    *arg1 = (*arg1 << count);
    ZF = (*arg1 == 0);
    SF = (*arg1 < 0);
    // CF undefined
    trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
    trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
    break;
  }
  // End Op c1 Subops
  default:
    cerr << "unrecognized subop for opcode c1: " << NUM(subop) << '\n';
    exit(1);
  }
  break;
}

//:: shift right arithmetic

:(code)
void test_shift_right_arithmetic_r32_with_imm8() {
  Reg[EBX].i = 26;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     fb                          01          \n"  // shift EBX right by 1 bit
      // ModR/M in binary: 11 (direct mode) 111 (subop shift right arithmetic) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while preserving sign\n"
      "run: storing 0x0000000d\n"
  );
}

:(before "End Op c1 Subops")
case 7: {  // shift right r/m32 by CL, preserving sign
  trace(Callstack_depth+1, "run") << "subop: shift right by CL bits, while preserving sign" << end();
  uint8_t count = next() & 0x1f;
  int32_t result = (*arg1 >> count);
  ZF = (*arg1 == 0);
  SF = (*arg1 < 0);
  // OF is only defined if count is 1
  if (count == 1) OF = false;
  // CF
  CF = ((*arg1 >> (count-1)) & 0x1);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  *arg1 = result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

:(code)
void test_shift_right_arithmetic_odd_r32_with_imm8() {
  Reg[EBX].i = 27;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     fb                          01          \n"  // shift EBX right by 1 bit
      // ModR/M in binary: 11 (direct mode) 111 (subop shift right arithmetic) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while preserving sign\n"
      // result: 13
      "run: storing 0x0000000d\n"
  );
}

:(code)
void test_shift_right_arithmetic_negative_r32_with_imm8() {
  Reg[EBX].i = 0xfffffffd;  // -3
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     fb                          01          \n"  // shift EBX right by 1 bit, while preserving sign
      // ModR/M in binary: 11 (direct mode) 111 (subop shift right arithmetic) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while preserving sign\n"
      // result: -2
      "run: storing 0xfffffffe\n"
  );
}

//:: shift right logical

:(code)
void test_shift_right_logical_r32_with_imm8() {
  Reg[EBX].i = 26;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     eb                          01          \n"  // shift EBX right by 1 bit, while padding zeroes
      // ModR/M in binary: 11 (direct mode) 101 (subop shift right logical) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while padding zeroes\n"
      "run: storing 0x0000000d\n"
  );
}

:(before "End Op c1 Subops")
case 5: {  // shift right r/m32 by CL, preserving sign
  trace(Callstack_depth+1, "run") << "subop: shift right by CL bits, while padding zeroes" << end();
  uint8_t count = next() & 0x1f;
  // OF is only defined if count is 1
  if (count == 1) {
    bool msb = (*arg1 & 0x80000000) >> 1;
    bool pnsb = (*arg1 & 0x40000000);
    OF = (msb != pnsb);
  }
  uint32_t* uarg1 = reinterpret_cast<uint32_t*>(arg1);
  *uarg1 = (*uarg1 >> count);
  ZF = (*uarg1 == 0);
  // result is always positive by definition
  SF = false;
  // CF undefined
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

:(code)
void test_shift_right_logical_odd_r32_with_imm8() {
  Reg[EBX].i = 27;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     eb                          01          \n"  // shift EBX right by 1 bit, while padding zeroes
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while padding zeroes\n"
      // result: 13
      "run: storing 0x0000000d\n"
  );
}

:(code)
void test_shift_right_logical_negative_r32_with_imm8() {
  Reg[EBX].i = 0xfffffffd;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c1     eb                          01          \n"  // shift EBX right by 1 bit, while padding zeroes
      // ModR/M in binary: 11 (direct mode) 101 (subop shift right logical) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while padding zeroes\n"
      "run: storing 0x7ffffffe\n"
  );
}

//:: and

:(before "End Initialize Op Names")
put_new(Name, "25", "EAX = bitwise AND of imm32 with EAX (and)");

:(code)
void test_and_EAX_with_imm32() {
  Reg[EAX].i = 0xff;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  25                                 0a 0b 0c 0d \n"  // and 0x0d0c0b0a with EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: and imm32 0x0d0c0b0a with EAX\n"
      "run: storing 0x0000000a\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x25: {  // and imm32 with EAX
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  const int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "and imm32 0x" << HEXWORD << signed_arg2 << " with EAX" << end();
  Reg[EAX].i &= signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[EAX].i << end();
  SF = (Reg[EAX].i >> 31);
  ZF = (Reg[EAX].i == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:

:(code)
void test_and_imm32_with_mem_at_rm32() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     23                          0a 0b 0c 0d \n"  // and 0x0d0c0b0a with *EBX
      // ModR/M in binary: 00 (indirect mode) 100 (subop and) 011 (dest EBX)
      "== data 0x2000\n"
      "ff 00 00 00\n"  // 0xff
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop and\n"
      "run: storing 0x0000000a\n"
  );
}

:(before "End Op 81 Subops")
case 4: {
  trace(Callstack_depth+1, "run") << "subop and" << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  *signed_arg1 &= signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  SF = (*signed_arg1 >> 31);
  ZF = (*signed_arg1 == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:

:(code)
void test_and_imm32_with_r32() {
  Reg[EBX].i = 0xff;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     e3                          0a 0b 0c 0d \n"  // and 0x0d0c0b0a with EBX
      // ModR/M in binary: 11 (direct mode) 100 (subop and) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop and\n"
      "run: storing 0x0000000a\n"
  );
}

//:: or

:(before "End Initialize Op Names")
put_new(Name, "0d", "EAX = bitwise OR of imm32 with EAX (or)");

:(code)
void test_or_EAX_with_imm32() {
  Reg[EAX].i = 0xd0c0b0a0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0d                                 0a 0b 0c 0d \n"  // or 0x0d0c0b0a with EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: or imm32 0x0d0c0b0a with EAX\n"
      "run: storing 0xddccbbaa\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x0d: {  // or imm32 with EAX
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  const int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "or imm32 0x" << HEXWORD << signed_arg2 << " with EAX" << end();
  Reg[EAX].i |= signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[EAX].i << end();
  SF = (Reg[EAX].i >> 31);
  ZF = (Reg[EAX].i == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:

:(code)
void test_or_imm32_with_mem_at_rm32() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     0b                          0a 0b 0c 0d \n"  // or 0x0d0c0b0a with *EBX
      // ModR/M in binary: 00 (indirect mode) 001 (subop or) 011 (dest EBX)
      "== data 0x2000\n"
      "a0 b0 c0 d0\n"  // 0xd0c0b0a0
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop or\n"
      "run: storing 0xddccbbaa\n"
  );
}

:(before "End Op 81 Subops")
case 1: {
  trace(Callstack_depth+1, "run") << "subop or" << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  *signed_arg1 |= signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  SF = (*signed_arg1 >> 31);
  ZF = (*signed_arg1 == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

:(code)
void test_or_imm32_with_r32() {
  Reg[EBX].i = 0xd0c0b0a0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     cb                          0a 0b 0c 0d \n"  // or 0x0d0c0b0a with EBX
      // ModR/M in binary: 11 (direct mode) 001 (subop or) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop or\n"
      "run: storing 0xddccbbaa\n"
  );
}

//:: xor

:(before "End Initialize Op Names")
put_new(Name, "35", "EAX = bitwise XOR of imm32 with EAX (xor)");

:(code)
void test_xor_EAX_with_imm32() {
  Reg[EAX].i = 0xddccb0a0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  35                                 0a 0b 0c 0d \n"  // xor 0x0d0c0b0a with EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: xor imm32 0x0d0c0b0a with EAX\n"
      "run: storing 0xd0c0bbaa\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x35: {  // xor imm32 with EAX
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  const int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "xor imm32 0x" << HEXWORD << signed_arg2 << " with EAX" << end();
  Reg[EAX].i ^= signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[EAX].i << end();
  SF = (Reg[EAX].i >> 31);
  ZF = (Reg[EAX].i == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:

:(code)
void test_xor_imm32_with_mem_at_rm32() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     33                          0a 0b 0c 0d \n"  // xor 0x0d0c0b0a with *EBX
      // ModR/M in binary: 00 (indirect mode) 110 (subop xor) 011 (dest EBX)
      "== data 0x2000\n"
      "a0 b0 c0 d0\n"  // 0xd0c0b0a0
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop xor\n"
      "run: storing 0xddccbbaa\n"
  );
}

:(before "End Op 81 Subops")
case 6: {
  trace(Callstack_depth+1, "run") << "subop xor" << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  *signed_arg1 ^= signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  SF = (*signed_arg1 >> 31);
  ZF = (*signed_arg1 == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

:(code)
void test_xor_imm32_with_r32() {
  Reg[EBX].i = 0xd0c0b0a0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     f3                          0a 0b 0c 0d \n"  // xor 0x0d0c0b0a with EBX
      // ModR/M in binary: 11 (direct mode) 110 (subop xor) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: subop xor\n"
      "run: storing 0xddccbbaa\n"
  );
}

//:: compare (cmp)

:(before "End Initialize Op Names")
put_new(Name, "3d", "compare: set SF if EAX < imm32 (cmp)");

:(code)
void test_compare_EAX_with_imm32_greater() {
  Reg[EAX].i = 0x0d0c0b0a;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3d                                 07 0b 0c 0d \n"  // compare EAX with 0x0d0c0b07
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EAX with imm32 0x0d0c0b07\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x3d: {  // compare EAX with imm32
  const int32_t signed_arg1 = Reg[EAX].i;
  const int32_t signed_arg2 = next32();
  trace(Callstack_depth+1, "run") << "compare EAX with imm32 0x" << HEXWORD << signed_arg2 << end();
  const int32_t signed_difference = signed_arg1 - signed_arg2;
  SF = (signed_difference < 0);
  ZF = (signed_difference == 0);
  const int64_t full_signed_difference = static_cast<int64_t>(signed_arg1) - signed_arg2;
  OF = (signed_difference != full_signed_difference);
  const uint32_t unsigned_arg1 = static_cast<uint32_t>(signed_arg1);
  const uint32_t unsigned_arg2 = static_cast<uint32_t>(signed_arg2);
  const uint32_t unsigned_difference = unsigned_arg1 - unsigned_arg2;
  const uint64_t full_unsigned_difference = static_cast<uint64_t>(unsigned_arg1) - unsigned_arg2;
  CF = (unsigned_difference != full_unsigned_difference);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

:(code)
void test_compare_EAX_with_imm32_lesser_unsigned_and_signed() {
  Reg[EAX].i = 0x0a0b0c07;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3d                                 0d 0c 0b 0a \n"  // compare EAX with imm32
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EAX with imm32 0x0a0b0c0d\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_EAX_with_imm32_lesser_unsigned_and_signed_due_to_overflow() {
  Reg[EAX].i = INT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3d                                 00 00 00 80\n"  // compare EAX with INT32_MIN
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EAX with imm32 0x80000000\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
  );
}

void test_compare_EAX_with_imm32_lesser_signed() {
  Reg[EAX].i = -1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3d                                 01 00 00 00\n"  // compare EAX with 1
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EAX with imm32 0x00000001\n"
      "run: SF=1; ZF=0; CF=0; OF=0\n"
  );
}

void test_compare_EAX_with_imm32_lesser_unsigned() {
  Reg[EAX].i = 1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3d                                 ff ff ff ff\n"  // compare EAX with -1
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EAX with imm32 0xffffffff\n"
      "run: SF=0; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_EAX_with_imm32_equal() {
  Reg[EAX].i = 0x0d0c0b0a;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3d                                 0a 0b 0c 0d \n"  // compare 0x0d0c0b0a with EAX
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EAX with imm32 0x0d0c0b0a\n"
      "run: SF=0; ZF=1; CF=0; OF=0\n"
  );
}

//:

void test_compare_imm32_with_r32_greater() {
  Reg[EBX].i = 0x0d0c0b0a;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     fb                          07 0b 0c 0d \n"  // compare 0x0d0c0b07 with EBX
      // ModR/M in binary: 11 (direct mode) 111 (subop compare) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x0d0c0b07\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(before "End Op 81 Subops")
case 7: {
  trace(Callstack_depth+1, "run") << "subop compare" << end();
  const int32_t tmp1 = *signed_arg1 - signed_arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  const int64_t tmp2 = static_cast<int64_t>(*signed_arg1) - signed_arg2;
  OF = (tmp1 != tmp2);
  const uint32_t unsigned_arg1 = static_cast<uint32_t>(*signed_arg1);
  const uint32_t unsigned_arg2 = static_cast<uint32_t>(signed_arg2);
  const uint32_t tmp3 = unsigned_arg1 - unsigned_arg2;
  const uint64_t tmp4 = static_cast<uint64_t>(unsigned_arg1) - unsigned_arg2;
  CF = (tmp3 != tmp4);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

:(code)
void test_compare_rm32_with_imm32_lesser_unsigned_and_signed() {
  Reg[EAX].i = 0x0a0b0c07;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     f8                          0d 0c 0b 0a \n"  // compare EAX with imm32
      // ModR/M in binary: 11 (direct mode) 111 (subop compare) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EAX\n"
      "run: imm32 is 0x0a0b0c0d\n"
      "run: subop compare\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_rm32_with_imm32_lesser_unsigned_and_signed_due_to_overflow() {
  Reg[EAX].i = INT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     f8                          00 00 00 80\n"  // compare EAX with INT32_MIN
      // ModR/M in binary: 11 (direct mode) 111 (subop compare) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EAX\n"
      "run: imm32 is 0x80000000\n"
      "run: subop compare\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
  );
}

void test_compare_rm32_with_imm32_lesser_signed() {
  Reg[EAX].i = -1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     f8                          01 00 00 00\n"  // compare EAX with 1
      // ModR/M in binary: 11 (direct mode) 111 (subop compare) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EAX\n"
      "run: imm32 is 0x00000001\n"
      "run: subop compare\n"
      "run: SF=1; ZF=0; CF=0; OF=0\n"
  );
}

void test_compare_rm32_with_imm32_lesser_unsigned() {
  Reg[EAX].i = 1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     f8                          ff ff ff ff\n"  // compare EAX with -1
      // ModR/M in binary: 11 (direct mode) 111 (subop compare) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EAX\n"
      "run: imm32 is 0xffffffff\n"
      "run: subop compare\n"
      "run: SF=0; ZF=0; CF=1; OF=0\n"
  );
}

:(code)
void test_compare_imm32_with_r32_equal() {
  Reg[EBX].i = 0x0d0c0b0a;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     fb                          0a 0b 0c 0d \n"  // compare 0x0d0c0b0a with EBX
      // ModR/M in binary: 11 (direct mode) 111 (subop compare) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: r/m32 is EBX\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: SF=0; ZF=1; CF=0; OF=0\n"
  );
}

:(code)
void test_compare_imm32_with_mem_at_rm32_greater() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     3b                          07 0b 0c 0d \n"  // compare 0x0d0c0b07 with *EBX
      // ModR/M in binary: 00 (indirect mode) 111 (subop compare) 011 (dest EBX)
      "== data 0x2000\n"
      "0a 0b 0c 0d\n"  // 0x0d0c0b0a
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x0d0c0b07\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(code)
void test_compare_imm32_with_mem_at_rm32_lesser() {
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     38                          0a 0b 0c 0d \n"  // compare 0x0d0c0b0a with *EAX
      // ModR/M in binary: 00 (indirect mode) 111 (subop compare) 000 (dest EAX)
      "== data 0x2000\n"
      "07 0b 0c 0d\n"  // 0x0d0c0b07
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
  );
}

:(code)
void test_compare_imm32_with_mem_at_rm32_equal() {
  Reg[EBX].i = 0x0d0c0b0a;
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  81     3b                          0a 0b 0c 0d \n"  // compare 0x0d0c0b0a with *EBX
      // ModR/M in binary: 00 (indirect mode) 111 (subop compare) 011 (dest EBX)
      "== data 0x2000\n"
      "0a 0b 0c 0d\n"  // 0x0d0c0b0a
  );
  CHECK_TRACE_CONTENTS(
      "run: combine r/m32 with imm32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
      "run: SF=0; ZF=1; CF=0; OF=0\n"
  );
}

//:: copy (mov)

:(before "End Initialize Op Names")
// b8 defined earlier to copy imm32 to EAX
put_new(Name, "b9", "copy imm32 to ECX (mov)");
put_new(Name, "ba", "copy imm32 to EDX (mov)");
put_new(Name, "bb", "copy imm32 to EBX (mov)");
put_new(Name, "bc", "copy imm32 to ESP (mov)");
put_new(Name, "bd", "copy imm32 to EBP (mov)");
put_new(Name, "be", "copy imm32 to ESI (mov)");
put_new(Name, "bf", "copy imm32 to EDI (mov)");

:(code)
void test_copy_imm32_to_r32() {
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  bb                                 0a 0b 0c 0d \n"  // copy 0x0d0c0b0a to EBX
  );
  CHECK_TRACE_CONTENTS(
      "run: copy imm32 0x0d0c0b0a to EBX\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xb9:
case 0xba:
case 0xbb:
case 0xbc:
case 0xbd:
case 0xbe:
case 0xbf: {  // copy imm32 to r32
  const uint8_t rdest = op & 0x7;
  const int32_t src = next32();
  trace(Callstack_depth+1, "run") << "copy imm32 0x" << HEXWORD << src << " to " << rname(rdest) << end();
  Reg[rdest].i = src;
  break;
}

//:

:(before "End Initialize Op Names")
put_new(Name, "c7", "copy imm32 to rm32 with subop 0 (mov)");

:(code)
void test_copy_imm32_to_mem_at_rm32() {
  Reg[EBX].i = 0x60;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c7     03                          0a 0b 0c 0d \n"  // copy 0x0d0c0b0a to *EBX
      // ModR/M in binary: 00 (indirect mode) 000 (subop) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: copy imm32 to r/m32\n"
      "run: effective address is 0x00000060 (EBX)\n"
      "run: imm32 is 0x0d0c0b0a\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xc7: {  // copy imm32 to r32
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "copy imm32 to r/m32" << end();
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  if (subop != 0) {
    cerr << "unrecognized subop for opcode c7: " << NUM(subop) << " (only 0/copy currently implemented)\n";
    exit(1);
  }
  int32_t* dest = effective_address(modrm);
  const int32_t src = next32();
  trace(Callstack_depth+1, "run") << "imm32 is 0x" << HEXWORD << src << end();
  *dest = src;  // Write multiple elements of vector<uint8_t> at once. Assumes sizeof(int) == 4 on the host as well.
  break;
}

//:: push

:(before "End Initialize Op Names")
put_new(Name, "68", "push imm32 to stack (push)");

:(code)
void test_push_imm32() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000014;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  68                                 af 00 00 00 \n"  // push *EAX to stack
  );
  CHECK_TRACE_CONTENTS(
      "run: push imm32 0x000000af\n"
      "run: ESP is now 0xbd000010\n"
      "run: contents at ESP: 0x000000af\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x68: {
  const uint32_t val = static_cast<uint32_t>(next32());
  trace(Callstack_depth+1, "run") << "push imm32 0x" << HEXWORD << val << end();
//?   cerr << "push: " << val << " => " << Reg[ESP].u << '\n';
  push(val);
  trace(Callstack_depth+1, "run") << "ESP is now 0x" << HEXWORD << Reg[ESP].u << end();
  trace(Callstack_depth+1, "run") << "contents at ESP: 0x" << HEXWORD << read_mem_u32(Reg[ESP].u) << end();
  break;
}

//:: multiply

:(before "End Initialize Op Names")
put_new(Name, "69", "multiply rm32 by imm32 and store result in r32 (imul)");

:(code)
void test_multiply_imm32() {
  Reg[EAX].i = 2;
  Reg[EBX].i = 3;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  69     c3                          04 00 00 00 \n"  // EAX = EBX * 4
      // ModR/M in binary: 11 (direct) 000 (dest EAX) 011 (src EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: multiply r/m32 by 0x00000004 and store result in EAX\n"
      "run: r/m32 is EBX\n"
      "run: storing 0x0000000c\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x69: {
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  const int32_t val = next32();
  trace(Callstack_depth+1, "run") << "multiply r/m32 by 0x" << HEXWORD << val << " and store result in " << rname(rdest) << end();
  const int32_t* signed_arg1 = effective_address(modrm);
  int32_t result = *signed_arg1 * val;
  int64_t full_result = static_cast<int64_t>(*signed_arg1) * val;
  OF = (result != full_result);
  CF = OF;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  Reg[rdest].i = result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[rdest].i << end();
  break;
}

//: operating on memory at the address provided by some register
//: we'll now start providing data in a separate segment

void test_add_r32_to_mem_at_rm32() {
  Reg[EBX].i = 0x10;
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     18                                    \n"  // add EBX to *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod Special-cases(addr)")
case 0:  // indirect addressing
  switch (rm) {
  default:  // address in register
    trace(Callstack_depth+1, "run") << "effective address is 0x" << HEXWORD << Reg[rm].u << " (" << rname(rm) << ")" << end();
    addr = Reg[rm].u;
    break;
  // End Mod 0 Special-cases(addr)
  }
  break;

//:

:(before "End Initialize Op Names")
put_new(Name, "03", "add rm32 to r32 (add)");

:(code)
void test_add_mem_at_rm32_to_r32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x10;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  03     18                                    \n"  // add *EAX to EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add r/m32 to EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x03: {  // add r/m32 to r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "add r/m32 to " << rname(arg1) << end();
  const int32_t* signed_arg2 = effective_address(modrm);
  int32_t signed_result = Reg[arg1].i + *signed_arg2;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(Reg[arg1].i) + *signed_arg2;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg2 = static_cast<uint32_t>(*signed_arg2);
  uint32_t unsigned_result = Reg[arg1].u + unsigned_arg2;
  uint64_t unsigned_full_result = static_cast<uint64_t>(Reg[arg1].u) + unsigned_arg2;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  Reg[arg1].i = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[arg1].i << end();
  break;
}

:(code)
void test_add_mem_at_rm32_to_r32_signed_overflow() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = INT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  03     18                                    \n" // add *EAX to EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add r/m32 to EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x00000001\n"
      "run: SF=1; ZF=0; CF=0; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

void test_add_mem_at_rm32_to_r32_unsigned_overflow() {
  Reg[EAX].u = 0x2000;
  Reg[EBX].u = UINT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  03     18                                    \n" // add *EAX to EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: add r/m32 to EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x00000001\n"
      "run: SF=0; ZF=1; CF=1; OF=0\n"
      "run: storing 0x00000000\n"
  );
}

void test_add_mem_at_rm32_to_r32_unsigned_and_signed_overflow() {
  Reg[EAX].u = 0x2000;
  Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  03     18                                    \n" // add *EAX to EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "00 00 00 80\n"  // INT32_MIN
  );
  CHECK_TRACE_CONTENTS(
      "run: add r/m32 to EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x80000000\n"
      "run: SF=0; ZF=1; CF=1; OF=1\n"
      "run: storing 0x00000000\n"
  );
}

//:: subtract

:(code)
void test_subtract_r32_from_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  29     18                                    \n"  // subtract EBX from *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0a 00 00 00\n"  // 0xa
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract EBX from r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x00000009\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "2b", "subtract rm32 from r32 (sub)");

:(code)
void test_subtract_mem_at_rm32_from_r32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 10;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2b     18                                    \n"  // subtract *EAX from EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract r/m32 from EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x00000009\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x2b: {  // subtract r/m32 from r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "subtract r/m32 from " << rname(arg1) << end();
  const int32_t* signed_arg2 = effective_address(modrm);
  const int32_t signed_result = Reg[arg1].i - *signed_arg2;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(Reg[arg1].i) - *signed_arg2;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg2 = static_cast<uint32_t>(*signed_arg2);
  uint32_t unsigned_result = Reg[arg1].u - unsigned_arg2;
  uint64_t unsigned_full_result = static_cast<uint64_t>(Reg[arg1].u) - unsigned_arg2;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  Reg[arg1].i = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[arg1].i << end();
  break;
}

:(code)
void test_subtract_mem_at_rm32_from_r32_signed_overflow() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2b     18                                    \n"  // subtract *EAX from EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "ff ff ff 7f\n"  // INT32_MAX
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract r/m32 from EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x7fffffff\n"
      "run: SF=0; ZF=0; CF=0; OF=1\n"
      "run: storing 0x00000001\n"
  );
}

void test_subtract_mem_at_rm32_from_r32_unsigned_overflow() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2b     18                                    \n"  // subtract *EAX from EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract r/m32 from EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x00000001\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
      "run: storing 0xffffffff\n"
  );
}

void test_subtract_mem_at_rm32_from_r32_signed_and_unsigned_overflow() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  2b     18                                    \n"  // subtract *EAX from EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "00 00 00 80\n"  // INT32_MIN
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract r/m32 from EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x80000000\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

//:: and
:(code)
void test_and_r32_with_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0xff;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  21     18                                    \n"  // and EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: and EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x0000000d\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "23", "r32 = bitwise AND of r32 with rm32 (and)");

:(code)
void test_and_mem_at_rm32_with_r32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  23     18                                    \n"  // and *EAX with EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "ff 00 00 00\n"  // 0xff
  );
  CHECK_TRACE_CONTENTS(
      "run: and r/m32 with EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x0000000d\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x23: {  // and r/m32 with r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "and r/m32 with " << rname(arg1) << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  const int32_t* signed_arg2 = effective_address(modrm);
  Reg[arg1].i &= *signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[arg1].i << end();
  SF = (Reg[arg1].i >> 31);
  ZF = (Reg[arg1].i == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:: or

:(code)
void test_or_r32_with_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0xa0b0c0d0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  09     18                                   #\n"  // EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: or EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0xaabbccdd\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "0b", "r32 = bitwise OR of r32 with rm32 (or)");

:(code)
void test_or_mem_at_rm32_with_r32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0xa0b0c0d0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0b     18                                    \n"  // or *EAX with EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: or r/m32 with EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0xaabbccdd\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x0b: {  // or r/m32 with r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "or r/m32 with " << rname(arg1) << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  const int32_t* signed_arg2 = effective_address(modrm);
  Reg[arg1].i |= *signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[arg1].i << end();
  SF = (Reg[arg1].i >> 31);
  ZF = (Reg[arg1].i == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:: xor

:(code)
void test_xor_r32_with_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0xa0b0c0d0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  31     18                                    \n"  // xor EBX with *EAX
      "== data 0x2000\n"
      "0d 0c bb aa\n"  // 0xaabb0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: xor EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x0a0bccdd\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "33", "r32 = bitwise XOR of r32 with rm32 (xor)");

:(code)
void test_xor_mem_at_rm32_with_r32() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0xa0b0c0d0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  33     18                                    \n"  // xor *EAX with EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: xor r/m32 with EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0xaabbccdd\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x33: {  // xor r/m32 with r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "xor r/m32 with " << rname(arg1) << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  const int32_t* signed_arg2 = effective_address(modrm);
  Reg[arg1].i |= *signed_arg2;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[arg1].i << end();
  SF = (Reg[arg1].i >> 31);
  ZF = (Reg[arg1].i == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:: not

:(code)
void test_not_of_mem_at_rm32() {
  Reg[EBX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  f7     13                                    \n"  // not *EBX
      // ModR/M in binary: 00 (indirect mode) 010 (subop not) 011 (dest EBX)
      "== data 0x2000\n"
      "ff 00 0f 0f\n"  // 0x0f0f00ff
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: effective address is 0x00002000 (EBX)\n"
      "run: subop: not\n"
      "run: storing 0xf0f0ff00\n"
  );
}

//:: compare (cmp)

:(code)
void test_compare_mem_at_rm32_with_r32_greater() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c07;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  39     18                                    \n"  // compare *EAX with EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(code)
void test_compare_mem_at_rm32_with_r32_lesser() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  39     18                                    \n"  // compare *EAX with EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "07 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
  );
}

:(code)
void test_compare_mem_at_rm32_with_r32_equal() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  39     18                                    \n"  // compare *EAX and EBX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: SF=0; ZF=1; CF=0; OF=0\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "3b", "compare: set SF if r32 < rm32 (cmp)");

:(code)
void test_compare_r32_with_mem_at_rm32_greater() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3b     18                                    \n"  // compare EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs EBX) 000 (rhs EAX)
      "== data 0x2000\n"
      "07 0c 0b 0a\n"  // 0x0a0b0c07
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x3b: {  // set SF if r32 < r/m32
  const uint8_t modrm = next();
  const uint8_t reg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "compare " << rname(reg1) << " with r/m32" << end();
  const int32_t* signed_arg2 = effective_address(modrm);
  const int32_t signed_difference = Reg[reg1].i - *signed_arg2;
  SF = (signed_difference < 0);
  ZF = (signed_difference == 0);
  int64_t full_signed_difference = static_cast<int64_t>(Reg[reg1].i) - *signed_arg2;
  OF = (signed_difference != full_signed_difference);
  const uint32_t unsigned_arg2 = static_cast<uint32_t>(*signed_arg2);
  const uint32_t unsigned_difference = Reg[reg1].u - unsigned_arg2;
  const uint64_t full_unsigned_difference = static_cast<uint64_t>(Reg[reg1].u) - unsigned_arg2;
  CF = (unsigned_difference != full_unsigned_difference);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

:(code)
void test_compare_r32_with_mem_at_rm32_lesser_unsigned_and_signed() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c07;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3b     18                                    \n"  // compare EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs EBX) 000 (rhs EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x0a0b0c0d\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_r32_with_mem_at_rm32_lesser_unsigned_and_signed_due_to_overflow() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = INT32_MAX;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3b     18                                    \n"  // compare EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs EBX) 000 (rhs EAX)
      "== data 0x2000\n"
      "00 00 00 80\n"  // INT32_MIN
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x80000000\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
  );
}

void test_compare_r32_with_mem_at_rm32_lesser_signed() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = -1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3b     18                                    \n"  // compare EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs EBX) 000 (rhs EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0x00000001\n"
      "run: SF=1; ZF=0; CF=0; OF=0\n"
  );
}

void test_compare_r32_with_mem_at_rm32_lesser_unsigned() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3b     18                                    \n"  // compare EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs EBX) 000 (rhs EAX)
      "== data 0x2000\n"
      "ff ff ff ff\n"  // -1
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: effective address contains 0xffffffff\n"
      "run: SF=0; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_r32_with_mem_at_rm32_equal() {
  Reg[EAX].i = 0x2000;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  3b     18                                    \n"  // compare EBX with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs EBX) 000 (rhs EAX)
      "== data 0x2000\n"
      "0d 0c 0b 0a\n"  // 0x0a0b0c0d
  );
  CHECK_TRACE_CONTENTS(
      "run: compare EBX with r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: SF=0; ZF=1; CF=0; OF=0\n"
  );
}

//:: copy (mov)

void test_copy_r32_to_mem_at_rm32() {
  Reg[EBX].i = 0xaf;
  Reg[EAX].i = 0x60;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  89     18                                    \n"  // copy EBX to *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: copy EBX to r/m32\n"
      "run: effective address is 0x00000060 (EAX)\n"
      "run: storing 0x000000af\n"
  );
}

//:

:(before "End Initialize Op Names")
put_new(Name, "8b", "copy rm32 to r32 (mov)");

:(code)
void test_copy_mem_at_rm32_to_r32() {
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  8b     18                                    \n"  // copy *EAX to EBX
      "== data 0x2000\n"
      "af 00 00 00\n"  // 0xaf
  );
  CHECK_TRACE_CONTENTS(
      "run: copy r/m32 to EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0x000000af\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x8b: {  // copy r32 to r/m32
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy r/m32 to " << rname(rdest) << end();
  const int32_t* src = effective_address(modrm);
  Reg[rdest].i = *src;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *src << end();
  break;
}

//:: jump

:(code)
void test_jump_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  ff     20                                    \n"  // jump to *EAX
      // ModR/M in binary: 00 (indirect mode) 100 (jump to r/m32) 000 (src EAX)
      "  b8                                 00 00 00 01\n"
      "  b8                                 00 00 00 02\n"
      "== data 0x2000\n"
      "08 00 00 00\n"  // 0x8
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000001 opcode: ff\n"
      "run: jump to r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: jumping to 0x00000008\n"
      "run: 0x00000008 opcode: b8\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000003 opcode: b8");
}

:(before "End Op ff Subops")
case 4: {  // jump to r/m32
  trace(Callstack_depth+1, "run") << "jump to r/m32" << end();
  const int32_t* arg2 = effective_address(modrm);
  EIP = *arg2;
  trace(Callstack_depth+1, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}

//:: push

:(code)
void test_push_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000014;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  ff     30                                    \n"  // push *EAX to stack
      "== data 0x2000\n"
      "af 00 00 00\n"  // 0xaf
  );
  CHECK_TRACE_CONTENTS(
      "run: push r/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: decrementing ESP to 0xbd000010\n"
      "run: pushing value 0x000000af\n"
  );
}

:(before "End Op ff Subops")
case 6: {  // push r/m32 to stack
  trace(Callstack_depth+1, "run") << "push r/m32" << end();
  const int32_t* val = effective_address(modrm);
  push(*val);
  break;
}

//:: pop

:(before "End Initialize Op Names")
put_new(Name, "8f", "pop top of stack to rm32 (pop)");

:(code)
void test_pop_mem_at_rm32() {
  Reg[EAX].i = 0x60;
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000000;
  write_mem_i32(0xbd000000, 0x00000030);
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  8f     00                                    \n"  // pop stack into *EAX
      // ModR/M in binary: 00 (indirect mode) 000 (pop r/m32) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: pop into r/m32\n"
      "run: effective address is 0x00000060 (EAX)\n"
      "run: popping value 0x00000030\n"
      "run: incrementing ESP to 0xbd000004\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x8f: {  // pop stack into r/m32
  const uint8_t modrm = next();
  const uint8_t subop = (modrm>>3)&0x7;
  switch (subop) {
    case 0: {
      trace(Callstack_depth+1, "run") << "pop into r/m32" << end();
      int32_t* dest = effective_address(modrm);
      *dest = pop();  // Write multiple elements of vector<uint8_t> at once. Assumes sizeof(int) == 4 on the host as well.
      break;
    }
  }
  break;
}

//:: special-case for loading address from disp32 rather than register

:(code)
void test_add_r32_to_mem_at_displacement() {
  Reg[EBX].i = 0x10;  // source
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     1d            00 20 00 00             \n"  // add EBX to *0x2000
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 101 (dest in disp32)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is 0x00002000 (disp32)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod 0 Special-cases(addr)")
case 5:  // exception: mod 0b00 rm 0b101 => incoming disp32
  addr = next32();
  trace(Callstack_depth+1, "run") << "effective address is 0x" << HEXWORD << addr << " (disp32)" << end();
  break;

//:

:(code)
void test_add_r32_to_mem_at_rm32_plus_disp8() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x1ffe;  // dest
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     58            02                      \n"  // add EBX to *(EAX+2)
      // ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00001ffe (EAX)\n"
      "run: effective address is 0x00002000 (after adding disp8)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod Special-cases(addr)")
case 1: {  // indirect + disp8 addressing
  switch (rm) {
  default:
    addr = Reg[rm].u;
    trace(Callstack_depth+1, "run") << "effective address is initially 0x" << HEXWORD << addr << " (" << rname(rm) << ")" << end();
    break;
  // End Mod 1 Special-cases(addr)
  }
  int8_t displacement = static_cast<int8_t>(next());
  if (addr > 0) {
    addr += displacement;
    trace(Callstack_depth+1, "run") << "effective address is 0x" << HEXWORD << addr << " (after adding disp8)" << end();
  }
  else {
    trace(Callstack_depth+1, "run") << "null address; skipping displacement" << end();
  }
  break;
}

:(code)
void test_add_r32_to_mem_at_rm32_plus_negative_disp8() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x2001;  // dest
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     58            ff                      \n"  // add EBX to *(EAX-1)
      // ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00002001 (EAX)\n"
      "run: effective address is 0x00002000 (after adding disp8)\n"
      "run: storing 0x00000011\n"
  );
}

//:

:(code)
void test_add_r32_to_mem_at_rm32_plus_disp32() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x1ffe;  // dest
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     98            02 00 00 00             \n"  // add EBX to *(EAX+2)
      // ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00001ffe (EAX)\n"
      "run: effective address is 0x00002000 (after adding disp32)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod Special-cases(addr)")
case 2: {  // indirect + disp32 addressing
  switch (rm) {
  default:
    addr = Reg[rm].u;
    trace(Callstack_depth+1, "run") << "effective address is initially 0x" << HEXWORD << addr << " (" << rname(rm) << ")" << end();
    break;
  // End Mod 2 Special-cases(addr)
  }
  int32_t displacement = static_cast<int32_t>(next32());
  if (addr > 0) {
    addr += displacement;
    trace(Callstack_depth+1, "run") << "effective address is 0x" << HEXWORD << addr << " (after adding disp32)" << end();
  }
  else {
    trace(Callstack_depth+1, "run") << "null address; skipping displacement" << end();
  }
  break;
}

:(code)
void test_add_r32_to_mem_at_rm32_plus_negative_disp32() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x2001;  // dest
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     98            ff ff ff ff             \n"  // add EBX to *(EAX-1)
      // ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 000 (dest EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00002001 (EAX)\n"
      "run: effective address is 0x00002000 (after adding disp32)\n"
      "run: storing 0x00000011\n"
  );
}

//:: copy address (lea)

:(before "End Initialize Op Names")
put_new(Name, "8d", "copy address in rm32 into r32 (lea)");

:(code)
void test_copy_address() {
  Reg[EAX].u = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  8d     18                                    \n"  // copy address in EAX into EBX
      // ModR/M in binary: 00 (indirect mode) 011 (dest EBX) 000 (src EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: copy address into EBX\n"
      "run: effective address is 0x00002000 (EAX)\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x8d: {  // copy address of m32 to r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy address into " << rname(arg1) << end();
  Reg[arg1].u = effective_address_number(modrm);
  break;
}

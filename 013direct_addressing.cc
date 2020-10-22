//: operating directly on a register

:(before "End Initialize Op Names")
put_new(Name, "01", "add r32 to rm32 (add)");

:(code)
void test_add_r32_to_r32() {
  Reg[EAX].i = 0x10;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  01     d8                                    \n" // add EBX to EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x01: {  // add r32 to r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "add " << rname(arg2) << " to r/m32" << end();
  int32_t* signed_arg1 = effective_address(modrm);
  int32_t signed_result = *signed_arg1 + Reg[arg2].i;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(*signed_arg1) + Reg[arg2].i;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg1 = static_cast<uint32_t>(*signed_arg1);
  uint32_t unsigned_result = unsigned_arg1 + Reg[arg2].u;
  uint64_t unsigned_full_result = static_cast<uint64_t>(unsigned_arg1) + Reg[arg2].u;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  *signed_arg1 = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  break;
}

:(code)
void test_add_r32_to_r32_signed_overflow() {
  Reg[EAX].i = INT32_MAX;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  01     d8                                    \n" // add EBX to EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: r/m32 is EAX\n"
      "run: SF=1; ZF=0; CF=0; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

void test_add_r32_to_r32_unsigned_overflow() {
  Reg[EAX].u = UINT32_MAX;
  Reg[EBX].u = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  01     d8                                    \n" // add EBX to EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: r/m32 is EAX\n"
      "run: SF=0; ZF=1; CF=1; OF=0\n"
      "run: storing 0x00000000\n"
  );
}

void test_add_r32_to_r32_unsigned_and_signed_overflow() {
  Reg[EAX].i = Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  01     d8                                    \n" // add EBX to EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: r/m32 is EAX\n"
      "run: SF=0; ZF=1; CF=1; OF=1\n"
      "run: storing 0x00000000\n"
  );
}

:(code)
// Implement tables 2-2 and 2-3 in the Intel manual, Volume 2.
// We return a pointer so that instructions can write to multiple bytes in
// 'Mem' at once.
// beware: will eventually have side-effects
int32_t* effective_address(uint8_t modrm) {
  const uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  const uint8_t rm = modrm & 0x7;
  if (mod == 3) {
    // mod 3 is just register direct addressing
    trace(Callstack_depth+1, "run") << "r/m32 is " << rname(rm) << end();
    return &Reg[rm].i;
  }
  uint32_t addr = effective_address_number(modrm);
  trace(Callstack_depth+1, "run") << "effective address contains 0x" << HEXWORD << read_mem_i32(addr) << end();
  return mem_addr_i32(addr);
}

// beware: will eventually have side-effects
uint32_t effective_address_number(uint8_t modrm) {
  const uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  const uint8_t rm = modrm & 0x7;
  uint32_t addr = 0;
  switch (mod) {
  case 3:
    // mod 3 is just register direct addressing
    raise << "unexpected direct addressing mode\n" << end();
    return 0;
  // End Mod Special-cases(addr)
  default:
    cerr << "unrecognized mod bits: " << NUM(mod) << '\n';
    exit(1);
  }
  //: other mods are indirect, and they'll set addr appropriately
  // Found effective_address(addr)
  return addr;
}

string rname(uint8_t r) {
  switch (r) {
  case 0: return "EAX";
  case 1: return "ECX";
  case 2: return "EDX";
  case 3: return "EBX";
  case 4: return "ESP";
  case 5: return "EBP";
  case 6: return "ESI";
  case 7: return "EDI";
  default: raise << "invalid register " << r << '\n' << end();  return "";
  }
}

//:: subtract

:(before "End Initialize Op Names")
put_new(Name, "29", "subtract r32 from rm32 (sub)");

:(code)
void test_subtract_r32_from_r32() {
  Reg[EAX].i = 10;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  29     d8                                    \n"  // subtract EBX from EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract EBX from r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0x00000009\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x29: {  // subtract r32 from r/m32
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "subtract " << rname(arg2) << " from r/m32" << end();
  int32_t* signed_arg1 = effective_address(modrm);
  int32_t signed_result = *signed_arg1 - Reg[arg2].i;
  SF = (signed_result < 0);
  ZF = (signed_result == 0);
  int64_t signed_full_result = static_cast<int64_t>(*signed_arg1) - Reg[arg2].i;
  OF = (signed_result != signed_full_result);
  // set CF
  uint32_t unsigned_arg1 = static_cast<uint32_t>(*signed_arg1);
  uint32_t unsigned_result = unsigned_arg1 - Reg[arg2].u;
  uint64_t unsigned_full_result = static_cast<uint64_t>(unsigned_arg1) - Reg[arg2].u;
  CF = (unsigned_result != unsigned_full_result);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  *signed_arg1 = signed_result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  break;
}

:(code)
void test_subtract_r32_from_r32_signed_overflow() {
  Reg[EAX].i = INT32_MIN;
  Reg[EBX].i = INT32_MAX;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  29     d8                                    \n"  // subtract EBX from EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract EBX from r/m32\n"
      "run: r/m32 is EAX\n"
      "run: SF=0; ZF=0; CF=0; OF=1\n"
      "run: storing 0x00000001\n"
  );
}

void test_subtract_r32_from_r32_unsigned_overflow() {
  Reg[EAX].i = 0;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  29     d8                                    \n"  // subtract EBX from EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract EBX from r/m32\n"
      "run: r/m32 is EAX\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
      "run: storing 0xffffffff\n"
  );
}

void test_subtract_r32_from_r32_signed_and_unsigned_overflow() {
  Reg[EAX].i = 0;
  Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  29     d8                                    \n"  // subtract EBX from EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract EBX from r/m32\n"
      "run: r/m32 is EAX\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
      "run: storing 0x80000000\n"
  );
}

//:: multiply

:(before "End Initialize Op Names")
put_new(Name, "f7", "negate/multiply/divide rm32 (with EAX and EDX if necessary) depending on subop (neg/mul/idiv)");

:(code)
void test_multiply_EAX_by_r32() {
  Reg[EAX].i = 4;
  Reg[ECX].i = 3;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     e1                                    \n"  // multiply EAX by ECX
      // ModR/M in binary: 11 (direct mode) 100 (subop mul) 001 (src ECX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is ECX\n"
      "run: subop: multiply EAX by r/m32\n"
      "run: storing 0x0000000c\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xf7: {
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "operate on r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
  case 4: {  // mul unsigned EAX by r/m32
    trace(Callstack_depth+1, "run") << "subop: multiply EAX by r/m32" << end();
    const uint64_t result = static_cast<uint64_t>(Reg[EAX].u) * static_cast<uint32_t>(*arg1);
    Reg[EAX].u = result & 0xffffffff;
    Reg[EDX].u = result >> 32;
    OF = (Reg[EDX].u != 0);
    CF = OF;
    trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
    trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[EAX].u << end();
    break;
  }
  // End Op f7 Subops
  default:
    cerr << "unrecognized subop for opcode f7: " << NUM(subop) << '\n';
    exit(1);
  }
  break;
}

//:

:(before "End Initialize Op Names")
put_new(Name_0f, "af", "multiply rm32 into r32 (imul)");

:(code)
void test_multiply_r32_into_r32() {
  Reg[EAX].i = 4;
  Reg[EBX].i = 2;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  0f af  d8                                    \n"  // subtract EBX into EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: multiply EBX by r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0x00000008\n"
  );
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0xaf: {  // multiply r32 by r/m32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "multiply " << rname(arg1) << " by r/m32" << end();
  const int32_t* arg2 = effective_address(modrm);
  int32_t result = Reg[arg1].i * (*arg2);
  int64_t full_result = static_cast<int64_t>(Reg[arg1].i) * (*arg2);
  OF = (result != full_result);
  CF = OF;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  Reg[arg1].i = result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[arg1].i << end();
  break;
}

//:: negate

:(code)
void test_negate_r32() {
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     db                                    \n"  // negate EBX
      // ModR/M in binary: 11 (direct mode) 011 (subop negate) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: negate\n"
      "run: storing 0xffffffff\n"
  );
}

:(before "End Op f7 Subops")
case 3: {  // negate r/m32
  trace(Callstack_depth+1, "run") << "subop: negate" << end();
  // one case that can overflow
  if (static_cast<uint32_t>(*arg1) == 0x80000000) {
    trace(Callstack_depth+1, "run") << "overflow" << end();
    SF = true;
    ZF = false;
    OF = true;
    break;
  }
  int32_t result = -(*arg1);
  SF = (result >> 31);
  ZF = (result == 0);
  OF = false;
  CF = (*arg1 != 0);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  *arg1 = result;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

:(code)
// negate can overflow in exactly one situation
void test_negate_can_overflow() {
  Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     db                                    \n"  // negate EBX
      // ModR/M in binary: 11 (direct mode) 011 (subop negate) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: negate\n"
      "run: overflow\n"
  );
}

//:: divide with remainder

void test_divide_EAX_by_rm32() {
  Reg[EAX].u = 7;
  Reg[EDX].u = 0;
  Reg[ECX].i = 3;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     f9                                    \n"  // multiply EAX by ECX
      // ModR/M in binary: 11 (direct mode) 111 (subop idiv) 001 (divisor ECX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is ECX\n"
      "run: subop: divide EDX:EAX by r/m32, storing quotient in EAX and remainder in EDX\n"
      "run: quotient: 0x00000002\n"
      "run: remainder: 0x00000001\n"
  );
}

:(before "End Op f7 Subops")
case 7: {  // divide EDX:EAX by r/m32, storing quotient in EAX and remainder in EDX
  trace(Callstack_depth+1, "run") << "subop: divide EDX:EAX by r/m32, storing quotient in EAX and remainder in EDX" << end();
  int64_t dividend = static_cast<int64_t>((static_cast<uint64_t>(Reg[EDX].u) << 32) | Reg[EAX].u);
  int32_t divisor = *arg1;
  assert(divisor != 0);
  Reg[EAX].i = dividend/divisor;  // quotient
  Reg[EDX].i = dividend%divisor;  // remainder
  // flag state undefined
  trace(Callstack_depth+1, "run") << "quotient: 0x" << HEXWORD << Reg[EAX].i << end();
  trace(Callstack_depth+1, "run") << "remainder: 0x" << HEXWORD << Reg[EDX].i << end();
  break;
}

:(code)
void test_divide_EAX_by_negative_rm32() {
  Reg[EAX].u = 7;
  Reg[EDX].u = 0;
  Reg[ECX].i = -3;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     f9                                    \n"  // multiply EAX by ECX
      // ModR/M in binary: 11 (direct mode) 111 (subop idiv) 001 (divisor ECX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is ECX\n"
      "run: subop: divide EDX:EAX by r/m32, storing quotient in EAX and remainder in EDX\n"
      "run: quotient: 0xfffffffe\n"  // -2
      "run: remainder: 0x00000001\n"
  );
}

void test_divide_negative_EAX_by_rm32() {
  Reg[EAX].i = -7;
  Reg[EDX].i = -1;  // sign extend
  Reg[ECX].i = 3;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     f9                                    \n"  // multiply EAX by ECX
      // ModR/M in binary: 11 (direct mode) 111 (subop idiv) 001 (divisor ECX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is ECX\n"
      "run: subop: divide EDX:EAX by r/m32, storing quotient in EAX and remainder in EDX\n"
      "run: quotient: 0xfffffffe\n"  // -2
      "run: remainder: 0xffffffff\n"  // -1, same sign as divident (EDX:EAX)
  );
}

void test_divide_negative_EDX_EAX_by_rm32() {
  Reg[EAX].i = 0;  // lower 32 bits are clear
  Reg[EDX].i = -7;
  Reg[ECX].i = 0x40000000;  // 2^30 (largest positive power of 2)
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     f9                                    \n"  // multiply EAX by ECX
      // ModR/M in binary: 11 (direct mode) 111 (subop idiv) 001 (divisor ECX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is ECX\n"
      "run: subop: divide EDX:EAX by r/m32, storing quotient in EAX and remainder in EDX\n"
      "run: quotient: 0xffffffe4\n"  // (-7 << 32) / (1 << 30) = -7 << 2 = -28
      "run: remainder: 0x00000000\n"
  );
}

//:: shift left

:(before "End Initialize Op Names")
put_new(Name, "d3", "shift rm32 by CL bits depending on subop (sal/sar/shl/shr)");

:(code)
void test_shift_left_r32_with_cl() {
  Reg[EBX].i = 13;
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     e3                                    \n"  // shift EBX left by CL bits
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
case 0xd3: {
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "operate on r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
  case 4: {  // shift left r/m32 by CL
    trace(Callstack_depth+1, "run") << "subop: shift left by CL bits" << end();
    uint8_t count = Reg[ECX].u & 0x1f;
    // OF is only defined if count is 1
    if (count == 1) {
      bool msb = (*arg1 & 0x80000000) >> 1;
      bool pnsb = (*arg1 & 0x40000000);
      OF = (msb != pnsb);
    }
    int32_t result = (*arg1 << count);
    ZF = (result == 0);
    SF = (result < 0);
    CF = (*arg1 << (count-1)) & 0x80000000;
    trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
    *arg1 = result;
    trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
    break;
  }
  // End Op d3 Subops
  default:
    cerr << "unrecognized subop for opcode d3: " << NUM(subop) << '\n';
    exit(1);
  }
  break;
}

//:: shift right arithmetic

:(code)
void test_shift_right_arithmetic_r32_with_cl() {
  Reg[EBX].i = 26;
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     fb                                    \n"  // shift EBX right by CL bits, while preserving sign
      // ModR/M in binary: 11 (direct mode) 111 (subop shift right arithmetic) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while preserving sign\n"
      "run: storing 0x0000000d\n"
  );
}

:(before "End Op d3 Subops")
case 7: {  // shift right r/m32 by CL, preserving sign
  trace(Callstack_depth+1, "run") << "subop: shift right by CL bits, while preserving sign" << end();
  uint8_t count = Reg[ECX].u & 0x1f;
  *arg1 = (*arg1 >> count);
  ZF = (*arg1 == 0);
  SF = (*arg1 < 0);
  // OF is only defined if count is 1
  if (count == 1) OF = false;
  // CF undefined
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

:(code)
void test_shift_right_arithmetic_odd_r32_with_cl() {
  Reg[EBX].i = 27;
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     fb                                    \n"  // shift EBX right by CL bits, while preserving sign
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

void test_shift_right_arithmetic_negative_r32_with_cl() {
  Reg[EBX].i = 0xfffffffd;  // -3
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     fb                                    \n"  // shift EBX right by CL bits, while preserving sign
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
void test_shift_right_logical_r32_with_cl() {
  Reg[EBX].i = 26;
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     eb                                    \n"  // shift EBX right by CL bits, while padding zeroes
      // ModR/M in binary: 11 (direct mode) 101 (subop shift right logical) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while padding zeroes\n"
      // result: 13
      "run: storing 0x0000000d\n"
  );
}

:(before "End Op d3 Subops")
case 5: {  // shift right r/m32 by CL, padding zeroes
  trace(Callstack_depth+1, "run") << "subop: shift right by CL bits, while padding zeroes" << end();
  uint8_t count = Reg[ECX].u & 0x1f;
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
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  break;
}

:(code)
void test_shift_right_logical_odd_r32_with_cl() {
  Reg[EBX].i = 27;
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     eb                                    \n"  // shift EBX right by CL bits, while padding zeroes
      // ModR/M in binary: 11 (direct mode) 101 (subop shift right logical) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: shift right by CL bits, while padding zeroes\n"
      // result: 13
      "run: storing 0x0000000d\n"
  );
}

void test_shift_right_logical_negative_r32_with_cl() {
  Reg[EBX].i = 0xfffffffd;
  Reg[ECX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  d3     eb                                    \n"  // shift EBX right by CL bits, while padding zeroes
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
put_new(Name, "21", "rm32 = bitwise AND of r32 with rm32 (and)");

:(code)
void test_and_r32_with_r32() {
  Reg[EAX].i = 0x0a0b0c0d;
  Reg[EBX].i = 0x000000ff;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  21     d8                                    \n"  // and EBX with destination EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: and EBX with r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0x0000000d\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x21: {  // and r32 with r/m32
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "and " << rname(arg2) << " with r/m32" << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  int32_t* signed_arg1 = effective_address(modrm);
  *signed_arg1 &= Reg[arg2].i;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  SF = (*signed_arg1 >> 31);
  ZF = (*signed_arg1 == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:: or

:(before "End Initialize Op Names")
put_new(Name, "09", "rm32 = bitwise OR of r32 with rm32 (or)");

:(code)
void test_or_r32_with_r32() {
  Reg[EAX].i = 0x0a0b0c0d;
  Reg[EBX].i = 0xa0b0c0d0;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  09     d8                                    \n"  // or EBX with destination EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: or EBX with r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0xaabbccdd\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x09: {  // or r32 with r/m32
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "or " << rname(arg2) << " with r/m32" << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  int32_t* signed_arg1 = effective_address(modrm);
  *signed_arg1 |= Reg[arg2].i;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  SF = (*signed_arg1 >> 31);
  ZF = (*signed_arg1 == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:: xor

:(before "End Initialize Op Names")
put_new(Name, "31", "rm32 = bitwise XOR of r32 with rm32 (xor)");

:(code)
void test_xor_r32_with_r32() {
  Reg[EAX].i = 0x0a0b0c0d;
  Reg[EBX].i = 0xaabbc0d0;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  31     d8                                    \n"  // xor EBX with destination EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: xor EBX with r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0xa0b0ccdd\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x31: {  // xor r32 with r/m32
  const uint8_t modrm = next();
  const uint8_t arg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "xor " << rname(arg2) << " with r/m32" << end();
  // bitwise ops technically operate on unsigned numbers, but it makes no
  // difference
  int32_t* signed_arg1 = effective_address(modrm);
  *signed_arg1 ^= Reg[arg2].i;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *signed_arg1 << end();
  SF = (*signed_arg1 >> 31);
  ZF = (*signed_arg1 == 0);
  CF = false;
  OF = false;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

//:: not

:(code)
void test_not_r32() {
  Reg[EBX].i = 0x0f0f00ff;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  f7     d3                                    \n"  // not EBX
      // ModR/M in binary: 11 (direct mode) 010 (subop not) 011 (dest EBX)
  );
  CHECK_TRACE_CONTENTS(
      "run: operate on r/m32\n"
      "run: r/m32 is EBX\n"
      "run: subop: not\n"
      "run: storing 0xf0f0ff00\n"
  );
}

:(before "End Op f7 Subops")
case 2: {  // not r/m32
  trace(Callstack_depth+1, "run") << "subop: not" << end();
  *arg1 = ~(*arg1);
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << end();
  // no flags affected
  break;
}

//:: compare (cmp)

:(before "End Initialize Op Names")
put_new(Name, "39", "compare: set SF if rm32 < r32 (cmp)");

:(code)
void test_compare_r32_with_r32_greater() {
  Reg[EAX].i = 0x0a0b0c0d;
  Reg[EBX].i = 0x0a0b0c07;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  39     d8                                    \n"  // compare EAX with EBX
      // ModR/M in binary: 11 (direct mode) 011 (rhs EBX) 000 (lhs EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: r/m32 is EAX\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x39: {  // set SF if r/m32 < r32
  const uint8_t modrm = next();
  const uint8_t reg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "compare r/m32 with " << rname(reg2) << end();
  const int32_t* signed_arg1 = effective_address(modrm);
  const int32_t signed_difference = *signed_arg1 - Reg[reg2].i;
  SF = (signed_difference < 0);
  ZF = (signed_difference == 0);
  const int64_t signed_full_difference = static_cast<int64_t>(*signed_arg1) - Reg[reg2].i;
  OF = (signed_difference != signed_full_difference);
  // set CF
  const uint32_t unsigned_arg1 = static_cast<uint32_t>(*signed_arg1);
  const uint32_t unsigned_difference = unsigned_arg1 - Reg[reg2].u;
  const uint64_t unsigned_full_difference = static_cast<uint64_t>(unsigned_arg1) - Reg[reg2].u;
  CF = (unsigned_difference != unsigned_full_difference);
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

:(code)
void test_compare_r32_with_r32_lesser_unsigned_and_signed() {
  Reg[EAX].i = 0x0a0b0c07;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  39     d8                                    \n"  // compare EAX with EBX
      // ModR/M in binary: 11 (direct mode) 011 (rhs EBX) 000 (lhs EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: r/m32 is EAX\n"
      "run: SF=1; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_r32_with_r32_lesser_unsigned_and_signed_due_to_overflow() {
  Reg[EAX].i = INT32_MAX;
  Reg[EBX].i = INT32_MIN;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  39     d8                                    \n"  // compare EAX with EBX
      // ModR/M in binary: 11 (direct mode) 011 (rhs EBX) 000 (lhs EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: r/m32 is EAX\n"
      "run: SF=1; ZF=0; CF=1; OF=1\n"
  );
}

void test_compare_r32_with_r32_lesser_signed() {
  Reg[EAX].i = -1;
  Reg[EBX].i = 1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  39     d8                                    \n"  // compare EAX with EBX
      // ModR/M in binary: 11 (direct mode) 011 (rhs EBX) 000 (lhs EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: r/m32 is EAX\n"
      "run: SF=1; ZF=0; CF=0; OF=0\n"
  );
}

void test_compare_r32_with_r32_lesser_unsigned() {
  Reg[EAX].i = 1;
  Reg[EBX].i = -1;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  39     d8                                    \n"  // compare EAX with EBX
      // ModR/M in binary: 11 (direct mode) 011 (rhs EBX) 000 (lhs EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: r/m32 is EAX\n"
      "run: SF=0; ZF=0; CF=1; OF=0\n"
  );
}

void test_compare_r32_with_r32_equal() {
  Reg[EAX].i = 0x0a0b0c0d;
  Reg[EBX].i = 0x0a0b0c0d;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  39     d8                                    \n"  // compare EAX and EBX
      // ModR/M in binary: 11 (direct mode) 011 (rhs EBX) 000 (lhs EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: compare r/m32 with EBX\n"
      "run: r/m32 is EAX\n"
      "run: SF=0; ZF=1; CF=0; OF=0\n"
  );
}

//:: copy (mov)

:(before "End Initialize Op Names")
put_new(Name, "89", "copy r32 to rm32 (mov)");

:(code)
void test_copy_r32_to_r32() {
  Reg[EBX].i = 0xaf;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  89     d8                                    \n"  // copy EBX to EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: copy EBX to r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0x000000af\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x89: {  // copy r32 to r/m32
  const uint8_t modrm = next();
  const uint8_t rsrc = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy " << rname(rsrc) << " to r/m32" << end();
  int32_t* dest = effective_address(modrm);
  *dest = Reg[rsrc].i;  // Write multiple elements of vector<uint8_t> at once. Assumes sizeof(int) == 4 on the host as well.
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *dest << end();
  break;
}

//:: xchg

:(before "End Initialize Op Names")
put_new(Name, "87", "swap the contents of r32 and rm32 (xchg)");

:(code)
void test_xchg_r32_with_r32() {
  Reg[EBX].i = 0xaf;
  Reg[EAX].i = 0x2e;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  87     d8                                    \n"  // exchange EBX with EAX
      // ModR/M in binary: 11 (direct mode) 011 (src EBX) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: exchange EBX with r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing 0x000000af in r/m32\n"
      "run: storing 0x0000002e in EBX\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x87: {  // exchange r32 with r/m32
  const uint8_t modrm = next();
  const uint8_t reg2 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "exchange " << rname(reg2) << " with r/m32" << end();
  int32_t* arg1 = effective_address(modrm);
  const int32_t tmp = *arg1;
  *arg1 = Reg[reg2].i;
  Reg[reg2].i = tmp;
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << *arg1 << " in r/m32" << end();
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXWORD << Reg[reg2].i << " in " << rname(reg2) << end();
  break;
}

//:: increment

:(before "End Initialize Op Names")
put_new(Name, "40", "increment EAX (inc)");
put_new(Name, "41", "increment ECX (inc)");
put_new(Name, "42", "increment EDX (inc)");
put_new(Name, "43", "increment EBX (inc)");
put_new(Name, "44", "increment ESP (inc)");
put_new(Name, "45", "increment EBP (inc)");
put_new(Name, "46", "increment ESI (inc)");
put_new(Name, "47", "increment EDI (inc)");

:(code)
void test_increment_r32() {
  Reg[ECX].u = 0x1f;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  41                                           \n"  // increment ECX
  );
  CHECK_TRACE_CONTENTS(
      "run: increment ECX\n"
      "run: storing value 0x00000020\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x40:
case 0x41:
case 0x42:
case 0x43:
case 0x44:
case 0x45:
case 0x46:
case 0x47: {  // increment r32
  const uint8_t reg = op & 0x7;
  trace(Callstack_depth+1, "run") << "increment " << rname(reg) << end();
  ++Reg[reg].u;
  trace(Callstack_depth+1, "run") << "storing value 0x" << HEXWORD << Reg[reg].u << end();
  break;
}

:(before "End Initialize Op Names")
put_new(Name, "ff", "increment/decrement/jump/push/call rm32 based on subop (inc/dec/jmp/push/call)");

:(code)
void test_increment_rm32() {
  Reg[EAX].u = 0x20;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  ff     c0                                    \n"  // increment EAX
      // ModR/M in binary: 11 (direct mode) 000 (subop inc) 000 (EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: increment r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing value 0x00000021\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0xff: {
  const uint8_t modrm = next();
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  switch (subop) {
    case 0: {  // increment r/m32
      trace(Callstack_depth+1, "run") << "increment r/m32" << end();
      int32_t* arg = effective_address(modrm);
      ++*arg;
      trace(Callstack_depth+1, "run") << "storing value 0x" << HEXWORD << *arg << end();
      break;
    }
    default:
      cerr << "unrecognized subop for ff: " << HEXBYTE << NUM(subop) << '\n';
      exit(1);
    // End Op ff Subops
  }
  break;
}

//:: decrement

:(before "End Initialize Op Names")
put_new(Name, "48", "decrement EAX (dec)");
put_new(Name, "49", "decrement ECX (dec)");
put_new(Name, "4a", "decrement EDX (dec)");
put_new(Name, "4b", "decrement EBX (dec)");
put_new(Name, "4c", "decrement ESP (dec)");
put_new(Name, "4d", "decrement EBP (dec)");
put_new(Name, "4e", "decrement ESI (dec)");
put_new(Name, "4f", "decrement EDI (dec)");

:(code)
void test_decrement_r32() {
  Reg[ECX].u = 0x1f;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  49                                           \n"  // decrement ECX
  );
  CHECK_TRACE_CONTENTS(
      "run: decrement ECX\n"
      "run: storing value 0x0000001e\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x48:
case 0x49:
case 0x4a:
case 0x4b:
case 0x4c:
case 0x4d:
case 0x4e:
case 0x4f: {  // decrement r32
  const uint8_t reg = op & 0x7;
  trace(Callstack_depth+1, "run") << "decrement " << rname(reg) << end();
  --Reg[reg].u;
  trace(Callstack_depth+1, "run") << "storing value 0x" << HEXWORD << Reg[reg].u << end();
  break;
}

:(code)
void test_decrement_rm32() {
  Reg[EAX].u = 0x20;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  ff     c8                                    \n"  // decrement EAX
      // ModR/M in binary: 11 (direct mode) 001 (subop inc) 000 (EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: decrement r/m32\n"
      "run: r/m32 is EAX\n"
      "run: storing value 0x0000001f\n"
  );
}

:(before "End Op ff Subops")
case 1: {  // decrement r/m32
  trace(Callstack_depth+1, "run") << "decrement r/m32" << end();
  int32_t* arg = effective_address(modrm);
  --*arg;
  trace(Callstack_depth+1, "run") << "storing value 0x" << HEXWORD << *arg << end();
  break;
}

//:: push

:(before "End Initialize Op Names")
put_new(Name, "50", "push EAX to stack (push)");
put_new(Name, "51", "push ECX to stack (push)");
put_new(Name, "52", "push EDX to stack (push)");
put_new(Name, "53", "push EBX to stack (push)");
put_new(Name, "54", "push ESP to stack (push)");
put_new(Name, "55", "push EBP to stack (push)");
put_new(Name, "56", "push ESI to stack (push)");
put_new(Name, "57", "push EDI to stack (push)");

:(code)
void test_push_r32() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000008;
  Reg[EBX].i = 0x0000000a;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  53                                           \n"  // push EBX to stack
  );
  CHECK_TRACE_CONTENTS(
      "run: push EBX\n"
      "run: decrementing ESP to 0xbd000004\n"
      "run: pushing value 0x0000000a\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x50:
case 0x51:
case 0x52:
case 0x53:
case 0x54:
case 0x55:
case 0x56:
case 0x57: {  // push r32 to stack
  uint8_t reg = op & 0x7;
  trace(Callstack_depth+1, "run") << "push " << rname(reg) << end();
//?   cerr << "push: " << NUM(reg) << ": " << Reg[reg].u << " => " << Reg[ESP].u << '\n';
  push(Reg[reg].u);
  break;
}

//:: pop

:(before "End Initialize Op Names")
put_new(Name, "58", "pop top of stack to EAX (pop)");
put_new(Name, "59", "pop top of stack to ECX (pop)");
put_new(Name, "5a", "pop top of stack to EDX (pop)");
put_new(Name, "5b", "pop top of stack to EBX (pop)");
put_new(Name, "5c", "pop top of stack to ESP (pop)");
put_new(Name, "5d", "pop top of stack to EBP (pop)");
put_new(Name, "5e", "pop top of stack to ESI (pop)");
put_new(Name, "5f", "pop top of stack to EDI (pop)");

:(code)
void test_pop_r32() {
  Mem.push_back(vma(0xbd000000));  // manually allocate memory
  Reg[ESP].u = 0xbd000008;
  write_mem_i32(0xbd000008, 0x0000000a);  // ..before this write
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "  5b                                           \n"  // pop stack to EBX
      "== data 0x2000\n"  // data segment
      "0a 00 00 00\n"  // 0xa
  );
  CHECK_TRACE_CONTENTS(
      "run: pop into EBX\n"
      "run: popping value 0x0000000a\n"
      "run: incrementing ESP to 0xbd00000c\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x58:
case 0x59:
case 0x5a:
case 0x5b:
case 0x5c:
case 0x5d:
case 0x5e:
case 0x5f: {  // pop stack into r32
  const uint8_t reg = op & 0x7;
  trace(Callstack_depth+1, "run") << "pop into " << rname(reg) << end();
//?   cerr << "pop from " << Reg[ESP].u << '\n';
  Reg[reg].u = pop();
//?   cerr << "=> " << NUM(reg) << ": " << Reg[reg].u << '\n';
  break;
}
:(code)
uint32_t pop() {
  const uint32_t result = read_mem_u32(Reg[ESP].u);
  trace(Callstack_depth+1, "run") << "popping value 0x" << HEXWORD << result << end();
  Reg[ESP].u += 4;
  trace(Callstack_depth+1, "run") << "incrementing ESP to 0x" << HEXWORD << Reg[ESP].u << end();
  assert(Reg[ESP].u < AFTER_STACK);
  return result;
}

:(before "End Includes")
#include <climits>

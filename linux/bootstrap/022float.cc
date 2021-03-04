//: floating-point operations

//:: copy

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "10", "copy xm32 to x32 (movss)");
put_new(Name_f3_0f, "11", "copy x32 to xm32 (movss)");

:(code)
void test_copy_x32_to_x32() {
  Xmm[3] = 0.5;
  run(
      "== code 0x1\n"  // code segment
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 11 d8                                    \n"  // copy XMM3 to XMM0
      // ModR/M in binary: 11 (direct mode) 011 (src XMM3) 000 (dest XMM0)
  );
  CHECK_TRACE_CONTENTS(
      "run: copy XMM3 to x/m32\n"
      "run: x/m32 is XMM0\n"
      "run: storing 0.5\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x10: {  // copy x/m32 to x32
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy x/m32 to " << Xname[rdest] << end();
  float* src = effective_address_float(modrm);
  Xmm[rdest] = *src;  // Write multiple elements of vector<uint8_t> at once. Assumes sizeof(float) == 4 on the host as well.
  trace(Callstack_depth+1, "run") << "storing " << Xmm[rdest] << end();
  break;
}
case 0x11: {  // copy x32 to x/m32
  const uint8_t modrm = next();
  const uint8_t rsrc = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy " << Xname[rsrc] << " to x/m32" << end();
  float* dest = effective_address_float(modrm);
  *dest = Xmm[rsrc];  // Write multiple elements of vector<uint8_t> at once. Assumes sizeof(float) == 4 on the host as well.
  trace(Callstack_depth+1, "run") << "storing " << *dest << end();
  break;
}

:(code)
void test_copy_x32_to_mem_at_xm32() {
  Xmm[3] = 0.5;
  Reg[EAX].i = 0x60;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 11 18                                    \n"  // copy XMM3 to *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src XMM3) 000 (dest EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: copy XMM3 to x/m32\n"
      "run: effective address is 0x00000060 (EAX)\n"
      "run: storing 0.5\n"
  );
}

void test_copy_mem_at_xm32_to_x32() {
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 10 18                                    \n"  // copy *EAX to XMM3
      "== data 0x2000\n"
      "00 00 00 3f\n"  // 0x3f000000 = 0.5
  );
  CHECK_TRACE_CONTENTS(
      "run: copy x/m32 to XMM3\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0.5\n"
  );
}

//:: convert to floating point

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "2a", "convert integer to floating-point (cvtsi2ss)");

:(code)
void test_cvtsi2ss() {
  Reg[EAX].i = 10;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 2a c0                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 000 (EAX)
  );
  CHECK_TRACE_CONTENTS(
      "run: convert r/m32 to XMM0\n"
      "run: r/m32 is EAX\n"
      "run: XMM0 is now 10\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x2a: {  // convert integer to float
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "convert r/m32 to " << Xname[dest] << end();
  const int32_t* src = effective_address(modrm);
  Xmm[dest] = *src;
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: convert floating point to int

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "2d", "convert floating-point to int (cvtss2si)");
put_new(Name_f3_0f, "2c", "truncate floating-point to int (cvttss2si)");

:(code)
void test_cvtss2si() {
  Xmm[0] = 9.8;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 2d c0                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (EAX) 000 (XMM0)
  );
  CHECK_TRACE_CONTENTS(
      "run: convert x/m32 to EAX\n"
      "run: x/m32 is XMM0\n"
      "run: EAX is now 0x0000000a\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x2d: {  // convert float to integer
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "convert x/m32 to " << rname(dest) << end();
  const float* src = effective_address_float(modrm);
  Reg[dest].i = round(*src);
  trace(Callstack_depth+1, "run") << rname(dest) << " is now 0x" << HEXWORD << Reg[dest].i << end();
  break;
}

:(code)
void test_cvttss2si() {
  Xmm[0] = 9.8;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 2c c0                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (EAX) 000 (XMM0)
  );
  CHECK_TRACE_CONTENTS(
      "run: truncate x/m32 to EAX\n"
      "run: x/m32 is XMM0\n"
      "run: EAX is now 0x00000009\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x2c: {  // truncate float to integer
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "truncate x/m32 to " << rname(dest) << end();
  const float* src = effective_address_float(modrm);
  Reg[dest].i = trunc(*src);
  trace(Callstack_depth+1, "run") << rname(dest) << " is now 0x" << HEXWORD << Reg[dest].i << end();
  break;
}

//:: add

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "58", "add floats (addss)");

:(code)
void test_addss() {
  Xmm[0] = 3.0;
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 58 c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: add x/m32 to XMM0\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 5\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x58: {  // add x/m32 to x32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "add x/m32 to " << Xname[dest] << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] += *src;
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: subtract

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "5c", "subtract floats (subss)");

:(code)
void test_subss() {
  Xmm[0] = 3.0;
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 5c c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: subtract x/m32 from XMM0\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 1\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x5c: {  // subtract x/m32 from x32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "subtract x/m32 from " << Xname[dest] << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] -= *src;
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: multiply

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "59", "multiply floats (mulss)");

:(code)
void test_mulss() {
  Xmm[0] = 3.0;
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 59 c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: multiply XMM0 by x/m32\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 6\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x59: {  // multiply x32 by x/m32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "multiply " << Xname[dest] << " by x/m32" << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] *= *src;
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: divide

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "5e", "divide floats (divss)");

:(code)
void test_divss() {
  Xmm[0] = 3.0;
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 5e c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: divide XMM0 by x/m32\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 1.5\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x5e: {  // divide x32 by x/m32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "divide " << Xname[dest] << " by x/m32" << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] /= *src;
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: min

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "5d", "minimum of two floats (minss)");

:(code)
void test_minss() {
  Xmm[0] = 3.0;
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 5d c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: minimum of XMM0 and x/m32\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 2\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x5d: {  // minimum of x32, x/m32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "minimum of " << Xname[dest] << " and x/m32" << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] = min(Xmm[dest], *src);
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: max

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "5f", "maximum of two floats (maxss)");

:(code)
void test_maxss() {
  Xmm[0] = 3.0;
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 5f c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: maximum of XMM0 and x/m32\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 3\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x5f: {  // maximum of x32, x/m32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "maximum of " << Xname[dest] << " and x/m32" << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] = max(Xmm[dest], *src);
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: reciprocal

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "53", "reciprocal of float (rcpss)");

:(code)
void test_rcpss() {
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 53 c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: reciprocal of x/m32 into XMM0\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 0.5\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x53: {  // reciprocal of x/m32 into x32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "reciprocal of x/m32 into " << Xname[dest] << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] = 1.0 / *src;
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

//:: square root

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "51", "square root of float (sqrtss)");

:(code)
void test_sqrtss() {
  Xmm[1] = 2.0;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 51 c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: square root of x/m32 into XMM0\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 1.41421\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x51: {  // square root of x/m32 into x32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "square root of x/m32 into " << Xname[dest] << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] = sqrt(*src);
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

:(before "End Includes")
#include <math.h>

//:: inverse square root

:(before "End Initialize Op Names")
put_new(Name_f3_0f, "52", "inverse square root of float (rsqrtss)");

:(code)
void test_rsqrtss() {
  Xmm[1] = 0.01;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "f3 0f 52 c1                                    \n"
      // ModR/M in binary: 11 (direct mode) 000 (XMM0) 001 (XMM1)
  );
  CHECK_TRACE_CONTENTS(
      "run: inverse square root of x/m32 into XMM0\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 10\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x52: {  // inverse square root of x/m32 into x32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "inverse square root of x/m32 into " << Xname[dest] << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] = 1.0 / sqrt(*src);
  trace(Callstack_depth+1, "run") << Xname[dest] << " is now " << Xmm[dest] << end();
  break;
}

:(code)
float* effective_address_float(uint8_t modrm) {
  const uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  const uint8_t rm = modrm & 0x7;
  if (mod == 3) {
    // mod 3 is just register direct addressing
    trace(Callstack_depth+1, "run") << "x/m32 is " << Xname[rm] << end();
    return &Xmm[rm];
  }
  uint32_t addr = effective_address_number(modrm);
  trace(Callstack_depth+1, "run") << "effective address contains " << read_mem_f32(addr) << end();
  return mem_addr_f32(addr);
}

//: compare

:(before "End Initialize Op Names")
put_new(Name_0f, "2f", "compare: set CF if x32 < xm32 (comiss)");

:(code)
void test_compare_x32_with_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  Xmm[3] = 0.5;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  0f 2f  18                                    \n"  // compare XMM3 with *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (lhs XMM3) 000 (rhs EAX)
      "== data 0x2000\n"
      "00 00 00 00\n"  // 0x00000000 = 0.0
  );
  CHECK_TRACE_CONTENTS(
      "run: compare XMM3 with x/m32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: SF=0; ZF=0; CF=0; OF=0\n"
  );
}

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x2f: {  // set CF if x32 < x/m32
  const uint8_t modrm = next();
  const uint8_t reg1 = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "compare " << Xname[reg1] << " with x/m32" << end();
  const float* arg2 = effective_address_float(modrm);
  // Flag settings carefully copied from the Intel manual.
  // See also https://stackoverflow.com/questions/7057501/x86-assembler-floating-point-compare/7057771#7057771
  SF = ZF = CF = OF = false;
  if (Xmm[reg1] == *arg2) ZF = true;
  if (Xmm[reg1] < *arg2) CF = true;
  trace(Callstack_depth+1, "run") << "SF=" << SF << "; ZF=" << ZF << "; CF=" << CF << "; OF=" << OF << end();
  break;
}

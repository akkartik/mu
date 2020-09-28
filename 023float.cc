//: floating-point operations

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
      "run: divide x32 by x/m32\n"
      "run: x/m32 is XMM1\n"
      "run: XMM0 is now 1.5\n"
  );
}

:(before "End Three-Byte Opcodes Starting With f3 0f")
case 0x5e: {  // divide x32 by x/m32
  const uint8_t modrm = next();
  const uint8_t dest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "divide x32 by x/m32" << end();
  const float* src = effective_address_float(modrm);
  Xmm[dest] /= *src;
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

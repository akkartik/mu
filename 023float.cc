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

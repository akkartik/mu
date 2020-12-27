//: SubX mostly deals with instructions operating on 32-bit operands, but we
//: still need to deal with raw bytes for strings and so on.

//: Unfortunately the register encodings when dealing with bytes are a mess.
//: We need a special case for them.
:(code)
string rname_8bit(uint8_t r) {
  switch (r) {
  case 0: return "AL";  // lowest byte of EAX
  case 1: return "CL";  // lowest byte of ECX
  case 2: return "DL";  // lowest byte of EDX
  case 3: return "BL";  // lowest byte of EBX
  case 4: return "AH";  // second lowest byte of EAX
  case 5: return "CH";  // second lowest byte of ECX
  case 6: return "DH";  // second lowest byte of EDX
  case 7: return "BH";  // second lowest byte of EBX
  default: raise << "invalid 8-bit register " << r << '\n' << end();  return "";
  }
}

uint8_t* effective_byte_address(uint8_t modrm) {
  uint8_t mod = (modrm>>6);
  uint8_t rm = modrm & 0x7;
  if (mod == 3) {
    // select an 8-bit register
    trace(Callstack_depth+1, "run") << "r/m8 is " << rname_8bit(rm) << end();
    return reg_8bit(rm);
  }
  // the rest is as usual
  return mem_addr_u8(effective_address_number(modrm));
}

uint8_t* reg_8bit(uint8_t rm) {
  uint8_t* result = reinterpret_cast<uint8_t*>(&Reg[rm & 0x3].i);  // _L register
  if (rm & 0x4)
    ++result;  // _H register;  assumes host is little-endian
  return result;
}

:(before "End Initialize Op Names")
put_new(Name, "88", "copy r8 to r8/m8-at-r32");

:(code)
void test_copy_r8_to_mem_at_rm32() {
  Reg[EBX].i = 0x224488ab;
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  88     18                                      \n"  // copy BL to the byte at *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src BL) 000 (dest EAX)
      "== data 0x2000\n"
      "f0 cc bb aa\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: copy BL to r8/m8-at-r32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0xab\n"
  );
  CHECK_EQ(0xaabbccab, read_mem_u32(0x2000));
}

:(before "End Single-Byte Opcodes")
case 0x88: {  // copy r8 to r/m8
  const uint8_t modrm = next();
  const uint8_t rsrc = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy " << rname_8bit(rsrc) << " to r8/m8-at-r32" << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* dest = effective_byte_address(modrm);
  const uint8_t* src = reg_8bit(rsrc);
  *dest = *src;  // Read/write multiple elements of vector<uint8_t> at once. Assumes sizeof(int) == 4 on the host as well.
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXBYTE << NUM(*dest) << end();
  break;
}

//:

:(before "End Initialize Op Names")
put_new(Name, "8a", "copy r8/m8-at-r32 to r8");

:(code)
void test_copy_mem_at_rm32_to_r8() {
  Reg[EBX].i = 0xaabbcc0f;  // one nibble each of lowest byte set to all 0s and all 1s, to maximize value of this test
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  8a     18                                      \n"  // copy just the byte at *EAX to BL
      // ModR/M in binary: 00 (indirect mode) 011 (dest EBX) 000 (src EAX)
      "== data 0x2000\n"
      "ab ff ff ff\n"  // 0xab with more data in following bytes
  );
  CHECK_TRACE_CONTENTS(
      "run: copy r8/m8-at-r32 to BL\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0xab\n"
      // remaining bytes of EBX are *not* cleared
      "run: EBX now contains 0xaabbccab\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x8a: {  // copy r/m8 to r8
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  trace(Callstack_depth+1, "run") << "copy r8/m8-at-r32 to " << rname_8bit(rdest) << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  const uint8_t* src = effective_byte_address(modrm);
  uint8_t* dest = reg_8bit(rdest);
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXBYTE << NUM(*src) << end();
  *dest = *src;  // Read/write multiple elements of vector<uint8_t> at once. Assumes sizeof(int) == 4 on the host as well.
  const uint8_t rdest_32bit = rdest & 0x3;
  trace(Callstack_depth+1, "run") << rname(rdest_32bit) << " now contains 0x" << HEXWORD << Reg[rdest_32bit].u << end();
  break;
}

:(code)
void test_cannot_copy_byte_to_ESP_EBP_ESI_EDI() {
  Reg[ESI].u = 0xaabbccdd;
  Reg[EBX].u = 0x11223344;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  8a     f3                                      \n"  // copy just the byte at *EBX to 8-bit register '6'
      // ModR/M in binary: 11 (direct mode) 110 (dest 8-bit 'register 6') 011 (src EBX)
  );
  CHECK_TRACE_CONTENTS(
      // ensure 8-bit register '6' is DH, not ESI
      "run: copy r8/m8-at-r32 to DH\n"
      "run: storing 0x44\n"
  );
  // ensure ESI is unchanged
  CHECK_EQ(Reg[ESI].u, 0xaabbccdd);
}

//:

:(before "End Initialize Op Names")
put_new(Name, "c6", "copy imm8 to r8/m8-at-r32 with subop 0 (mov)");

:(code)
void test_copy_imm8_to_mem_at_rm32() {
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  c6     00                          dd          \n"  // copy to the byte at *EAX
      // ModR/M in binary: 00 (indirect mode) 000 (unused) 000 (dest EAX)
      "== data 0x2000\n"
      "f0 cc bb aa\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: copy imm8 to r8/m8-at-r32\n"
      "run: effective address is 0x00002000 (EAX)\n"
      "run: storing 0xdd\n"
  );
  CHECK_EQ(0xaabbccdd, read_mem_u32(0x2000));
}

:(before "End Single-Byte Opcodes")
case 0xc6: {  // copy imm8 to r/m8
  const uint8_t modrm = next();
  const uint8_t src = next();
  trace(Callstack_depth+1, "run") << "copy imm8 to r8/m8-at-r32" << end();
  trace(Callstack_depth+1, "run") << "imm8 is 0x" << HEXBYTE << NUM(src) << end();
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  if (subop != 0) {
    cerr << "unrecognized subop for opcode c6: " << NUM(subop) << " (only 0/copy currently implemented)\n";
    exit(1);
  }
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* dest = effective_byte_address(modrm);
  *dest = src;  // Write multiple elements of vector<uint8_t> at once. Assumes sizeof(int) == 4 on the host as well.
  trace(Callstack_depth+1, "run") << "storing 0x" << HEXBYTE << NUM(*dest) << end();
  break;
}

//:: set flags (setcc)

:(before "End Initialize Op Names")
put_new(Name_0f, "94", "set r8/m8-at-rm32 to 1 if equal, if ZF is set, 0 otherwise (setcc/setz/sete)");
put_new(Name_0f, "95", "set r8/m8-at-rm32 to 1 if not equal, if ZF is not set, 0 otherwise (setcc/setnz/setne)");
put_new(Name_0f, "9f", "set r8/m8-at-rm32 to 1 if greater, if ZF is unset and SF == OF, 0 otherwise (setcc/setg/setnle)");
put_new(Name_0f, "97", "set r8/m8-at-rm32 to 1 if greater (addr, float), if ZF is unset and CF is unset, 0 otherwise (setcc/seta/setnbe)");
put_new(Name_0f, "9d", "set r8/m8-at-rm32 to 1 if greater or equal, if SF == OF, 0 otherwise (setcc/setge/setnl)");
put_new(Name_0f, "93", "set r8/m8-at-rm32 to 1 if greater or equal (addr, float), if CF is unset, 0 otherwise (setcc/setae/setnb)");
put_new(Name_0f, "9c", "set r8/m8-at-rm32 to 1 if lesser, if SF != OF, 0 otherwise (setcc/setl/setnge)");
put_new(Name_0f, "92", "set r8/m8-at-rm32 to 1 if lesser (addr, float), if CF is set, 0 otherwise (setcc/setb/setnae)");
put_new(Name_0f, "9e", "set r8/m8-at-rm32 to 1 if lesser or equal, if ZF is set or SF != OF, 0 otherwise (setcc/setle/setng)");
put_new(Name_0f, "96", "set r8/m8-at-rm32 to 1 if lesser or equal (addr, float), if ZF is set or CF is set, 0 otherwise (setcc/setbe/setna)");

:(before "End Two-Byte Opcodes Starting With 0f")
case 0x94: {  // set r8/m8-at-rm32 if ZF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = ZF;
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x95: {  // set r8/m8-at-rm32 if !ZF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = !ZF;
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x9f: {  // set r8/m8-at-rm32 if !SF and !ZF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = !ZF && SF == OF;
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x97: {  // set r8/m8-at-rm32 if !CF and !ZF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = (!CF && !ZF);
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x9d: {  // set r8/m8-at-rm32 if !SF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = (SF == OF);
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x93: {  // set r8/m8-at-rm32 if !CF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = !CF;
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x9c: {  // set r8/m8-at-rm32 if SF and !ZF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = (SF != OF);
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x92: {  // set r8/m8-at-rm32 if CF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = CF;
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x9e: {  // set r8/m8-at-rm32 if SF or ZF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = (ZF || SF != OF);
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}
case 0x96: {  // set r8/m8-at-rm32 if ZF or CF
  const uint8_t modrm = next();
  trace(Callstack_depth+1, "run") << "set r8/m8-at-rm32" << end();
  uint8_t* dest = effective_byte_address(modrm);
  *dest = (ZF || CF);
  trace(Callstack_depth+1, "run") << "storing " << NUM(*dest) << end();
  break;
}

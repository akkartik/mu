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
    trace(90, "run") << "r/m8 is " << rname_8bit(rm) << end();
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

:(scenario copy_r8_to_mem_at_r32)
% Reg[EBX].i = 0x224488ab;
% Reg[EAX].i = 0x2000;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  88  18                                      # copy BL to the byte at *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src BL) 000 (dest EAX)
== 0x2000
f0 cc bb aa
+run: copy BL to r8/m8-at-r32
+run: effective address is 0x00002000 (EAX)
+run: storing 0xab
% CHECK_EQ(0xaabbccab, read_mem_u32(0x2000));

:(before "End Single-Byte Opcodes")
case 0x88: {  // copy r8 to r/m8
  const uint8_t modrm = next();
  const uint8_t rsrc = (modrm>>3)&0x7;
  trace(90, "run") << "copy " << rname_8bit(rsrc) << " to r8/m8-at-r32" << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* dest = reinterpret_cast<uint8_t*>(effective_byte_address(modrm));
  const uint8_t* src = reg_8bit(rsrc);
  *dest = *src;
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*dest) << end();
  break;
}

//:

:(before "End Initialize Op Names")
put_new(Name, "8a", "copy r8/m8-at-r32 to r8");

:(scenario copy_mem_at_r32_to_r8)
% Reg[EBX].i = 0xaabbcc0f;  // one nibble each of lowest byte set to all 0s and all 1s, to maximize value of this test
% Reg[EAX].i = 0x2000;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  8a  18                                      # copy just the byte at *EAX to BL
# ModR/M in binary: 00 (indirect mode) 011 (dest EBX) 000 (src EAX)
== 0x2000  # data segment
ab ff ff ff  # 0xab with more data in following bytes
+run: copy r8/m8-at-r32 to BL
+run: effective address is 0x00002000 (EAX)
+run: storing 0xab
# remaining bytes of EBX are *not* cleared
+run: EBX now contains 0xaabbccab

:(before "End Single-Byte Opcodes")
case 0x8a: {  // copy r/m8 to r8
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  trace(90, "run") << "copy r8/m8-at-r32 to " << rname_8bit(rdest) << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  const uint8_t* src = reinterpret_cast<uint8_t*>(effective_byte_address(modrm));
  uint8_t* dest = reg_8bit(rdest);
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*src) << end();
  *dest = *src;
  const uint8_t rdest_32bit = rdest & 0x3;
  trace(90, "run") << rname(rdest_32bit) << " now contains 0x" << HEXWORD << Reg[rdest_32bit].u << end();
  break;
}

:(scenario cannot_copy_byte_to_ESP_EBP_ESI_EDI)
% Reg[ESI].u = 0xaabbccdd;
% Reg[EBX].u = 0x11223344;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  8a  f3                                      # copy just the byte at *EBX to 8-bit register '6'
# ModR/M in binary: 11 (direct mode) 110 (dest 8-bit 'register 6') 011 (src EBX)
# ensure 8-bit register '6' is DH, not ESI
+run: copy r8/m8-at-r32 to DH
+run: storing 0x44
# ensure ESI is unchanged
% CHECK_EQ(Reg[ESI].u, 0xaabbccdd);

//:

:(before "End Initialize Op Names")
put_new(Name, "c6", "copy imm8 to r8/m8-at-r32 (mov)");

:(scenario copy_imm8_to_mem_at_r32)
% Reg[EAX].i = 0x2000;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  c6  00                          dd          # copy to the byte at *EAX
# ModR/M in binary: 00 (indirect mode) 000 (unused) 000 (dest EAX)
== 0x2000
f0 cc bb aa
+run: copy imm8 to r8/m8-at-r32
+run: effective address is 0x00002000 (EAX)
+run: storing 0xdd
% CHECK_EQ(0xaabbccdd, read_mem_u32(0x2000));

:(before "End Single-Byte Opcodes")
case 0xc6: {  // copy imm8 to r/m8
  const uint8_t modrm = next();
  const uint8_t src = next();
  trace(90, "run") << "copy imm8 to r8/m8-at-r32" << end();
  trace(90, "run") << "imm8 is 0x" << HEXWORD << src << end();
  const uint8_t subop = (modrm>>3)&0x7;  // middle 3 'reg opcode' bits
  if (subop != 0) {
    cerr << "unrecognized subop for opcode c6: " << NUM(subop) << " (only 0/copy currently implemented)\n";
    exit(1);
  }
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* dest = reinterpret_cast<uint8_t*>(effective_byte_address(modrm));
  *dest = src;
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*dest) << end();
  break;
}

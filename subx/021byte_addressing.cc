//:

:(before "End Initialize Op Names(name)")
put(name, "88", "copy r8 (lowermost byte of r32) to r8/m8-at-r32");

:(scenario copy_r8_to_mem_at_r32)
% Reg[EBX].i = 0x224488ab;
% Reg[EAX].i = 0x2000;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  88  18                                      # copy just the lowermost byte of EBX to the byte at *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
== 0x2000
f0 cc bb aa  # 0xf0 with more data in following bytes
+run: copy lowermost byte of EBX to r8/m8-at-r32
+run: effective address is 0x2000 (EAX)
+run: storing 0xab
% CHECK_EQ(0xaabbccab, read_mem_u32(0x2000));

:(before "End Single-Byte Opcodes")
case 0x88: {  // copy r8 to r/m8
  const uint8_t modrm = next();
  const uint8_t rsrc = (modrm>>3)&0x7;
  trace(90, "run") << "copy lowermost byte of " << rname(rsrc) << " to r8/m8-at-r32" << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  uint8_t* dest = reinterpret_cast<uint8_t*>(effective_address(modrm));
  *dest = Reg[rsrc].u;
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*dest) << end();
  break;
}

//:

:(before "End Initialize Op Names(name)")
put(name, "8a", "copy r8/m8-at-r32 to r8 (lowermost byte of r32)");

:(scenario copy_mem_at_r32_to_r8)
% Reg[EBX].i = 0xaabbcc0f;  // one nibble each of lowest byte set to all 0s and all 1s, to maximize value of this test
% Reg[EAX].i = 0x2000;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  8a  18                                      # copy just the byte at *EAX to lowermost byte of EBX (clearing remaining bytes)
# ModR/M in binary: 00 (indirect mode) 011 (dest EBX) 000 (src EAX)
== 0x2000  # data segment
ab ff ff ff  # 0xab with more data in following bytes
+run: copy r8/m8-at-r32 to lowermost byte of EBX
+run: effective address is 0x2000 (EAX)
+run: storing 0xab
# remaining bytes of EBX are *not* cleared
+run: EBX now contains 0xaabbccab

:(before "End Single-Byte Opcodes")
case 0x8a: {  // copy r/m8 to r8
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  trace(90, "run") << "copy r8/m8-at-r32 to lowermost byte of " << rname(rdest) << end();
  // use unsigned to zero-extend 8-bit value to 32 bits
  const uint8_t* src = reinterpret_cast<uint8_t*>(effective_address(modrm));
  trace(90, "run") << "storing 0x" << HEXBYTE << NUM(*src) << end();
  *reinterpret_cast<uint8_t*>(&Reg[rdest].u) = *src;  // assumes host is little-endian
  trace(90, "run") << rname(rdest) << " now contains 0x" << HEXWORD << Reg[rdest].u << end();
  break;
}

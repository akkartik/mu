:(scenario add_r32_to_rm32)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
# word in addresses 0x60-0x63 has value 1
% Mem[0x60] = 1;
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX (reg 3) to *EAX (reg 0)
+run: add reg 3 to effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x11

:(before "End Single-Byte Opcodes")
case 0x01: {  // add r32 to r/m32
  uint8_t modrm = next();
  uint8_t arg2 = (modrm>>3)&0x7;
  trace(2, "run") << "add reg " << static_cast<int>(arg2) << " to effective address" << end();
  int32_t* arg1 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, *arg1, Reg[arg2].i);
  break;
}

:(code)
// Implement tables 2-2 and 2-3 in the Intel manual, Volume 2.
// We return a pointer so that instructions can write to multiple bytes in
// 'Mem' at once.
int32_t* effective_address(uint8_t modrm) {
  uint8_t mod = (modrm>>6);
  // ignore middle 3 'reg opcode' bits
  uint8_t rm = modrm & 0x7;
  int32_t* result = 0;
  switch (mod) {
    case 0:
      // mod 0 is usually indirect addressing
      switch (rm) {
      default:
        trace(99, "run") << "effective address is mem at address 0x" << std::hex << Reg[rm].u << " (reg " << static_cast<int>(rm) << ")" << end();
        assert(Reg[rm].u + sizeof(int32_t) <= Mem.size());
        result = reinterpret_cast<int32_t*>(&Mem.at(Reg[rm].u));  // rely on the host itself being in little-endian order
        break;
      // End Mod 0 Special-Cases
      }
      break;
    // End Mod Special-Cases
  }
  return result;
}

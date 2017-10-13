//: operating on memory at the address provided by some register

:(scenario add_r32_to_mem_at_r32)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
# word in addresses 0x60-0x63 has value 1
% Mem.at(0x60) = 1;
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX (reg 3) to *EAX (reg 0)
+run: add reg 3 to effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000011

:(before "End Mod Special-cases")
case 0:
  // mod 0 is usually indirect addressing
  switch (rm) {
  default:
    trace(2, "run") << "effective address is mem at address 0x" << std::hex << Reg[rm].u << " (reg " << NUM(rm) << ")" << end();
    assert(Reg[rm].u + sizeof(int32_t) <= Mem.size());
    result = reinterpret_cast<int32_t*>(&Mem.at(Reg[rm].u));  // rely on the host itself being in little-endian order
    break;
  // End Mod 0 Special-cases
  }
  break;

//:

:(scenario add_mem_at_r32_to_r32)
% Reg[0].i = 0x60;
% Reg[3].i = 0x10;
% Mem.at(0x60) = 1;
# op  ModR/M  SIB   displacement  immediate
  03  18                                      # add *EAX (reg 0) to EBX (reg 3)
+run: add effective address to reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x03: {  // add r/m32 to r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "add effective address to reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, Reg[arg1].i, *arg2);
  break;
}

//:: subtract

:(scenario subtract_r32_from_mem_at_r32)
% Reg[0].i = 0x60;
% Mem.at(0x60) = 10;
% Reg[3].i = 1;
# op  ModRM   SIB   displacement  immediate
  29  18                                      # subtract EBX (reg 3) from *EAX (reg 0)
+run: subtract reg 3 from effective address
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000009

//:

:(scenario subtract_mem_at_r32_from_r32)
% Reg[0].i = 0x60;
% Mem.at(0x60) = 1;
% Reg[3].i = 10;
# op  ModRM   SIB   displacement  immediate
  2b  18                                      # subtract *EAX (reg 0) from EBX (reg 3)
+run: subtract effective address from reg 3
+run: effective address is mem at address 0x60 (reg 0)
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x2b: {  // subtract r/m32 from r32
  uint8_t modrm = next();
  uint8_t arg1 = (modrm>>3)&0x7;
  trace(2, "run") << "subtract effective address from reg " << NUM(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, Reg[arg1].i, *arg2);
  break;
}

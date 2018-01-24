//: operating on memory at the address provided by some register plus optional scale and offset

:(scenario add_r32_to_mem_at_r32_with_sib)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  1c      20                             # add EBX to *EAX
# SIB in binary: 00 (scale 1) 100 (no index) 000 (base EAX)
# See Table 2-3 of the Intel programming manual.
+run: add EBX to effective address
+run: effective address is mem at address 0x60 (EAX)
+run: storing 0x00000011

:(before "End Mod 0 Special-cases")
case 4:
  // exception: SIB addressing
  uint8_t sib = next();
  uint8_t base = sib&0x7;
  uint8_t index = (sib>>3)&0x7;
  if (index == ESP) {
    // ignore index and scale
    trace(2, "run") << "effective address is mem at address 0x" << std::hex << Reg[base].u << " (" << rname(base) << ")" << end();
    result = reinterpret_cast<int32_t*>(&Mem.at(Reg[base].u));
  }
  else {
    uint8_t scale = (1 << (sib>>6));
    uint32_t addr = Reg[base].u + Reg[index].u*scale;
    trace(2, "run") << "effective address is mem at address 0x" << std::hex << addr << " (" << rname(base) << " + " << rname(index) << "*" << NUM(scale) << ")" << end();
    result = reinterpret_cast<int32_t*>(&Mem.at(addr));
  }
  break;

:(scenario add_r32_to_mem_at_base_plus_index)
% Reg[3].i = 0x10;  // source
% Reg[0].i = 0x5e;  // dest base
% Reg[1].i = 0x2;  // dest index
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  1c      08                             # add EBX to *(EAX+ECX)
# SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
# See Table 2-3 of the Intel programming manual.
+run: add EBX to effective address
+run: effective address is mem at address 0x60 (EAX + ECX*1)
+run: storing 0x00000011

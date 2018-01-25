//: operating on memory at the address provided by some register plus optional scale and offset

:(scenario add_r32_to_mem_at_r32_with_sib)
% Reg[3].i = 0x10;
% Reg[0].i = 0x60;
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  1c      20                             # add EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 100 (no index) 000 (base EAX)
+run: add EBX to r/m32
+run: effective address is initially 0x60 (EAX)
+run: effective address is 0x60
+run: storing 0x00000011

:(before "End Mod 0 Special-cases")
case 4:  // exception: mod 0b00 rm 0b100 => incoming SIB (scale-index-base) byte
  uint32_t addr = effective_address_from_sib(mod);
  if (addr == 0) break;
  result = reinterpret_cast<int32_t*>(&Mem.at(addr));
  break;
:(code)
uint32_t effective_address_from_sib(uint8_t mod) {
  uint8_t sib = next();
  uint8_t base = sib&0x7;
  uint32_t addr = 0;
  if (base != EBP || mod != 0) {
    addr = Reg[base].u;
    trace(2, "run") << "effective address is initially 0x" << std::hex << addr << " (" << rname(base) << ")" << end();
  }
  else {
    // base == EBP && mod == 0
    addr = imm32();
    trace(2, "run") << "effective address is initially 0x" << std::hex << addr << " (disp32)" << end();
  }
  uint8_t index = (sib>>3)&0x7;
  if (index == ESP) {
    // ignore index and scale
    trace(2, "run") << "effective address is 0x" << std::hex << addr << end();
  }
  else {
    uint8_t scale = (1 << (sib>>6));
    addr += Reg[index].i*scale;  // treat index register as signed. Maybe base as well? But we'll always ensure it's non-negative.
    trace(2, "run") << "effective address is 0x" << std::hex << addr << " (after adding " << rname(index) << "*" << NUM(scale) << ")" << end();
  }
  return addr;
}

:(scenario add_r32_to_mem_at_base_r32_index_r32)
% Reg[3].i = 0x10;  // source
% Reg[0].i = 0x5e;  // dest base
% Reg[1].i = 0x2;  // dest index
% SET_WORD_IN_MEM(0x60, 1);
# op  ModR/M  SIB   displacement  immediate
  01  1c      08                             # add EBX to *(EAX+ECX)
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
+run: add EBX to r/m32
+run: effective address is initially 0x5e (EAX)
+run: effective address is 0x60 (after adding ECX*1)
+run: storing 0x00000011

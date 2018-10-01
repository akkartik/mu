//: operating on memory at the address provided by some register plus optional scale and offset

:(scenario add_r32_to_mem_at_r32_with_sib)
% Reg[EBX].i = 0x10;
% Reg[EAX].i = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  1c      20                             # add EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 100 (no index) 000 (base EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x2000 (EAX)
+run: effective address is 0x2000
+run: storing 0x00000011

:(before "End Mod 0 Special-cases(addr)")
case 4:  // exception: mod 0b00 rm 0b100 => incoming SIB (scale-index-base) byte
  addr = effective_address_from_sib(mod);
  break;
:(code)
uint32_t effective_address_from_sib(uint8_t mod) {
  uint8_t sib = next();
  uint8_t base = sib&0x7;
  uint32_t addr = 0;
  if (base != EBP || mod != 0) {
    addr = Reg[base].u;
    trace(90, "run") << "effective address is initially 0x" << std::hex << addr << " (" << rname(base) << ")" << end();
  }
  else {
    // base == EBP && mod == 0
    addr = next32();  // ignore base
    trace(90, "run") << "effective address is initially 0x" << std::hex << addr << " (disp32)" << end();
  }
  uint8_t index = (sib>>3)&0x7;
  if (index == ESP) {
    // ignore index and scale
    trace(90, "run") << "effective address is 0x" << std::hex << addr << end();
  }
  else {
    uint8_t scale = (1 << (sib>>6));
    addr += Reg[index].i*scale;  // treat index register as signed. Maybe base as well? But we'll always ensure it's non-negative.
    trace(90, "run") << "effective address is 0x" << std::hex << addr << " (after adding " << rname(index) << "*" << NUM(scale) << ")" << end();
  }
  return addr;
}

:(scenario add_r32_to_mem_at_base_r32_index_r32)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x1ffe;  // dest base
% Reg[ECX].i = 0x2;  // dest index
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  1c      08                             # add EBX to *(EAX+ECX)
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x1ffe (EAX)
+run: effective address is 0x2000 (after adding ECX*1)
+run: storing 0x00000011

:(scenario add_r32_to_mem_at_displacement_using_sib)
% Reg[EBX].i = 0x10;  // source
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  1c      25    00 20 00 00              # add EBX to *0x2000
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 100 (no index) 101 (not EBP but disp32)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x2000 (disp32)
+run: effective address is 0x2000
+run: storing 0x00000011

//:

:(scenario add_r32_to_mem_at_base_r32_index_r32_plus_disp8)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x1ff9;  // dest base
% Reg[ECX].i = 0x5;  // dest index
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  5c      08    02                       # add EBX to *(EAX+ECX+2)
# ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x1ff9 (EAX)
+run: effective address is 0x1ffe (after adding ECX*1)
+run: effective address is 0x2000 (after adding disp8)
+run: storing 0x00000011

:(before "End Mod 1 Special-cases(addr)")
case 4:  // exception: mod 0b01 rm 0b100 => incoming SIB (scale-index-base) byte
  addr = effective_address_from_sib(mod);
  break;

//:

:(scenario add_r32_to_mem_at_base_r32_index_r32_plus_disp32)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x1ff9;  // dest base
% Reg[ECX].i = 0x5;  // dest index
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  9c      08    02 00 00 00              # add EBX to *(EAX+ECX+2)
# ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 100 (dest in SIB)
# SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x1ff9 (EAX)
+run: effective address is 0x1ffe (after adding ECX*1)
+run: effective address is 0x2000 (after adding disp32)
+run: storing 0x00000011

:(before "End Mod 2 Special-cases(addr)")
case 4:  // exception: mod 0b10 rm 0b100 => incoming SIB (scale-index-base) byte
  addr = effective_address_from_sib(mod);
  break;

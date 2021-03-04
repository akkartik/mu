//: operating on memory at the address provided by some register plus optional scale and offset

:(code)
void test_add_r32_to_mem_at_rm32_with_sib() {
  Reg[EBX].i = 0x10;
  Reg[EAX].i = 0x2000;
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     1c      20                              \n"  // add EBX to *EAX
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
      // SIB in binary: 00 (scale 1) 100 (no index) 000 (base EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00002000 (EAX)\n"
      "run: effective address is 0x00002000\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod 0 Special-cases(addr)")
case 4:  // exception: mod 0b00 rm 0b100 => incoming SIB (scale-index-base) byte
  addr = effective_address_from_sib(mod);
  break;
:(code)
uint32_t effective_address_from_sib(uint8_t mod) {
  const uint8_t sib = next();
  const uint8_t base = sib&0x7;
  uint32_t addr = 0;
  if (base != EBP || mod != 0) {
    addr = Reg[base].u;
    trace(Callstack_depth+1, "run") << "effective address is initially 0x" << HEXWORD << addr << " (" << rname(base) << ")" << end();
  }
  else {
    // base == EBP && mod == 0
    addr = next32();  // ignore base
    trace(Callstack_depth+1, "run") << "effective address is initially 0x" << HEXWORD << addr << " (disp32)" << end();
  }
  const uint8_t index = (sib>>3)&0x7;
  if (index == ESP) {
    // ignore index and scale
    trace(Callstack_depth+1, "run") << "effective address is 0x" << HEXWORD << addr << end();
  }
  else {
    const uint8_t scale = (1 << (sib>>6));
    addr += Reg[index].i*scale;  // treat index register as signed. Maybe base as well? But we'll always ensure it's non-negative.
    trace(Callstack_depth+1, "run") << "effective address is 0x" << HEXWORD << addr << " (after adding " << rname(index) << "*" << NUM(scale) << ")" << end();
  }
  return addr;
}

:(code)
void test_add_r32_to_mem_at_base_r32_index_r32() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x1ffe;  // dest base
  Reg[ECX].i = 0x2;  // dest index
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     1c      08                              \n"  // add EBX to *(EAX+ECX)
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
      // SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00001ffe (EAX)\n"
      "run: effective address is 0x00002000 (after adding ECX*1)\n"
      "run: storing 0x00000011\n"
  );
}

:(code)
void test_add_r32_to_mem_at_displacement_using_sib() {
  Reg[EBX].i = 0x10;  // source
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     1c      25    00 20 00 00               \n"  // add EBX to *0x2000
      // ModR/M in binary: 00 (indirect mode) 011 (src EBX) 100 (dest in SIB)
      // SIB in binary: 00 (scale 1) 100 (no index) 101 (not EBP but disp32)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00002000 (disp32)\n"
      "run: effective address is 0x00002000\n"
      "run: storing 0x00000011\n"
  );
}

//:

:(code)
void test_add_r32_to_mem_at_base_r32_index_r32_plus_disp8() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x1ff9;  // dest base
  Reg[ECX].i = 0x5;  // dest index
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     5c      08    02                        \n"  // add EBX to *(EAX+ECX+2)
      // ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 100 (dest in SIB)
      // SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00001ff9 (EAX)\n"
      "run: effective address is 0x00001ffe (after adding ECX*1)\n"
      "run: effective address is 0x00002000 (after adding disp8)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod 1 Special-cases(addr)")
case 4:  // exception: mod 0b01 rm 0b100 => incoming SIB (scale-index-base) byte
  addr = effective_address_from_sib(mod);
  break;

//:

:(code)
void test_add_r32_to_mem_at_base_r32_index_r32_plus_disp32() {
  Reg[EBX].i = 0x10;  // source
  Reg[EAX].i = 0x1ff9;  // dest base
  Reg[ECX].i = 0x5;  // dest index
  run(
      "== code 0x1\n"
      // op     ModR/M  SIB   displacement  immediate
      "  01     9c      08    02 00 00 00               \n"  // add EBX to *(EAX+ECX+2)
      // ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 100 (dest in SIB)
      // SIB in binary: 00 (scale 1) 001 (index ECX) 000 (base EAX)
      "== data 0x2000\n"
      "01 00 00 00\n"  // 1
  );
  CHECK_TRACE_CONTENTS(
      "run: add EBX to r/m32\n"
      "run: effective address is initially 0x00001ff9 (EAX)\n"
      "run: effective address is 0x00001ffe (after adding ECX*1)\n"
      "run: effective address is 0x00002000 (after adding disp32)\n"
      "run: storing 0x00000011\n"
  );
}

:(before "End Mod 2 Special-cases(addr)")
case 4:  // exception: mod 0b10 rm 0b100 => incoming SIB (scale-index-base) byte
  addr = effective_address_from_sib(mod);
  break;

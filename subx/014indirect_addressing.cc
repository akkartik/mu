//: operating on memory at the address provided by some register
//: we'll now start providing data in a separate segment

:(scenario add_r32_to_mem_at_r32)
% Reg[EBX].i = 0x10;
% Reg[EAX].i = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  18                                     # add EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is 0x00002000 (EAX)
+run: storing 0x00000011

:(before "End Mod Special-cases(addr)")
case 0:  // indirect addressing
  switch (rm) {
  default:  // address in register
    trace(90, "run") << "effective address is 0x" << HEXWORD << Reg[rm].u << " (" << rname(rm) << ")" << end();
    addr = Reg[rm].u;
    break;
  // End Mod 0 Special-cases(addr)
  }
  break;

//:

:(before "End Initialize Op Names")
put_new(Name, "03", "add rm32 to r32 (add)");

:(scenario add_mem_at_r32_to_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x10;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  03  18                                      # add *EAX to EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add r/m32 to EBX
+run: effective address is 0x00002000 (EAX)
+run: storing 0x00000011

:(before "End Single-Byte Opcodes")
case 0x03: {  // add r/m32 to r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "add r/m32 to " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(+, Reg[arg1].i, *arg2);
  break;
}

//:: subtract

:(scenario subtract_r32_from_mem_at_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 1;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  29  18                                      # subtract EBX from *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0a 00 00 00  # 10
+run: subtract EBX from r/m32
+run: effective address is 0x00002000 (EAX)
+run: storing 0x00000009

//:

:(before "End Initialize Op Names")
put_new(Name, "2b", "subtract rm32 from r32 (sub)");

:(scenario subtract_mem_at_r32_from_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 10;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  2b  18                                      # subtract *EAX from EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: subtract r/m32 from EBX
+run: effective address is 0x00002000 (EAX)
+run: storing 0x00000009

:(before "End Single-Byte Opcodes")
case 0x2b: {  // subtract r/m32 from r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "subtract r/m32 from " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_ARITHMETIC_OP(-, Reg[arg1].i, *arg2);
  break;
}

//:: and

:(scenario and_r32_with_mem_at_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0xff;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  21  18                                      # and EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: and EBX with r/m32
+run: effective address is 0x00002000 (EAX)
+run: storing 0x0000000d

//:

:(before "End Initialize Op Names")
put_new(Name, "23", "r32 = bitwise AND of r32 with rm32 (and)");

:(scenario and_mem_at_r32_with_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  23  18                                      # and *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
ff 00 00 00  # 0xff
+run: and r/m32 with EBX
+run: effective address is 0x00002000 (EAX)
+run: storing 0x0000000d

:(before "End Single-Byte Opcodes")
case 0x23: {  // and r/m32 with r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "and r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(&, Reg[arg1].u, *arg2);
  break;
}

//:: or

:(scenario or_r32_with_mem_at_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  09  18                                      # or EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: or EBX with r/m32
+run: effective address is 0x00002000 (EAX)
+run: storing 0xaabbccdd

//:

:(before "End Initialize Op Names")
put_new(Name, "0b", "r32 = bitwise OR of r32 with rm32 (or)");

:(scenario or_mem_at_r32_with_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  0b  18                                      # or *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: or r/m32 with EBX
+run: effective address is 0x00002000 (EAX)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x0b: {  // or r/m32 with r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "or r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: xor

:(scenario xor_r32_with_mem_at_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  31  18                                      # xor EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c bb aa  # 0xaabb0c0d
+run: xor EBX with r/m32
+run: effective address is 0x00002000 (EAX)
+run: storing 0x0a0bccdd

//:

:(before "End Initialize Op Names")
put_new(Name, "33", "r32 = bitwise XOR of r32 with rm32 (xor)");

:(scenario xor_mem_at_r32_with_r32)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0xa0b0c0d0;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  33  18                                      # xor *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: xor r/m32 with EBX
+run: effective address is 0x00002000 (EAX)
+run: storing 0xaabbccdd

:(before "End Single-Byte Opcodes")
case 0x33: {  // xor r/m32 with r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "xor r/m32 with " << rname(arg1) << end();
  const int32_t* arg2 = effective_address(modrm);
  BINARY_BITWISE_OP(|, Reg[arg1].u, *arg2);
  break;
}

//:: not

:(scenario not_of_mem_at_r32)
% Reg[EBX].i = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  f7  13                                      # not *EBX
# ModR/M in binary: 00 (indirect mode) 010 (subop not) 011 (dest EBX)
== 0x2000  # data segment
ff 00 0f 0f  # 0x0f0f00ff
+run: operate on r/m32
+run: effective address is 0x00002000 (EBX)
+run: subop: not
+run: storing 0xf0f0ff00

//:: compare (cmp)

:(scenario compare_mem_at_r32_with_r32_greater)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c07;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare EBX with r/m32
+run: effective address is 0x00002000 (EAX)
+run: SF=0; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_lesser)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
07 0c 0b 0a  # 0x0a0b0c0d
+run: compare EBX with r/m32
+run: effective address is 0x00002000 (EAX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_mem_at_r32_with_r32_equal)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  39  18                                      # compare EBX with *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare EBX with r/m32
+run: effective address is 0x00002000 (EAX)
+run: SF=0; ZF=1; OF=0

//:

:(before "End Initialize Op Names")
put_new(Name, "3b", "compare: set SF if r32 < rm32 (cmp)");

:(scenario compare_r32_with_mem_at_r32_greater)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
07 0c 0b 0a  # 0x0a0b0c0d
+run: compare r/m32 with EBX
+run: effective address is 0x00002000 (EAX)
+run: SF=0; ZF=0; OF=0

:(before "End Single-Byte Opcodes")
case 0x3b: {  // set SF if r32 < r/m32
  const uint8_t modrm = next();
  const uint8_t reg1 = (modrm>>3)&0x7;
  trace(90, "run") << "compare r/m32 with " << rname(reg1) << end();
  const int32_t arg1 = Reg[reg1].i;
  const int32_t* arg2 = effective_address(modrm);
  const int32_t tmp1 = arg1 - *arg2;
  SF = (tmp1 < 0);
  ZF = (tmp1 == 0);
  int64_t tmp2 = arg1 - *arg2;
  OF = (tmp1 != tmp2);
  trace(90, "run") << "SF=" << SF << "; ZF=" << ZF << "; OF=" << OF << end();
  break;
}

:(scenario compare_r32_with_mem_at_r32_lesser)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c07;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare r/m32 with EBX
+run: effective address is 0x00002000 (EAX)
+run: SF=1; ZF=0; OF=0

:(scenario compare_r32_with_mem_at_r32_equal)
% Reg[EAX].i = 0x2000;
% Reg[EBX].i = 0x0a0b0c0d;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  3b  18                                      # compare *EAX with EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
== 0x2000  # data segment
0d 0c 0b 0a  # 0x0a0b0c0d
+run: compare r/m32 with EBX
+run: effective address is 0x00002000 (EAX)
+run: SF=0; ZF=1; OF=0

//:: copy (mov)

:(scenario copy_r32_to_mem_at_r32)
% Reg[EBX].i = 0xaf;
% Reg[EAX].i = 0x60;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  89  18                                      # copy EBX to *EAX
# ModR/M in binary: 00 (indirect mode) 011 (src EAX) 000 (dest EAX)
+run: copy EBX to r/m32
+run: effective address is 0x00000060 (EAX)
+run: storing 0x000000af

//:

:(before "End Initialize Op Names")
put_new(Name, "8b", "copy rm32 to r32 (mov)");

:(scenario copy_mem_at_r32_to_r32)
% Reg[EAX].i = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  8b  18                                      # copy *EAX to EBX
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 000 (dest EAX)
== 0x2000  # data segment
af 00 00 00  # 0xaf
+run: copy r/m32 to EBX
+run: effective address is 0x00002000 (EAX)
+run: storing 0x000000af

:(before "End Single-Byte Opcodes")
case 0x8b: {  // copy r32 to r/m32
  const uint8_t modrm = next();
  const uint8_t rdest = (modrm>>3)&0x7;
  trace(90, "run") << "copy r/m32 to " << rname(rdest) << end();
  const int32_t* src = effective_address(modrm);
  Reg[rdest].i = *src;
  trace(90, "run") << "storing 0x" << HEXWORD << *src << end();
  break;
}

//:: jump

:(scenario jump_mem_at_r32)
% Reg[EAX].i = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  20                                      # jump to *EAX
# ModR/M in binary: 00 (indirect mode) 100 (jump to r/m32) 000 (src EAX)
  05                              00 00 00 01
  05                              00 00 00 02
== 0x2000  # data segment
08 00 00 00  # 8
+run: inst: 0x00000001
+run: jump to r/m32
+run: effective address is 0x00002000 (EAX)
+run: jumping to 0x00000008
+run: inst: 0x00000008
-run: inst: 0x00000003

:(before "End Op ff Subops")
case 4: {  // jump to r/m32
  trace(90, "run") << "jump to r/m32" << end();
  const int32_t* arg2 = effective_address(modrm);
  EIP = *arg2;
  trace(90, "run") << "jumping to 0x" << HEXWORD << EIP << end();
  break;
}

//:: push

:(scenario push_mem_at_r32)
% Reg[EAX].i = 0x2000;
% Reg[ESP].u = 0x14;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  ff  30                                      # push *EAX to stack
# ModR/M in binary: 00 (indirect mode) 110 (push r/m32) 000 (src EAX)
== 0x2000  # data segment
af 00 00 00  # 0xaf
+run: push r/m32
+run: effective address is 0x00002000 (EAX)
+run: decrementing ESP to 0x00000010
+run: pushing value 0x000000af

:(before "End Op ff Subops")
case 6: {  // push r/m32 to stack
  trace(90, "run") << "push r/m32" << end();
  const int32_t* val = effective_address(modrm);
  push(*val);
  break;
}

//:: pop

:(before "End Initialize Op Names")
put_new(Name, "8f", "pop top of stack to rm32 (pop)");

:(scenario pop_mem_at_r32)
% Reg[EAX].i = 0x60;
% Reg[ESP].u = 0x2000;
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  8f  00                                      # pop stack into *EAX
# ModR/M in binary: 00 (indirect mode) 000 (pop r/m32) 000 (dest EAX)
== 0x2000  # data segment
30 00 00 00  # 0x30
+run: pop into r/m32
+run: effective address is 0x00000060 (EAX)
+run: popping value 0x00000030
+run: incrementing ESP to 0x00002004

:(before "End Single-Byte Opcodes")
case 0x8f: {  // pop stack into r/m32
  const uint8_t modrm = next();
  const uint8_t subop = (modrm>>3)&0x7;
  switch (subop) {
    case 0: {
      trace(90, "run") << "pop into r/m32" << end();
      int32_t* dest = effective_address(modrm);
      *dest = pop();
      break;
    }
  }
  break;
}

//:: special-case for loading address from disp32 rather than register

:(scenario add_r32_to_mem_at_displacement)
% Reg[EBX].i = 0x10;  // source
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  1d            00 20 00 00              # add EBX to *0x2000
# ModR/M in binary: 00 (indirect mode) 011 (src EBX) 101 (dest in disp32)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is 0x00002000 (disp32)
+run: storing 0x00000011

:(before "End Mod 0 Special-cases(addr)")
case 5:  // exception: mod 0b00 rm 0b101 => incoming disp32
  addr = next32();
  trace(90, "run") << "effective address is 0x" << HEXWORD << addr << " (disp32)" << end();
  break;

//:

:(scenario add_r32_to_mem_at_r32_plus_disp8)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x1ffe;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  58            02                       # add EBX to *(EAX+2)
# ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x00001ffe (EAX)
+run: effective address is 0x00002000 (after adding disp8)
+run: storing 0x00000011

:(before "End Mod Special-cases(addr)")
case 1:  // indirect + disp8 addressing
  switch (rm) {
  default:
    addr = Reg[rm].u;
    trace(90, "run") << "effective address is initially 0x" << HEXWORD << addr << " (" << rname(rm) << ")" << end();
    break;
  // End Mod 1 Special-cases(addr)
  }
  if (addr > 0) {
    addr += static_cast<int8_t>(next());
    trace(90, "run") << "effective address is 0x" << HEXWORD << addr << " (after adding disp8)" << end();
  }
  break;

:(scenario add_r32_to_mem_at_r32_plus_negative_disp8)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x2001;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  58            ff                       # add EBX to *(EAX-1)
# ModR/M in binary: 01 (indirect+disp8 mode) 011 (src EBX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x00002001 (EAX)
+run: effective address is 0x00002000 (after adding disp8)
+run: storing 0x00000011

//:

:(scenario add_r32_to_mem_at_r32_plus_disp32)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x1ffe;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  98            02 00 00 00              # add EBX to *(EAX+2)
# ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x00001ffe (EAX)
+run: effective address is 0x00002000 (after adding disp32)
+run: storing 0x00000011

:(before "End Mod Special-cases(addr)")
case 2:  // indirect + disp32 addressing
  switch (rm) {
  default:
    addr = Reg[rm].u;
    trace(90, "run") << "effective address is initially 0x" << HEXWORD << addr << " (" << rname(rm) << ")" << end();
    break;
  // End Mod 2 Special-cases(addr)
  }
  if (addr > 0) {
    addr += next32();
    trace(90, "run") << "effective address is 0x" << HEXWORD << addr << " (after adding disp32)" << end();
  }
  break;

:(scenario add_r32_to_mem_at_r32_plus_negative_disp32)
% Reg[EBX].i = 0x10;  // source
% Reg[EAX].i = 0x2001;  // dest
== 0x1  # code segment
# op  ModR/M  SIB   displacement  immediate
  01  98            ff ff ff ff              # add EBX to *(EAX-1)
# ModR/M in binary: 10 (indirect+disp32 mode) 011 (src EBX) 000 (dest EAX)
== 0x2000  # data segment
01 00 00 00  # 1
+run: add EBX to r/m32
+run: effective address is initially 0x00002001 (EAX)
+run: effective address is 0x00002000 (after adding disp32)
+run: storing 0x00000011

//:: lea

:(before "End Initialize Op Names")
put_new(Name, "8d", "copy address in rm32 into r32 (lea)");

:(scenario lea)
% Reg[EAX].u = 0x2000;
== 0x1
# op  ModR/M  SIB   displacement  immediate
  8d  18
# ModR/M in binary: 00 (indirect mode) 011 (dest EBX) 000 (src EAX)
+run: lea into EBX
+run: effective address is 0x00002000 (EAX)

:(before "End Single-Byte Opcodes")
case 0x8d: {  // lea m32 to r32
  const uint8_t modrm = next();
  const uint8_t arg1 = (modrm>>3)&0x7;
  trace(90, "run") << "lea into " << rname(arg1) << end();
  Reg[arg1].u = effective_address_number(modrm);
  break;
}

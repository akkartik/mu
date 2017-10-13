//: operating directly on a register

:(scenario add_r32_to_r32)
% Reg[0].i = 0x10;
% Reg[3].i = 1;
# op  ModR/M  SIB   displacement  immediate
  01  d8                                      # add EBX (reg 3) to EAX (reg 0)
+run: add reg 3 to effective address
+run: effective address is reg 0
+run: storing 0x00000011

:(before "End Mod Special-cases")
case 3:
  // mod 3 is just register direct addressing
  trace(2, "run") << "effective address is reg " << NUM(rm) << end();
  result = &Reg[rm].i;
  break;

//:: subtract

:(scenario subtract_r32_from_r32)
% Reg[0].i = 10;
% Reg[3].i = 1;
# op  ModR/M  SIB   displacement  immediate
  29  d8                                      # subtract EBX (reg 3) from EAX (reg 0)
+run: subtract reg 3 from effective address
+run: effective address is reg 0
+run: storing 0x00000009

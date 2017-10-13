//: operating directly on a register

:(before "End Mod Special-cases")
case 3:
  // mod 3 is just register direct addressing
  trace(2, "run") << "effective address is reg " << NUM(rm) << end();
  result = &Reg[rm].i;
  break;

//:: subtract

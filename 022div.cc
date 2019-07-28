//: helper for division operations: sign-extend EAX into EDX

:(before "End Initialize Op Names")
put_new(Name, "99", "sign-extend EAX into EDX (cdq)");

:(code)
void test_cdq() {
  Reg[EAX].i = 10;
  run(
      "== code 0x1\n"
      "99\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: sign-extend EAX into EDX\n"
      "run: EDX is now 0x00000000\n"
  );
}

:(before "End Single-Byte Opcodes")
case 0x99: {  // sign-extend EAX into EDX
  trace(Callstack_depth+1, "run") << "sign-extend EAX into EDX" << end();
  Reg[EDX].i = (Reg[EAX].i < 0) ? -1 : 0;
  trace(Callstack_depth+1, "run") << "EDX is now 0x" << HEXWORD << Reg[EDX].u << end();
  break;
}

:(code)
void test_cdq_negative() {
  Reg[EAX].i = -10;
  run(
      "== code 0x1\n"
      "99\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: sign-extend EAX into EDX\n"
      "run: EDX is now 0xffffffff\n"
  );
}

//: Now that we have operand metadata, start warning on instructions that
//: don't use it.
//:
//: While SubX will let you write raw machine code, don't do that unless you
//: have a very good reason.

:(before "Pack Operands(segment code)")
warn_on_raw_hex(code);
if (trace_contains_errors()) return;
:(code)
void warn_on_raw_hex(const segment& code) {
  trace(99, "transform") << "-- warn on raw hex instructions" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    if (all_hex_bytes(inst) && has_operands(inst)) {
      warn << "'" << to_string(inst) << "': using raw hex is not recommended\n" << end();
      break;
    }
  }
}

:(scenarios transform)
:(scenario warn_on_hex_bytes_without_operands)
== 0x1
bb 2a 00 00 00  # copy 0x2a (42) to EBX
+warn: 'bb 2a 00 00 00': using raw hex is not recommended

:(scenario warn_on_non_operand_metadata)
== 0x1
bb 2a 00/foo 00/bar 00  # copy 0x2a (42) to EBX
+warn: 'bb 2a 00/foo 00/bar 00': using raw hex is not recommended

:(scenario no_warn_on_instructions_without_operands)
== 0x1
55  # push EBP
-warn: '55': using raw hex is not recommended

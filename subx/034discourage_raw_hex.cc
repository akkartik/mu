//: Now that we have operand metadata, start warning on instructions that
//: don't use it.
//:
//: While SubX will let you write raw machine code, don't do that unless you
//: have a very good reason.

:(after "Begin Level-2 Transforms")
Transform.push_back(warn_on_raw_jumps);
:(code)
void warn_on_raw_jumps(/*const*/ program& p) {
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  trace(99, "transform") << "-- warn on raw hex instructions" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    if (all_hex_bytes(inst) && has_operands(inst)) {
      warn << "'" << to_string(inst) << "': using raw hex is not recommended.\n" << end();
      break;
    }
  }
}

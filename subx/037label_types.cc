//: Distinguish between labels marking the start of a function, and labels
//: inside functions.
//:
//: - Labels within functions start with a '$', and are only permitted in
//:   'jump' instructions.
//:
//: - Labels marking the start of functions lack the '$' sigil, and are only
//:   permitted in 'call' instructions.

:(before "Rewrite Labels(segment code)")
check_label_types(code);
if (trace_contains_errors()) return;
:(code)
void check_label_types(const segment& code) {
  trace(99, "transform") << "-- check label types" << end();
  for (int i = 0;  i < SIZE(code.lines);  ++i)
    check_label_types(code.lines.at(i));
}

void check_label_types(const line& inst) {
  int idx = first_operand(inst);
  if (idx >= SIZE(inst.words)) return;
  const word& target = inst.words.at(idx);
  if (is_number(target.data)) return;  // handled elsewhere
  if (is_jump(inst) && target.data.at(0) != '$')
    raise << "'" << inst.original << "': jumps should always be to internal labels starting with '$'\n" << end();
  if (is_call(inst) && target.data.at(0) == '$')
    raise << "'" << inst.original << "': calls should always be to function labels (not starting with '$')\n" << end();
}

:(scenario catch_jump_to_function)
% Hide_errors = true;
== 0x1
main:
7e/jump-if foo/disp8
foo:
+error: '7e/jump-if foo/disp8': jumps should always be to internal labels starting with '$'

:(scenario catch_call_to_internal_label)
% Hide_errors = true;
== 0x1
main:
e8/call $foo/disp32
 $foo:  # indent to avoid looking like a trace_count command for this scenario
+error: 'e8/call $foo/disp32': calls should always be to function labels (not starting with '$')

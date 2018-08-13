//: Make sure that we never jump from one function to within another.
//:
//: (The check for label types already ensures we can't jump to the start of
//: another function.)

:(scenario jump_to_different_function)
% Hide_errors = true;
== 0x1
fn1:
  7e/jump-if $target/disp8
fn2:
 $target:
+error: '7e/jump-if $target/disp8' in function 'fn1': jump to within another function 'fn2' is a *really* bad idea

:(before "Rewrite Labels(segment code)")
check_local_jumps(code);
if (trace_contains_errors()) return;
:(code)
void check_local_jumps(const segment& code) {
  map</*jump target*/string, /*containing call target*/string> function;
  compute_function_target(code, function);
  if (trace_contains_errors()) return;
  string current_function;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    if (SIZE(inst.words) == 1 && is_label(inst.words.at(0))) {
      // label definition
      if (inst.words.at(0).data.at(0) != '$')
        current_function = drop_last(inst.words.at(0).data);
    }
    else if (is_jump(inst)) {
      const word& target = inst.words.at(first_operand(inst));
      if (!contains_key(function, target.data)) continue;  // error/warning handled elsewhere
      if (get(function, target.data) == current_function) continue;
      raise << "'" << to_string(inst) << "' in function '" << current_function << "': jump to within another function '" << get(function, target.data) << "' is a *really* bad idea\n" << end();
      return;
    }
  }
}

void compute_function_target(const segment& code, map<string, string>& out) {
  string current_function;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    if (SIZE(inst.words) != 1) continue;
    const word& curr = inst.words.at(0);
    if (!is_label(curr)) continue;
    const string& label = drop_last(curr.data);
    if (label.at(0) != '$') {
      current_function = label;
      continue;
    }
    if (contains_key(out, label)) {
      raise << "duplicate label '" << label << "'\n" << end();
      return;
    }
    // current_function can be empty! if so that would be 'main'.
    put(out, label, current_function);
  }
}

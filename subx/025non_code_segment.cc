//: Raise an error when operand metadata is used in non-code segments.

:(scenario operand_metadata_outside_code_segment)
% Hide_errors = true;
== 0x1  # code segment
cd 0x80/imm8
== 0x1000  # data segment
cd 12/imm8
+error: 12/imm8: metadata imm8 is only allowed in the (first) code segment

:(before "End One-time Setup")
Transform.push_back(check_operands_in_non_code_segments);
:(code)
void check_operands_in_non_code_segments(/*const*/ program& p) {
  if (p.segments.empty()) return;
  for (int i = /*skip code segment*/1;  i < SIZE(p.segments);  ++i) {
    const segment& seg = p.segments.at(i);
    for (int j = 0;  j < SIZE(seg.lines);  ++j) {
      const line& l = seg.lines.at(j);
      for (int k = 0;  k < SIZE(l.words);  ++k) {
        const word& w = l.words.at(k);
        for (map<string, uint32_t>::iterator p = Operand_bound.begin();  p != Operand_bound.end();  ++p)
          if (has_metadata(w, p->first))
            raise << w.original << ": metadata " << p->first << " is only allowed in the (first) code segment\n" << end();
      }
    }
  }
}

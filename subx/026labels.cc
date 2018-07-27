//: Labels are defined by ending names with a ':'. This layer will compute
//: addresses for labels, and compute the offset for instructions using them.

:(scenarios transform)
:(scenario map_label)
== 0x1
          # instruction                     effective address                                           operand     displacement    immediate
          # op          subop               mod             rm32          base      index     scale     r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
loop:
            05                                                                                                                      0x0d0c0b0a/imm32  # add to EAX
+translate: label 'loop' is at address 1

:(before "End One-time Setup")
Transform.push_back(replace_labels);

:(code)
void replace_labels(program& p) {
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  map<string, uint32_t> address;
  compute_addresses_for_labels(code, address);
  if (trace_contains_errors()) return;
  drop_labels(code);
  if (trace_contains_errors()) return;
  replace_labels_with_addresses(code, address);
}

void compute_addresses_for_labels(const segment& code, map<string, uint32_t> address) {
  int current_byte = 0;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      // hack: if we have any operand metadata left after previous transforms,
      // deduce its size
      // Maybe we should just move this transform to before instruction
      // packing, and deduce the size of *all* operands. But then we'll also
      // have to deal with bitfields.
      if (has_metadata(curr, "disp32") || has_metadata(curr, "imm32")) {
        if (*curr.data.rbegin() == ':')
          raise << "'" << to_string(inst) << "': don't use ':' when jumping to labels\n" << end();
        current_byte += 4;
      }
      // automatically handle /disp8 and /imm8 here
      else if (*curr.data.rbegin() != ':') {
        ++current_byte;
      }
      else {
        if (contains_any_operand_metadata(curr))
          raise << "'" << to_string(inst) << "': label definition (':') not allowed in operand\n" << end();
        if (j > 0)
          raise << "'" << to_string(inst) << "': labels can only be the first word in a line.\n" << end();
        string label = curr.data.substr(0, SIZE(curr.data)-1);
        put(address, label, current_byte);
        trace(99, "translate") << "label '" << label << "' is at address " << (current_byte+code.start) << end();
        // no modifying current_byte; label definitions won't be in the final binary
      }
    }
  }
}

void drop_labels(segment& code) {
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    remove_if(inst.words.begin(), inst.words.end(), is_label);
  }
}

bool is_label(const word& w) {
  return *w.data.rbegin() == ':';
}

void replace_labels_with_addresses(const segment& code, map<string, uint32_t> address) {
}

//: Label definitions must be the first word on a line. No jumping inside
//: instructions.
//: They should also be the only word on a line.
//: However, you can absolutely have multiple labels map to the same address,
//: as long as they're on separate lines.

:(scenario multiple_labels_at)
== 0x1
          # instruction                     effective address                                           operand     displacement    immediate
          # op          subop               mod             rm32          base      index     scale     r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits    3 bits    2 bits    2 bits      0/1/2/4 bytes   0/1/2/4 bytes
loop:
loop2:
            05                                                                                                                      0x0d0c0b0a/imm32  # add to EAX
loop3:
            f
+translate: label 'loop' is at address 1
+translate: label 'loop2' is at address 1
+translate: label 'loop3' is at address 6

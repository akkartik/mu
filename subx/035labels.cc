//: Labels are defined by ending names with a ':'. This layer will compute
//: addresses for labels, and compute the offset for instructions using them.

:(scenarios transform)
:(scenario map_label)
== 0x1
          # instruction                     effective address                                                   operand     displacement    immediate
          # op          subop               mod             rm32          base        index         scale       r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
loop:
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
+transform: label 'loop' is at address 1

:(before "End Transforms")
Transform.push_back(rewrite_labels);

:(code)
void rewrite_labels(program& p) {
  trace(99, "transform") << "-- rewrite labels" << end();
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  map<string, int32_t> address;  // values are unsigned, but we're going to do subtractions on them so they need to fit in 31 bits
  compute_addresses_for_labels(code, address);
  if (trace_contains_errors()) return;
  drop_labels(code);
  if (trace_contains_errors()) return;
  replace_labels_with_addresses(code, address);
}

void compute_addresses_for_labels(const segment& code, map<string, int32_t>& address) {
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
        trace(99, "transform") << "label '" << label << "' is at address " << (current_byte+code.start) << end();
        // no modifying current_byte; label definitions won't be in the final binary
      }
    }
  }
}

void drop_labels(segment& code) {
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    vector<word>::iterator new_end = remove_if(inst.words.begin(), inst.words.end(), is_label);
    inst.words.erase(new_end, inst.words.end());
  }
}

bool is_label(const word& w) {
  return *w.data.rbegin() == ':';
}

void replace_labels_with_addresses(segment& code, const map<string, int32_t>& address) {
  int32_t byte_next_instruction_starts_at = 0;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    byte_next_instruction_starts_at += num_bytes(inst);
    line new_inst;
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (contains_key(address, curr.data)) {
        int32_t offset = static_cast<int32_t>(get(address, curr.data)) - byte_next_instruction_starts_at;
        if (has_metadata(curr, "disp8") || has_metadata(curr, "imm8")) {
          if (offset > 0xff || offset < -0x7f)
            raise << "'" << to_string(inst) << "': label too far away for distance " << std::hex << offset << " to fit in 8 bits\n" << end();
          else
            emit_hex_bytes(new_inst, offset, 1);
        }
        else if (has_metadata(curr, "disp16")) {
          if (offset > 0xffff || offset < -0x7fff)
            raise << "'" << to_string(inst) << "': label too far away for distance " << std::hex << offset << " to fit in 16 bits\n" << end();
          else
            emit_hex_bytes(new_inst, offset, 2);
        }
        else if (has_metadata(curr, "disp32") || has_metadata(curr, "imm32")) {
          emit_hex_bytes(new_inst, offset, 4);
        }
      }
      else {
        new_inst.words.push_back(curr);
      }
    }
    inst.words.swap(new_inst.words);
    trace(99, "transform") << "instruction after transform: '" << data_to_string(inst) << "'" << end();
  }
}

// Assumes all bitfields are packed.
uint32_t num_bytes(const line& inst) {
  uint32_t sum = 0;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    const word& curr = inst.words.at(i);
    if (has_metadata(curr, "disp32") || has_metadata(curr, "imm32"))  // only multi-byte operands
      sum += 4;
    else
      sum++;
  }
  return sum;
}

string data_to_string(const line& inst) {
  ostringstream out;
  for (int i = 0;  i < SIZE(inst.words);  ++i) {
    if (i > 0) out << ' ';
    out << inst.words.at(i).data;
  }
  return out.str();
}

//: Label definitions must be the first word on a line. No jumping inside
//: instructions.
//: They should also be the only word on a line.
//: However, you can absolutely have multiple labels map to the same address,
//: as long as they're on separate lines.

:(scenario multiple_labels_at)
== 0x1
          # instruction                     effective address                                                   operand     displacement    immediate
          # op          subop               mod             rm32          base        index         scale       r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
# address 1
loop:
loop2:
# address 1 (labels take up no space)
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
# address 6
            eb                                                                                                              loop2/disp8
# address 8
            eb                                                                                                              loop3/disp8
# address 10
loop3:
+transform: label 'loop' is at address 1
+transform: label 'loop2' is at address 1
+transform: label 'loop3' is at address 10
# first jump is to -7
+transform: instruction after transform: 'eb f9'
# second jump is to 0 (fall through)
+transform: instruction after transform: 'eb 00'

//: Labels are defined by ending names with a ':'. This layer will compute
//: addresses for labels, and compute the offset for instructions using them.

//: We're introducing non-number names for the first time, so it's worth
//: laying down some ground rules all transforms will follow, so things don't
//: get too confusing:
//:   - if it starts with a digit, it's treated as a number. If it can't be
//:     parsed as hex it will raise an error.
//:   - if it starts with '-' it's treated as a number.
//:   - if it starts with '0x' it's treated as a number.
//:   - if it's two characters long, it can't be a name. Either it's a hex
//:     byte, or it raises an error.
//: That's it. Names can start with any non-digit that isn't a dash. They can
//: be a single character long. 'a' is not a hex number, it's a variable.
//: Later layers may add more conventions partitioning the space of names. But
//: the above rules will remain inviolate.
bool is_number(const string& s) {
  if (s.at(0) == '-') return true;
  if (isdigit(s.at(0))) return true;
  return SIZE(s) == 2;
}
:(before "End Unit Tests")
void test_is_number() {
  CHECK(!is_number("a"));
}
:(code)
void check_valid_name(const string& s) {
  if (s.empty()) {
    raise << "empty name!\n" << end();
    return;
  }
  if (s.at(0) == '-')
    raise << "'" << s << "' starts with '-', which can be confused with a negative number; use a different name\n" << end();
  if (s.substr(0, 2) == "0x") {
    raise << "'" << s << "' looks like a hex number; use a different name\n" << end();
    return;
  }
  if (isdigit(s.at(0)))
    raise << "'" << s << "' starts with a digit, and so can be confused with a negative number; use a different name.\n" << end();
  if (SIZE(s) == 2)
    raise << "'" << s << "' is two characters long which can look like raw hex bytes at a glance; use a different name\n" << end();
}

:(scenarios transform)
:(scenario map_label)
== 0x1
          # instruction                     effective address                                                   operand     displacement    immediate
          # op          subop               mod             rm32          base        index         scale       r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
loop:
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
+transform: label 'loop' is at address 1

:(before "End Level-2 Transforms")
Transform.push_back(rewrite_labels);
:(code)
void rewrite_labels(program& p) {
  trace(99, "transform") << "-- rewrite labels" << end();
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  // Rewrite Labels(segment code)
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
        string label = drop_last(curr.data);
        // ensure labels look sufficiently different from raw hex
        check_valid_name(label);
        if (trace_contains_errors()) return;
        if (contains_any_operand_metadata(curr))
          raise << "'" << to_string(inst) << "': label definition (':') not allowed in operand\n" << end();
        if (j > 0)
          raise << "'" << to_string(inst) << "': labels can only be the first word in a line.\n" << end();
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

string drop_last(const string& s) {
  return string(s.begin(), --s.end());
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
 $loop2:
# address 1 (labels take up no space)
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
# address 6
            eb                                                                                                              $loop2/disp8
# address 8
            eb                                                                                                              $loop3/disp8
# address 10
 $loop3:
+transform: label 'loop' is at address 1
+transform: label '$loop2' is at address 1
+transform: label '$loop3' is at address 10
# first jump is to -7
+transform: instruction after transform: 'eb f9'
# second jump is to 0 (fall through)
+transform: instruction after transform: 'eb 00'

:(scenario label_too_short)
% Hide_errors = true;
== 0x1
          # instruction                     effective address                                                   operand     displacement    immediate
          # op          subop               mod             rm32          base        index         scale       r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
xz:
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
+error: 'xz' is two characters long which can look like raw hex bytes at a glance; use a different name

:(scenario label_hex)
% Hide_errors = true;
== 0x1
          # instruction                     effective address                                                   operand     displacement    immediate
          # op          subop               mod             rm32          base        index         scale       r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
0xab:
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
+error: '0xab' looks like a hex number; use a different name

:(scenario label_negative_hex)
% Hide_errors = true;
== 0x1
          # instruction                     effective address                                                   operand     displacement    immediate
          # op          subop               mod             rm32          base        index         scale       r32
          # 1-3 bytes   3 bits              2 bits          3 bits        3 bits      3 bits        2 bits      2 bits      0/1/2/4 bytes   0/1/2/4 bytes
 -a:  # indent to avoid looking like a trace_should_not_contain command for this scenario
            05                                                                                                                              0x0d0c0b0a/imm32  # add to EAX
+error: '-a' starts with '-', which can be confused with a negative number; use a different name

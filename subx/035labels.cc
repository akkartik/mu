//: Labels are defined by ending names with a ':'. This layer will compute
//: displacements for labels, and compute the offset for instructions using them.
//:
//: We won't check this, but our convention will be that jump targets will
//: start with a '$', while functions will not. Function names will never be
//: jumped to, and jump targets will never be called.

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
  map<string, int32_t> byte_index;  // values are unsigned, but we're going to do subtractions on them so they need to fit in 31 bits
  compute_byte_indices_for_labels(code, byte_index);
  if (trace_contains_errors()) return;
  drop_labels(code);
  if (trace_contains_errors()) return;
  replace_labels_with_displacements(code, byte_index);
}

void compute_byte_indices_for_labels(const segment& code, map<string, int32_t>& byte_index) {
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
      if (has_operand_metadata(curr, "disp32") || has_operand_metadata(curr, "imm32")) {
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
        if (Dump_map)
          cerr << "0x" << HEXWORD << (code.start + current_byte) << ' ' << label << '\n';
        put(byte_index, label, current_byte);
        trace(99, "transform") << "label '" << label << "' is at address " << (current_byte+code.start) << end();
        // no modifying current_byte; label definitions won't be in the final binary
      }
    }
  }
}

:(before "End Globals")
bool Dump_map = false;  // currently used only by 'subx translate'
:(before "End Commandline Options")
else if (is_equal(*arg, "--map")) {
  Dump_map = true;
}

:(code)
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

void replace_labels_with_displacements(segment& code, const map<string, int32_t>& byte_index) {
  int32_t byte_index_next_instruction_starts_at = 0;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    byte_index_next_instruction_starts_at += num_bytes(inst);
    line new_inst;
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (contains_key(byte_index, curr.data)) {
        int32_t displacement = static_cast<int32_t>(get(byte_index, curr.data)) - byte_index_next_instruction_starts_at;
        if (has_operand_metadata(curr, "disp8")) {
          if (displacement > 0xff || displacement < -0x7f)
            raise << "'" << to_string(inst) << "': label too far away for displacement " << std::hex << displacement << " to fit in 8 bits\n" << end();
          else
            emit_hex_bytes(new_inst, displacement, 1);
        }
        else if (has_operand_metadata(curr, "disp16")) {
          if (displacement > 0xffff || displacement < -0x7fff)
            raise << "'" << to_string(inst) << "': label too far away for displacement " << std::hex << displacement << " to fit in 16 bits\n" << end();
          else
            emit_hex_bytes(new_inst, displacement, 2);
        }
        else if (has_operand_metadata(curr, "disp32")) {
          emit_hex_bytes(new_inst, displacement, 4);
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
# address 0xa
 $loop3:
+transform: label 'loop' is at address 1
+transform: label '$loop2' is at address 1
+transform: label '$loop3' is at address a
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

//: now that we have labels, we need to adjust segment size computation to
//: ignore them.

:(scenario segment_size_ignores_labels)
== code  # 0x08048074
05/add 0x0d0c0b0a/imm32  # 5 bytes
foo:                     # 0 bytes
== data  # 0x08049079
bar:
00
+transform: segment 1 begins at address 0x08049079

:(before "End num_bytes(curr) Special-cases")
else if (is_label(curr))
  ;  // don't count it

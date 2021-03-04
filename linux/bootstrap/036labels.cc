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

//: One special label is 'Entry', the address to start running the program at.
//: It can be non-unique; the last declaration overrides earlier ones.
//: It must exist in a program. Otherwise we don't know where to start running
//: programs.

void test_Entry_label() {
  run(
      "== code 0x1\n"
      "05 0x0d0c0b0a/imm32\n"
      "Entry:\n"
      "05 0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "run: 0x00000006 opcode: 05\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN("run: 0x00000001 opcode: 05");
}

:(before "End looks_like_hex_int(s) Detectors")
if (SIZE(s) == 2) return true;

:(code)
void test_pack_immediate_ignores_single_byte_nondigit_argument() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "b9/copy  a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'b9/copy a/imm32'\n"
      // no change (we're just not printing metadata to the trace)
      "transform: instruction after packing: 'b9 a'\n"
  );
}

void test_pack_immediate_ignores_3_hex_digit_argument() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "b9/copy  aaa/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'b9/copy aaa/imm32'\n"
      // no change (we're just not printing metadata to the trace)
      "transform: instruction after packing: 'b9 aaa'\n"
  );
}

void test_pack_immediate_ignores_non_hex_argument() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "b9/copy xxx/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: packing instruction 'b9/copy xxx/imm32'\n"
      // no change (we're just not printing metadata to the trace)
      "transform: instruction after packing: 'b9 xxx'\n"
  );
}

//: a helper we'll find handy later
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
    raise << "'" << s << "' starts with a digit, and so can be confused with a number; use a different name.\n" << end();
  if (SIZE(s) == 2)
    raise << "'" << s << "' is two characters long, which can look like raw hex bytes at a glance; use a different name\n" << end();
}

//: Now that that's done, let's start using names as labels.

void test_map_label() {
  transform(
      "== code 0x1\n"
      "loop:\n"
      "  05  0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: label 'loop' is at address 1\n"
  );
}

:(before "End Transforms")
Transform.push_back(rewrite_labels);
:(code)
void rewrite_labels(program& p) {
  trace(3, "transform") << "-- rewrite labels" << end();
  if (p.segments.empty()) return;
  segment& code = *find(p, "code");
  map<string, int32_t> byte_index;  // values are unsigned, but we're going to do subtractions on them so they need to fit in 31 bits
  compute_byte_indices_for_labels(code, byte_index);
  if (trace_contains_errors()) return;
  drop_labels(code);
  if (trace_contains_errors()) return;
  replace_labels_with_displacements(code, byte_index);
  if (contains_key(byte_index, "Entry"))
    p.entry = code.start + get(byte_index, "Entry");
}

void compute_byte_indices_for_labels(const segment& code, map<string, int32_t>& byte_index) {
  int current_byte = 0;
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    const line& inst = code.lines.at(i);
    if (Source_lines_file.is_open() && !inst.original.empty() && /*not a label*/ *inst.words.at(0).data.rbegin() != ':')
      Source_lines_file << "0x" << HEXWORD << (code.start + current_byte) << ' ' << inst.original << '\n';
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      // hack: if we have any argument metadata left after previous transforms,
      // deduce its size
      // Maybe we should just move this transform to before instruction
      // packing, and deduce the size of *all* arguments. But then we'll also
      // have to deal with bitfields.
      if (has_argument_metadata(curr, "disp32") || has_argument_metadata(curr, "imm32")) {
        if (*curr.data.rbegin() == ':')
          raise << "'" << to_string(inst) << "': don't use ':' when jumping to labels\n" << end();
        current_byte += 4;
      }
      else if (has_argument_metadata(curr, "disp16")) {
        if (*curr.data.rbegin() == ':')
          raise << "'" << to_string(inst) << "': don't use ':' when jumping to labels\n" << end();
        current_byte += 2;
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
        if (contains_any_argument_metadata(curr))
          raise << "'" << to_string(inst) << "': label definition (':') not allowed in argument\n" << end();
        if (j > 0)
          raise << "'" << to_string(inst) << "': labels can only be the first word in a line.\n" << end();
        if (Labels_file.is_open())
          Labels_file << "0x" << HEXWORD << (code.start + current_byte) << ' ' << label << '\n';
        if (contains_key(byte_index, label) && label != "Entry") {
          raise << "duplicate label '" << label << "'\n" << end();
          return;
        }
        put(byte_index, label, current_byte);
        trace(99, "transform") << "label '" << label << "' is at address " << (current_byte+code.start) << end();
        // no modifying current_byte; label definitions won't be in the final binary
      }
    }
  }
}

:(before "End Globals")
bool Dump_debug_info = false;  // currently used only by 'bootstrap translate'
ofstream Labels_file;
ofstream Source_lines_file;
:(before "End Commandline Options")
else if (is_equal(*arg, "--debug")) {
  Dump_debug_info = true;
  // End --debug Settings
}
//: wait to open "labels" for writing until we're sure we aren't trying to read it
:(after "Begin bootstrap translate")
if (Dump_debug_info) {
  cerr << "saving address->label information to 'labels'\n";
  Labels_file.open("labels");
  cerr << "saving address->source information to 'source_lines'\n";
  Source_lines_file.open("source_lines");
}
:(before "End bootstrap translate")
if (Dump_debug_info) {
  Labels_file.close();
  Source_lines_file.close();
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
        int32_t absolute_address = code.start + get(byte_index, curr.data);
        if (has_argument_metadata(curr, "disp8")) {
          if (displacement > 0x7f || displacement < -0x7f)
            raise << "'" << to_string(inst) << "': label too far away for displacement " << std::hex << displacement << " to fit in 8 signed bits\n" << end();
          else
            emit_hex_bytes(new_inst, displacement, 1);
        }
        else if (has_argument_metadata(curr, "disp16")) {
          if (displacement > 0x7fff || displacement < -0x7fff)
            raise << "'" << to_string(inst) << "': label too far away for displacement " << std::hex << displacement << " to fit in 16 signed bits\n" << end();
          else
            emit_hex_bytes(new_inst, displacement, 2);
        }
        else if (has_argument_metadata(curr, "disp32")) {
          if (is_far_jump_or_call(new_inst))
            emit_hex_bytes(new_inst, displacement, 4);
          else
            emit_hex_bytes(new_inst, absolute_address, 4);
        } else if (has_argument_metadata(curr, "imm32")) {
          emit_hex_bytes(new_inst, absolute_address, 4);
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

bool is_far_jump_or_call(const line& inst) {
  string first_opcode = inst.words.at(0).data;
  if (first_opcode == "e8" || first_opcode == "e9") return true;
  if (SIZE(inst.words) < 2) return false;
  if (first_opcode != "0f") return false;
  string second_opcode = inst.words.at(1).data;
  return starts_with(second_opcode, "8");
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

void test_multiple_labels_at() {
  transform(
      "== code 0x1\n"
      // address 1
      "loop:\n"
      " $loop2:\n"
      // address 1 (labels take up no space)
      "    05  0x0d0c0b0a/imm32\n"
      // address 6
      "    eb  $loop2/disp8\n"
      // address 8
      "    eb  $loop3/disp8\n"
      // address 0xa
      " $loop3:\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: label 'loop' is at address 1\n"
      "transform: label '$loop2' is at address 1\n"
      "transform: label '$loop3' is at address a\n"
      // first jump is to -7
      "transform: instruction after transform: 'eb f9'\n"
      // second jump is to 0 (fall through)
      "transform: instruction after transform: 'eb 00'\n"
  );
}

void test_loading_label_as_imm32() {
  transform(
      "== code 0x1\n"
      "label:\n"
      "  be/copy-to-ESI  label/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: label 'label' is at address 1\n"
      "transform: instruction after transform: 'be 01 00 00 00'\n"
  );
}

void test_duplicate_label() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "loop:\n"
      "loop:\n"
      "    05  0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: duplicate label 'loop'\n"
  );
}

void test_label_too_short() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "xz:\n"
      "  05  0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: 'xz' is two characters long, which can look like raw hex bytes at a glance; use a different name\n"
  );
}

void test_label_hex() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "0xab:\n"
      "  05  0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '0xab' looks like a hex number; use a different name\n"
  );
}

void test_label_negative_hex() {
  Hide_errors = true;
  transform(
      "== code 0x1\n"
      "-a:\n"
      "    05  0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: '-a' starts with '-', which can be confused with a negative number; use a different name\n"
  );
}

//: As said up top, the 'Entry' label is special.
//: It can be non-unique; the last declaration overrides earlier ones.
//: It must exist in a program. Otherwise we don't know where to start running
//: programs.

void test_duplicate_Entry_label() {
  transform(
      "== code 0x1\n"
      "Entry:\n"
      "Entry:\n"
      "    05  0x0d0c0b0a/imm32\n"
  );
  CHECK_TRACE_DOESNT_CONTAIN_ERRORS();
}

// This test could do with some refactoring.
// We're duplicating the flow inside `bootstrap translate`, but without
// reading/writing files.
// We can't just use run(string) because most of our tests allow programs
// without 'Entry' labels, as a convenience.
void test_programs_without_Entry_label() {
  Hide_errors = true;
  program p;
  istringstream in(
      "== code 0x1\n"
      "05 0x0d0c0b0a/imm32\n"
      "05 0x0d0c0b0a/imm32\n"
  );
  parse(in, p);
  transform(p);
  ostringstream dummy;
  save_elf(p, dummy);
  CHECK_TRACE_CONTENTS(
      "error: no 'Entry' label found\n"
  );
}

//: now that we have labels, we need to adjust segment size computation to
//: ignore them.

void test_segment_size_ignores_labels() {
  transform(
      "== code 0x09000074\n"
      "  05/add  0x0d0c0b0a/imm32\n"  // 5 bytes
      "foo:\n"                        // 0 bytes
      "== data 0x0a000000\n"
      "bar:\n"
      "  00\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: segment 1 begins at address 0x0a000079\n"
  );
}

:(before "End size_of(word w) Special-cases")
else if (is_label(w))
  return 0;

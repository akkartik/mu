//: Global variables.
//:
//: Global variables are just labels in the data segment.
//: However, they can only be used in imm32 and not disp32 arguments. And they
//: can't be used with jump and call instructions.
//:
//: This layer has much the same structure as rewriting labels.

:(code)
void test_global_variable() {
  run(
      "== code 0x1\n"
      "b9  x/imm32\n"
      "== data 0x2000\n"
      "x:\n"
      "  00 00 00 00\n"
  );
  CHECK_TRACE_CONTENTS(
      "transform: global variable 'x' is at address 0x00002000\n"
  );
}

:(before "End Transforms")
Transform.push_back(rewrite_global_variables);
:(code)
void rewrite_global_variables(program& p) {
  trace(3, "transform") << "-- rewrite global variables" << end();
  // Begin rewrite_global_variables
  map<string, uint32_t> address;
  compute_addresses_for_global_variables(p, address);
  if (trace_contains_errors()) return;
  drop_global_variables(p);
  replace_global_variables_with_addresses(p, address);
}

void compute_addresses_for_global_variables(const program& p, map<string, uint32_t>& address) {
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    if (p.segments.at(i).name != "code")
      compute_addresses_for_global_variables(p.segments.at(i), address);
  }
}

void compute_addresses_for_global_variables(const segment& s, map<string, uint32_t>& address) {
  int current_address = s.start;
  for (int i = 0;  i < SIZE(s.lines);  ++i) {
    const line& inst = s.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (*curr.data.rbegin() != ':') {
        current_address += size_of(curr);
      }
      else {
        string variable = drop_last(curr.data);
        // ensure variables look sufficiently different from raw hex
        check_valid_name(variable);
        if (trace_contains_errors()) return;
        if (j > 0)
          raise << "'" << to_string(inst) << "': global variable names can only be the first word in a line.\n" << end();
        if (Labels_file.is_open())
          Labels_file << "0x" << HEXWORD << current_address << ' ' << variable << '\n';
        if (contains_key(address, variable)) {
          raise << "duplicate global '" << variable << "'\n" << end();
          return;
        }
        put(address, variable, current_address);
        trace(99, "transform") << "global variable '" << variable << "' is at address 0x" << HEXWORD << current_address << end();
        // no modifying current_address; global variable definitions won't be in the final binary
      }
    }
  }
}

void drop_global_variables(program& p) {
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    if (p.segments.at(i).name != "code")
      drop_labels(p.segments.at(i));
  }
}

void replace_global_variables_with_addresses(program& p, const map<string, uint32_t>& address) {
  if (p.segments.empty()) return;
  for (int i = 0;  i < SIZE(p.segments);  ++i) {
    segment& curr = p.segments.at(i);
    if (curr.name == "code")
      replace_global_variables_in_code_segment(curr, address);
    else
      replace_global_variables_in_data_segment(curr, address);
  }
}

void replace_global_variables_in_code_segment(segment& code, const map<string, uint32_t>& address) {
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    line new_inst;
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (!contains_key(address, curr.data)) {
        if (!looks_like_hex_int(curr.data))
          raise << "missing reference to global '" << curr.data << "'\n" << end();
        new_inst.words.push_back(curr);
        continue;
      }
      if (!valid_use_of_global_variable(curr)) {
        raise << "'" << to_string(inst) << "': can't refer to global variable '" << curr.data << "'\n" << end();
        return;
      }
      emit_hex_bytes(new_inst, get(address, curr.data), 4);
    }
    inst.words.swap(new_inst.words);
    trace(99, "transform") << "instruction after transform: '" << data_to_string(inst) << "'" << end();
  }
}

void replace_global_variables_in_data_segment(segment& data, const map<string, uint32_t>& address) {
  for (int i = 0;  i < SIZE(data.lines);  ++i) {
    line& l = data.lines.at(i);
    line new_l;
    for (int j = 0;  j < SIZE(l.words);  ++j) {
      const word& curr = l.words.at(j);
      if (!contains_key(address, curr.data)) {
        if (looks_like_hex_int(curr.data)) {
          if (has_argument_metadata(curr, "imm32"))
            emit_hex_bytes(new_l, curr, 4);
          else if (has_argument_metadata(curr, "imm16"))
            emit_hex_bytes(new_l, curr, 2);
          else if (has_argument_metadata(curr, "imm8"))
            emit_hex_bytes(new_l, curr, 1);
          else if (has_argument_metadata(curr, "disp8"))
            raise << "can't use /disp8 in a non-code segment\n" << end();
          else if (has_argument_metadata(curr, "disp16"))
            raise << "can't use /disp16 in a non-code segment\n" << end();
          else if (has_argument_metadata(curr, "disp32"))
            raise << "can't use /disp32 in a non-code segment\n" << end();
          else
            new_l.words.push_back(curr);
        }
        else {
          raise << "missing reference to global '" << curr.data << "'\n" << end();
          new_l.words.push_back(curr);
        }
        continue;
      }
      trace(99, "transform") << curr.data << " maps to " << HEXWORD << get(address, curr.data) << end();
      emit_hex_bytes(new_l, get(address, curr.data), 4);
    }
    l.words.swap(new_l.words);
    trace(99, "transform") << "after transform: '" << data_to_string(l) << "'" << end();
  }
}

bool valid_use_of_global_variable(const word& curr) {
  if (has_argument_metadata(curr, "imm32")) return true;
  // End Valid Uses Of Global Variable(curr)
  return false;
}

//:: a more complex sanity check for how we use global variables
//: requires first saving some data early before we pack arguments

:(after "Begin Transforms")
Transform.push_back(correlate_disp32_with_mod);
:(code)
void correlate_disp32_with_mod(program& p) {
  if (p.segments.empty()) return;
  segment& code = *find(p, "code");
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      word& curr = inst.words.at(j);
      if (has_argument_metadata(curr, "disp32")
          && has_argument_metadata(inst, "mod"))
        curr.metadata.push_back("has_mod");
    }
  }
}

:(before "End Valid Uses Of Global Variable(curr)")
if (has_argument_metadata(curr, "disp32"))
  return has_metadata(curr, "has_mod");
// todo: more sophisticated check, to ensure we don't use global variable
// addresses as a real displacement added to other arguments.

:(code)
bool has_metadata(const word& w, const string& m) {
  for (int i = 0;  i < SIZE(w.metadata);  ++i)
    if (w.metadata.at(i) == m) return true;
  return false;
}

void test_global_variable_disallowed_in_jump() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "eb/jump  x/disp8\n"
      "== data 0x2000\n"
      "x:\n"
      "  00 00 00 00\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: 'eb/jump x/disp8': can't refer to global variable 'x'\n"
      // sub-optimal error message; should be
//?       "error: can't jump to data (variable 'x')\n"
  );
}

void test_global_variable_disallowed_in_call() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "e8/call  x/disp32\n"
      "== data 0x2000\n"
      "x:\n"
      "  00 00 00 00\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: 'e8/call x/disp32': can't refer to global variable 'x'\n"
      // sub-optimal error message; should be
//?       "error: can't call to the data segment ('x')\n"
  );
}

void test_global_variable_in_data_segment() {
  run(
      "== code 0x1\n"
      "b9  x/imm32\n"
      "== data 0x2000\n"
      "x:\n"
      "  y/imm32\n"
      "y:\n"
      "  00 00 00 00\n"
  );
  // check that we loaded 'x' with the address of 'y'
  CHECK_TRACE_CONTENTS(
      "load: 0x00002000 -> 04\n"
      "load: 0x00002001 -> 20\n"
      "load: 0x00002002 -> 00\n"
      "load: 0x00002003 -> 00\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_raw_number_with_imm32_in_data_segment() {
  run(
      "== code 0x1\n"
      "b9  x/imm32\n"
      "== data 0x2000\n"
      "x:\n"
      "  1/imm32\n"
  );
  // check that we loaded 'x' with the address of 1
  CHECK_TRACE_CONTENTS(
      "load: 0x00002000 -> 01\n"
      "load: 0x00002001 -> 00\n"
      "load: 0x00002002 -> 00\n"
      "load: 0x00002003 -> 00\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_duplicate_global_variable() {
  Hide_errors = true;
  run(
      "== code 0x1\n"
      "40/increment-EAX\n"
      "== data 0x2000\n"
      "x:\n"
      "x:\n"
      "  00\n"
  );
  CHECK_TRACE_CONTENTS(
      "error: duplicate global 'x'\n"
  );
}

void test_global_variable_disp32_with_modrm() {
  run(
      "== code 0x1\n"
      "8b/copy 0/mod/indirect 5/rm32/.disp32 2/r32/EDX x/disp32\n"
      "== data 0x2000\n"
      "x:\n"
      "  00 00 00 00\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

void test_global_variable_disp32_with_call() {
  transform(
      "== code 0x1\n"
      "foo:\n"
      "  e8/call bar/disp32\n"
      "bar:\n"
  );
  CHECK_TRACE_COUNT("error", 0);
}

string to_full_string(const line& in) {
  ostringstream out;
  for (int i = 0;  i < SIZE(in.words);  ++i) {
    if (i > 0) out << ' ';
    out << in.words.at(i).data;
    for (int j = 0;  j < SIZE(in.words.at(i).metadata);  ++j)
      out << '/' << in.words.at(i).metadata.at(j);
  }
  return out.str();
}

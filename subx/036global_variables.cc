//: Global variables.
//:
//: Global variables are just labels in the data segment.
//: However, they can only be used in imm32 and not disp32 operands. And they
//: can't be used with jump and call instructions.
//:
//: This layer much the same structure as rewriting labels.

:(scenario global_variable)
% Mem_offset = CODE_START;
% Mem.resize(0x2000);
== code
b9/copy x/imm32  # copy to ECX
== data
x:
00 00 00 00
+transform: global variable 'x' is at address 0x08049079

:(before "End Level-2 Transforms")
Transform.push_back(rewrite_global_variables);
:(code)
void rewrite_global_variables(program& p) {
  trace(99, "transform") << "-- rewrite global variables" << end();
  map<string, uint32_t> address;
  compute_addresses_for_global_variables(p, address);
  if (trace_contains_errors()) return;
  drop_global_variables(p);
  replace_global_variables_with_addresses(p, address);
}

void compute_addresses_for_global_variables(const program& p, map<string, uint32_t>& address) {
  for (int i = /*skip code segment*/1;  i < SIZE(p.segments);  ++i)
    compute_addresses_for_global_variables(p.segments.at(i), address);
}

void compute_addresses_for_global_variables(const segment& s, map<string, uint32_t>& address) {
  int current_address = s.start;
  for (int i = 0;  i < SIZE(s.lines);  ++i) {
    const line& inst = s.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (*curr.data.rbegin() != ':') {
        ++current_address;
      }
      else {
        string variable = drop_last(curr.data);
        // ensure variables look sufficiently different from raw hex
        check_valid_name(variable);
        if (trace_contains_errors()) return;
        if (j > 0)
          raise << "'" << to_string(inst) << "': global variable names can only be the first word in a line.\n" << end();
        put(address, variable, current_address);
        trace(99, "transform") << "global variable '" << variable << "' is at address 0x" << HEXWORD << current_address << end();
        // no modifying current_address; global variable definitions won't be in the final binary
      }
    }
  }
}

void drop_global_variables(program& p) {
  for (int i = /*skip code segment*/1;  i < SIZE(p.segments);  ++i)
    drop_labels(p.segments.at(i));
}

void replace_global_variables_with_addresses(program& p, const map<string, uint32_t>& address) {
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    line new_inst;
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      const word& curr = inst.words.at(j);
      if (!contains_key(address, curr.data)) {
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

bool valid_use_of_global_variable(const word& curr) {
  if (has_operand_metadata(curr, "imm32")) return true;
  // End Valid Uses Of Global Variable(curr)
  return false;
}

//:: a more complex sanity check for how we use global variables
//: requires first saving some data early before we pack operands

:(after "Begin Level-2 Transforms")
Transform.push_back(correlate_disp32_with_mod);
:(code)
void correlate_disp32_with_mod(program& p) {
  if (p.segments.empty()) return;
  segment& code = p.segments.at(0);
  for (int i = 0;  i < SIZE(code.lines);  ++i) {
    line& inst = code.lines.at(i);
    for (int j = 0;  j < SIZE(inst.words);  ++j) {
      word& curr = inst.words.at(j);
      if (has_operand_metadata(curr, "disp32")
          && has_operand_metadata(inst, "mod"))
        curr.metadata.push_back("has_mod");
    }
  }
}

:(before "End Valid Uses Of Global Variable(curr)")
if (has_operand_metadata(curr, "disp32"))
  return has_metadata(curr, "has_mod");
// todo: more sophisticated check, to ensure we don't use global variable
// addresses as a real displacement added to other operands.

:(code)
bool has_metadata(const word& w, const string& m) {
  for (int i = 0;  i < SIZE(w.metadata);  ++i)
    if (w.metadata.at(i) == m) return true;
  return false;
}

:(scenario global_variable_disallowed_in_jump)
% Hide_errors = true;
== code
eb/jump x/disp8
== data
x:
00 00 00 00
+error: 'eb/jump x/disp8': can't refer to global variable 'x'
# sub-optimal error message; should be
#? +error: can't jump to data (variable 'x')

:(scenario global_variable_disallowed_in_call)
% Hide_errors = true;
== code
e8/call x/disp32
== data
x:
00 00 00 00
+error: 'e8/call x/disp32': can't refer to global variable 'x'
# sub-optimal error message; should be
#? +error: can't call to the data segment ('x')

:(scenario disp32_data_with_modrm)
% Mem_offset = CODE_START;
% Mem.resize(0x2000);
== code
8b/copy 0/mod/indirect 5/rm32/.disp32 2/r32/EDX x/disp32
==
x:
00 00 00 00
$error: 0

:(scenarios transform)
:(scenario disp32_data_with_call)
== code
foo:
e8/call bar/disp32
bar:
$error: 0

:(code)
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

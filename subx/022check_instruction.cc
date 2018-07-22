//: Catch instructions with the wrong size or type (metadata) of operands.

:(before "End Help Texts")
put(Help, "instructions",
  "Each x86 instruction consists of an instruction or opcode and some number of operands.\n"
  "Each operand has a type. An instruction won't have more than one of any type.\n"
  "Each instruction has some set of allowed operand types. It'll reject others.\n"
  "The complete list of operand types: mod, subop, r32 (register), rm32 (register or memory), scale, index, base, disp8, disp16, disp32, imm8, imm32.\n"
  "Each of these has its own help page. Try reading 'subx help mod' next.\n"
);
:(before "End Help Contents")
cerr << "  instructions\n";

//:: docs on each operand type

:(before "End Help Texts")
init_operand_type_help();
:(code)
void init_operand_type_help() {
  put(Help, "mod",
    "2-bit operand controlling the _addressing mode_ of many instructions,\n"
    "to determine how to compute the _effective address_ to look up memory at\n"
    "based on the 'rm32' operand and potentially others.\n"
    "\n"
    "If mod = 3, just operate on the contents of the register specified by rm32 (direct mode).\n"
    "If mod = 2, effective address is usually* rm32 + disp32 (indirect mode with displacement).\n"
    "If mod = 1, effective address is usually* rm32 + disp8 (indirect mode with displacement).\n"
    "If mod = 0, effective address is usually* rm32 (indirect mode).\n"
    "(* - The exception is when rm32 is '4'. Register 4 is the stack pointer (ESP). Using it as an address gets more involved.\n"
    "     For more details, try reading the help pages for 'base', 'index' and 'scale'.)\n"
    "\n"
    "For complete details consult the IA-32 software developer's manual, table 2-2,\n"
    "\"32-bit addressing forms with the ModR/M byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "subop",
    "Additional 3-bit operand for determining the instruction when the opcode is 81, 8f or ff.\n"
    "Can't coexist with operand of type 'r32' in a single instruction, because the two use the same bits.\n"
  );
  put(Help, "r32",
    "3-bit operand specifying a register operand used directly, without any further addressing modes.\n"
  );
  put(Help, "rm32",
    "3-bit operand specifying a register operand whose precise interpretation interacts with 'mod'.\n"
    "For complete details consult the IA-32 software developer's manual, table 2-2,\n"
    "\"32-bit addressing forms with the ModR/M byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "base",
    "Additional 3-bit operand (when 'rm32' is 4 unless 'mod' is 3) specifying the register containing an address to look up.\n"
    "This address may be further modified by 'index' and 'scale' operands.\n"
    "  effective address = base + index*scale + displacement (disp8 or disp32)\n"
    "For complete details consult the IA-32 software developer's manual, table 2-3,\n"
    "\"32-bit addressing forms with the SIB byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "index",
    "Optional 3-bit operand (when 'rm32' is 4 unless 'mod' is 3) that can be added to the 'base' operand to compute the 'effective address' at which to look up memory.\n"
    "  effective address = base + index*scale + displacement (disp8 or disp32)\n"
    "For complete details consult the IA-32 software developer's manual, table 2-3,\n"
    "\"32-bit addressing forms with the SIB byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "scale",
    "Optional 2-bit operand (when 'rm32' is 4 unless 'mod' is 3) that can be multiplied to the 'index' operand before adding the result to the 'base' operand to compute the _effective address_ to operate on.\n"
    "  effective address = base + index * scale + displacement (disp8 or disp32)\n"
    "For complete details consult the IA-32 software developer's manual, table 2-3,\n"
    "\"32-bit addressing forms with the SIB byte\".\n"
    "  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf\n"
  );
  put(Help, "disp8",
    "8-bit value to be added in many instructions.\n"
  );
  put(Help, "disp16",
    "16-bit value to be added in many instructions.\n"
  );
  put(Help, "disp32",
    "32-bit value to be added in many instructions.\n"
  );
  put(Help, "imm8",
    "8-bit value for many instructions.\n"
  );
  put(Help, "imm32",
    "32-bit value for many instructions.\n"
  );
}

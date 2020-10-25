//: Core data structures for simulating the SubX VM (subset of an x86 processor),
//: either in tests or debug aids.

//:: registers
//: assume segment registers are hard-coded to 0
//: no MMX, etc.

:(before "End Types")
enum {
  EAX,
  ECX,
  EDX,
  EBX,
  ESP,
  EBP,
  ESI,
  EDI,
  NUM_INT_REGISTERS,
};
union reg {
  int32_t i;
  uint32_t u;
};
:(before "End Globals")
reg Reg[NUM_INT_REGISTERS] = { {0} };
uint32_t EIP = 1;  // preserve null pointer
:(before "End Reset")
bzero(Reg, sizeof(Reg));
EIP = 1;  // preserve null pointer

:(before "End Types")
const int NUM_XMM_REGISTERS = 8;
float Xmm[NUM_XMM_REGISTERS] = { 0.0 };
const string Xname[NUM_XMM_REGISTERS] = { "XMM0", "XMM1", "XMM2", "XMM3", "XMM4", "XMM5", "XMM6", "XMM7" };
:(before "End Reset")
bzero(Xmm, sizeof(Xmm));

:(before "End Help Contents")
cerr << "  registers\n";
:(before "End Help Texts")
put_new(Help, "registers",
  "SubX supports 16 registers: eight 32-bit integer registers and eight single-precision\n"
  "floating-point registers. From 0 to 7, they are:\n"
  "  integer: EAX ECX EDX EBX ESP EBP ESI EDI\n"
  "  floating point: XMM0 XMM1 XMM2 XMM3 XMM4 XMM5 XMM6 XMM7\n"
  "ESP contains the top of the stack.\n"
  "\n"
  "-- 8-bit registers\n"
  "Some instructions operate on eight *overlapping* 8-bit registers.\n"
  "From 0 to 7, they are:\n"
  "  AL CL DL BL AH CH DH BH\n"
  "The 8-bit registers overlap with the 32-bit ones. AL is the lowest signicant byte\n"
  "of EAX, AH is the second lowest significant byte, and so on.\n"
  "\n"
  "For example, if EBX contains 0x11223344, then BL contains 0x44, and BH contains 0x33.\n"
  "\n"
  "There is no way to access bytes within ESP, EBP, ESI or EDI.\n"
  "\n"
  "For complete details consult the IA-32 software developer's manual, volume 2,\n"
  "table 2-2, \"32-bit addressing forms with the ModR/M byte\".\n"
  "It is included in this repository as 'modrm.pdf'.\n"
  "The register encodings are described in the top row of the table, but you'll need\n"
  "to spend some time with it.\n"
  "\n"
  "-- flag registers\n"
  "Various instructions (particularly 'compare') modify one or more of four 1-bit\n"
  "'flag' registers, as a side-effect:\n"
  "- the sign flag (SF): usually set if an arithmetic result is negative, or\n"
  "  reset if not.\n"
  "- the zero flag (ZF): usually set if a result is zero, or reset if not.\n"
  "- the carry flag (CF): usually set if an arithmetic result overflows by just one bit.\n"
  "  Useful for operating on unsigned numbers.\n"
  "- the overflow flag (OF): usually set if an arithmetic result overflows by more\n"
  "  than one bit. Useful for operating on signed numbers.\n"
  "The flag bits are read by conditional jumps.\n"
  "\n"
  "For complete details on how different instructions update the flags, consult the IA-32\n"
  "manual (volume 2). There's various versions of it online, such as https://c9x.me/x86,\n"
  "though of course you'll need to be careful to ignore instructions and flag registers\n"
  "that SubX doesn't support.\n"
  "\n"
  "It isn't simple, but if this is the processor you have running on your computer,\n"
  "might as well get good at it.\n"
);

:(before "End Globals")
// the subset of x86 flag registers we care about
bool SF = false;  // sign flag
bool ZF = false;  // zero flag
bool CF = false;  // carry flag
bool OF = false;  // overflow flag
:(before "End Reset")
SF = ZF = CF = OF = false;

//:: simulated RAM

:(before "End Types")
const uint32_t SEGMENT_ALIGNMENT = 0x1000000;  // 16MB
inline uint32_t align_upwards(uint32_t x, uint32_t align) {
  return (x+align-1) & -(align);
}

// Like in real-world Linux, we'll allocate RAM for our programs in disjoint
// slabs called VMAs or Virtual Memory Areas.
struct vma {
  uint32_t start;  // inclusive
  uint32_t end;  // exclusive
  vector<uint8_t> _data;
  vma(uint32_t s, uint32_t e) :start(s), end(e) {}
  vma(uint32_t s) :start(s), end(align_upwards(s+1, SEGMENT_ALIGNMENT)) {}
  bool match(uint32_t a) {
    return a >= start && a < end;
  }
  bool match32(uint32_t a) {
    return a >= start && a+4 <= end;
  }
  uint8_t& data(uint32_t a) {
    assert(match(a));
    uint32_t result_index = a-start;
    if (_data.size() <= result_index+/*largest word size that can be accessed in one instruction*/sizeof(int)) {
      const int align = 0x1000;
      uint32_t result_size = result_index + 1;  // size needed for result_index to be valid
      uint32_t new_size = align_upwards(result_size, align);
      // grow at least 2x to maintain some amortized complexity guarantees
      if (new_size < _data.size() * 2)
        new_size = _data.size() * 2;
      // never grow past the stated limit
      if (new_size > end-start)
        new_size = end-start;
      _data.resize(new_size);
    }
    return _data.at(result_index);
  }
  void grow_until(uint32_t new_end_address) {
    if (new_end_address < end) return;
    // Ugly: vma knows about the global Memory list of vmas
    void sanity_check(uint32_t start, uint32_t end);
    sanity_check(start, new_end_address);
    end = new_end_address;
  }
  // End vma Methods
};
:(code)
void sanity_check(uint32_t start, uint32_t end) {
  bool dup_found = false;
  for (int i = 0;  i < SIZE(Mem);  ++i) {
    const vma& curr = Mem.at(i);
    if (curr.start == start) {
      assert(!dup_found);
      dup_found = true;
    }
    else if (curr.start > start) {
      assert(curr.start > end);
    }
    else if (curr.start < start) {
      assert(curr.end < start);
    }
  }
}

:(before "End Globals")
// RAM is made of VMAs.
vector<vma> Mem;
:(code)
:(before "End Globals")
uint32_t End_of_program = 0;  // when the program executes past this address in tests we'll stop the test
// The stack grows downward. Can't increase its size for now.
:(before "End Reset")
Mem.clear();
End_of_program = 0;
:(code)
// These helpers depend on Mem being laid out contiguously (so you can't use a
// map, etc.) and on the host also being little-endian.
inline uint8_t read_mem_u8(uint32_t addr) {
  uint8_t* handle = mem_addr_u8(addr);  // error messages get printed here
  return handle ? *handle : 0;
}
inline int8_t read_mem_i8(uint32_t addr) {
  return static_cast<int8_t>(read_mem_u8(addr));
}
inline uint32_t read_mem_u32(uint32_t addr) {
  uint32_t* handle = mem_addr_u32(addr);  // error messages get printed here
  return handle ? *handle : 0;
}
inline int32_t read_mem_i32(uint32_t addr) {
  return static_cast<int32_t>(read_mem_u32(addr));
}
inline float read_mem_f32(uint32_t addr) {
  return static_cast<float>(read_mem_u32(addr));
}

inline uint8_t* mem_addr_u8(uint32_t addr) {
  uint8_t* result = NULL;
  for (int i = 0;  i < SIZE(Mem);  ++i) {
    if (Mem.at(i).match(addr)) {
      if (result)
        raise << "address 0x" << HEXWORD << addr << " is in two segments\n" << end();
      result = &Mem.at(i).data(addr);
    }
  }
  if (result == NULL) {
    if (Trace_file.is_open()) Trace_file.flush();
    raise << "Tried to access uninitialized memory at address 0x" << HEXWORD << addr << '\n' << end();
    exit(1);
  }
  return result;
}
inline int8_t* mem_addr_i8(uint32_t addr) {
  return reinterpret_cast<int8_t*>(mem_addr_u8(addr));
}
inline uint32_t* mem_addr_u32(uint32_t addr) {
  uint32_t* result = NULL;
  for (int i = 0;  i < SIZE(Mem);  ++i) {
    if (Mem.at(i).match32(addr)) {
      if (result)
        raise << "address 0x" << HEXWORD << addr << " is in two segments\n" << end();
      result = reinterpret_cast<uint32_t*>(&Mem.at(i).data(addr));
    }
  }
  if (result == NULL) {
    if (Trace_file.is_open()) Trace_file.flush();
    raise << "Tried to access uninitialized memory at address 0x" << HEXWORD << addr << '\n' << end();
    exit(1);
  }
  return result;
}
inline int32_t* mem_addr_i32(uint32_t addr) {
  return reinterpret_cast<int32_t*>(mem_addr_u32(addr));
}
inline float* mem_addr_f32(uint32_t addr) {
  return reinterpret_cast<float*>(mem_addr_u32(addr));
}
// helper for some syscalls. But read-only.
inline const char* mem_addr_kernel_string(uint32_t addr) {
  return reinterpret_cast<const char*>(mem_addr_u8(addr));
}
inline string mem_addr_string(uint32_t addr, uint32_t size) {
  ostringstream out;
  for (size_t i = 0;  i < size;  ++i)
    out << read_mem_u8(addr+i);
  return out.str();
}

inline void write_mem_u8(uint32_t addr, uint8_t val) {
  uint8_t* handle = mem_addr_u8(addr);
  if (handle != NULL) *handle = val;
}
inline void write_mem_i8(uint32_t addr, int8_t val) {
  int8_t* handle = mem_addr_i8(addr);
  if (handle != NULL) *handle = val;
}
inline void write_mem_u32(uint32_t addr, uint32_t val) {
  uint32_t* handle = mem_addr_u32(addr);
  if (handle != NULL) *handle = val;
}
inline void write_mem_i32(uint32_t addr, int32_t val) {
  int32_t* handle = mem_addr_i32(addr);
  if (handle != NULL) *handle = val;
}

inline bool already_allocated(uint32_t addr) {
  bool result = false;
  for (int i = 0;  i < SIZE(Mem);  ++i) {
    if (Mem.at(i).match(addr)) {
      if (result)
        raise << "address 0x" << HEXWORD << addr << " is in two segments\n" << end();
      result = true;
    }
  }
  return result;
}

//:: core interpreter loop

:(code)
// skeleton of how x86 instructions are decoded
void run_one_instruction() {
  uint8_t op=0, op2=0, op3=0;
  // Run One Instruction
  if (Trace_file.is_open()) {
    dump_registers();
    // End Dump Info for Instruction
  }
  uint32_t inst_start_address = EIP;
  op = next();
  trace(Callstack_depth+1, "run") << "0x" << HEXWORD << inst_start_address << " opcode: " << HEXBYTE << NUM(op) << end();
  switch (op) {
  case 0xf4:  // hlt
    EIP = End_of_program;
    break;
  // End Single-Byte Opcodes
  case 0x0f:
    switch(op2 = next()) {
    // End Two-Byte Opcodes Starting With 0f
    default:
      cerr << "unrecognized second opcode after 0f: " << HEXBYTE << NUM(op2) << '\n';
      exit(1);
    }
    break;
  case 0xf2:
    switch(op2 = next()) {
    // End Two-Byte Opcodes Starting With f2
    case 0x0f:
      switch(op3 = next()) {
      // End Three-Byte Opcodes Starting With f2 0f
      default:
        cerr << "unrecognized third opcode after f2 0f: " << HEXBYTE << NUM(op3) << '\n';
        exit(1);
      }
      break;
    default:
      cerr << "unrecognized second opcode after f2: " << HEXBYTE << NUM(op2) << '\n';
      exit(1);
    }
    break;
  case 0xf3:
    switch(op2 = next()) {
    // End Two-Byte Opcodes Starting With f3
    case 0x0f:
      switch(op3 = next()) {
      // End Three-Byte Opcodes Starting With f3 0f
      default:
        cerr << "unrecognized third opcode after f3 0f: " << HEXBYTE << NUM(op3) << '\n';
        exit(1);
      }
      break;
    default:
      cerr << "unrecognized second opcode after f3: " << HEXBYTE << NUM(op2) << '\n';
      exit(1);
    }
    break;
  default:
    cerr << "unrecognized opcode: " << HEXBYTE << NUM(op) << '\n';
    exit(1);
  }
}

inline uint8_t next() {
  return read_mem_u8(EIP++);
}

void dump_registers() {
  ostringstream out;
  out << "regs: ";
  for (int i = 0;  i < NUM_INT_REGISTERS;  ++i) {
    if (i > 0) out << "  ";
    out << i << ": " << std::hex << std::setw(8) << std::setfill('_') << Reg[i].u;
  }
  out << " -- SF: " << SF << "; ZF: " << ZF << "; CF: " << CF << "; OF: " << OF;
  trace(Callstack_depth+1, "run") << out.str() << end();
}

//: start tracking supported opcodes
:(before "End Globals")
map</*op*/string, string> Name;
map</*op*/string, string> Name_0f;
map</*op*/string, string> Name_f3;
map</*op*/string, string> Name_f3_0f;
:(before "End One-time Setup")
init_op_names();
:(code)
void init_op_names() {
  put(Name, "f4", "halt (hlt)");
  // End Initialize Op Names
}

:(before "End Help Special-cases(key)")
if (key == "opcodes") {
  cerr << "Opcodes currently supported by SubX:\n";
  for (map<string, string>::iterator p = Name.begin();  p != Name.end();  ++p)
    cerr << "  " << p->first << ": " << p->second << '\n';
  for (map<string, string>::iterator p = Name_0f.begin();  p != Name_0f.end();  ++p)
    cerr << "  0f " << p->first << ": " << p->second << '\n';
  for (map<string, string>::iterator p = Name_f3.begin();  p != Name_f3.end();  ++p)
    cerr << "  f3 " << p->first << ": " << p->second << '\n';
  for (map<string, string>::iterator p = Name_f3_0f.begin();  p != Name_f3_0f.end();  ++p)
    cerr << "  f3 0f " << p->first << ": " << p->second << '\n';
  cerr << "Run `bootstrap help instructions` for details on words like 'r32' and 'disp8'.\n"
          "For complete details on these instructions, consult the IA-32 manual (volume 2).\n"
          "There's various versions of it online, such as https://c9x.me/x86.\n"
          "The mnemonics in brackets will help you locate each instruction.\n";
  return 0;
}
:(before "End Help Contents")
cerr << "  opcodes\n";

//: Helpers for managing trace depths
//:
//: We're going to use trace depths primarily to segment code running at
//: different frames of the call stack. This will make it easy for the trace
//: browser to collapse over entire calls.
//:
//: Errors will be at depth 0.
//: Warnings will be at depth 1.
//: SubX instructions will occupy depth 2 and up to Max_depth, organized by
//: stack frames. Each instruction's internal details will be one level deeper
//: than its 'main' depth. So 'call' instruction details will be at the same
//: depth as the instructions of the function it calls.
:(before "End Globals")
extern const int Initial_callstack_depth = 2;
int Callstack_depth = Initial_callstack_depth;
:(before "End Reset")
Callstack_depth = Initial_callstack_depth;

:(before "End Includes")
#include <iomanip>
#define HEXBYTE  std::hex << std::setw(2) << std::setfill('0')
#define HEXWORD  std::hex << std::setw(8) << std::setfill('0')
// ugly that iostream doesn't print uint8_t as an integer
#define NUM(X) static_cast<int>(X)
#include <stdint.h>

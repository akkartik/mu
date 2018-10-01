//: Core data structures for simulating the SubX VM (subset of an x86 processor)
//:
//: At the lowest level ("level 1") of abstraction, SubX executes x86
//: instructions provided in the form of an array of bytes, loaded into memory
//: starting at a specific address.

//:: registers
//: assume segment registers are hard-coded to 0
//: no floating-point, MMX, etc. yet

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

:(before "End Help Contents")
cerr << "  registers\n";
:(before "End Help Texts")
put(Help, "registers",
  "SubX currently supports eight 32-bit integer registers: R0 to R7.\n"
  "R4 (ESP) contains the top of the stack.\n"
  "\n"
  "There's also a register for the address of the currently executing\n"
  "instruction. It is modified by jumps.\n"
  "\n"
  "Various instructions modify one or more of three 1-bit 'flag' registers,\n"
  "as a side-effect:\n"
  "- the sign flag (SF): usually set if an arithmetic result is negative, or\n"
  "  reset if not.\n"
  "- the zero flag (ZF): usually set if a result is zero, or reset if not.\n"
  "- the overflow flag (OF): usually set if an arithmetic result overflows.\n"
  "The flag bits are read by conditional jumps.\n"
  "\n"
  "We don't support non-integer (floating-point) registers yet.\n"
);

:(before "End Globals")
// the subset of x86 flag registers we care about
bool SF = false;  // sign flag
bool ZF = false;  // zero flag
bool OF = false;  // overflow flag
:(before "End Reset")
SF = ZF = OF = false;

//: how the flag registers are updated after each instruction

:(before "End Includes")
// Combine 'arg1' and 'arg2' with arithmetic operation 'op' and store the
// result in 'arg1', then update flags.
// beware: no side-effects in args
#define BINARY_ARITHMETIC_OP(op, arg1, arg2) { \
  /* arg1 and arg2 must be signed */ \
  int64_t tmp = arg1 op arg2; \
  arg1 = arg1 op arg2; \
  trace(90, "run") << "storing 0x" << HEXWORD << arg1 << end(); \
  SF = (arg1 < 0); \
  ZF = (arg1 == 0); \
  OF = (arg1 != tmp); \
}

// Combine 'arg1' and 'arg2' with bitwise operation 'op' and store the result
// in 'arg1', then update flags.
#define BINARY_BITWISE_OP(op, arg1, arg2) { \
  /* arg1 and arg2 must be unsigned */ \
  arg1 = arg1 op arg2; \
  trace(90, "run") << "storing 0x" << HEXWORD << arg1 << end(); \
  SF = (arg1 >> 31); \
  ZF = (arg1 == 0); \
  OF = false; \
}

//:: simulated RAM

:(before "End Types")
const uint32_t INITIAL_SEGMENT_SIZE = 0x1000 - 1;
// Subtract one just so we can start the first segment at address 1 without
// overflowing the first segment. Other segments will learn to adjust.

// Like in real-world Linux, we'll allocate RAM for our programs in disjoint
// slabs called VMAs or Virtual Memory Areas.
struct vma {
  uint32_t start;  // inclusive
  uint32_t end;  // exclusive
  vector<uint8_t> _data;
  vma(uint32_t s, uint32_t e) :start(s), end(e) {
    _data.resize(end-start);
  }
  vma(uint32_t s) :start(s), end(s+INITIAL_SEGMENT_SIZE) {
    _data.resize(end-start);
  }
  bool match(uint32_t a) {
    return a >= start && a < end;
  }
  bool match32(uint32_t a) {
    return a >= start && a+4 <= end;
  }
  uint8_t& data(uint32_t a) {
    assert(match(a));
    return _data.at(a-start);
  }
  void grow_until(uint32_t new_end_address) {
    if (new_end_address < end) return;
    end = new_end_address;
    _data.resize(new_end_address - start);
  }
  // End vma Methods
};

:(before "End Globals")
// RAM is made of VMAs.
//
// We currently have zero tests for overlapping VMAs. Particularly after
// growing segments.
vector<vma> Mem;
:(code)
// The first 3 VMAs are special. When loading ELF binaries in later layers,
// we'll assume that the first VMA is for code, the second is for data
// (including the heap), and the third for the stack.
void grow_code_segment(uint32_t new_end_address) {
  assert(!Mem.empty());
  Mem.at(0).grow_until(new_end_address);
}
void grow_data_segment(uint32_t new_end_address) {
  assert(SIZE(Mem) > 1);
  Mem.at(1).grow_until(new_end_address);
}
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

inline uint8_t* mem_addr_u8(uint32_t addr) {
  uint8_t* result = NULL;
  for (int i = 0;  i < SIZE(Mem);  ++i) {
    if (Mem.at(i).match(addr)) {
      if (result)
        raise << "address 0x" << HEXWORD << addr << " is in two segments\n" << end();
      result = &Mem.at(i).data(addr);
    }
  }
  if (result == NULL)
    raise << "Tried to access uninitialized memory at address 0x" << HEXWORD << addr << '\n' << end();
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
    raise << "Tried to access uninitialized memory at address 0x" << HEXWORD << addr << '\n' << end();
    raise << "The entire 4-byte word should be initialized and lie in a single segment.\n" << end();
  }
  return result;
}
inline int32_t* mem_addr_i32(uint32_t addr) {
  return reinterpret_cast<int32_t*>(mem_addr_u32(addr));
}
// helper for some syscalls. But read-only.
inline const char* mem_addr_string(uint32_t addr) {
  return reinterpret_cast<const char*>(mem_addr_u8(addr));
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
  trace(90, "run") << "inst: 0x" << HEXWORD << EIP << end();
//?   dump_registers();
//?   cerr << "inst: 0x" << EIP << " => ";
  op = next();
//?   cerr << HEXBYTE << NUM(op) << '\n';
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
      DUMP("");
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
        DUMP("");
        exit(1);
      }
      break;
    default:
      cerr << "unrecognized second opcode after f2: " << HEXBYTE << NUM(op2) << '\n';
      DUMP("");
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
        DUMP("");
        exit(1);
      }
      break;
    default:
      cerr << "unrecognized second opcode after f3: " << HEXBYTE << NUM(op2) << '\n';
      DUMP("");
      exit(1);
    }
    break;
  default:
    cerr << "unrecognized opcode: " << HEXBYTE << NUM(op) << '\n';
    DUMP("");
    exit(1);
  }
}

inline uint8_t next() {
  return read_mem_u8(EIP++);
}

void dump_registers() {
  for (int i = 0;  i < NUM_INT_REGISTERS;  ++i) {
    if (i > 0) cerr << "; ";
    cerr << "  " << i << ": " << std::hex << std::setw(8) << std::setfill('_') << Reg[i].u;
  }
  cerr << " -- SF: " << SF << "; ZF: " << ZF << "; OF: " << OF << '\n';
}

//: start tracking supported opcodes
:(before "End Globals")
map</*op*/string, string> name;
map</*op*/string, string> name_0f;
map</*op*/string, string> name_f3;
map</*op*/string, string> name_f3_0f;
:(before "End One-time Setup")
init_op_names();
:(code)
void init_op_names() {
  put(name, "f4", "halt");
  // End Initialize Op Names(name)
}

:(before "End Help Special-cases(key)")
if (key == "opcodes") {
  cerr << "Opcodes currently supported by SubX:\n";
  for (map<string, string>::iterator p = name.begin();  p != name.end();  ++p)
    cerr << "  " << p->first << ": " << p->second << '\n';
  for (map<string, string>::iterator p = name_0f.begin();  p != name_0f.end();  ++p)
    cerr << "  0f " << p->first << ": " << p->second << '\n';
  for (map<string, string>::iterator p = name_f3.begin();  p != name_f3.end();  ++p)
    cerr << "  f3 " << p->first << ": " << p->second << '\n';
  for (map<string, string>::iterator p = name_f3_0f.begin();  p != name_f3_0f.end();  ++p)
    cerr << "  f3 0f " << p->first << ": " << p->second << '\n';
  cerr << "Run `subx help instructions` for details on words like 'r32' and 'disp8'.\n";
  return 0;
}
:(before "End Help Contents")
cerr << "  opcodes\n";

:(before "End Includes")
#include <iomanip>
#define HEXBYTE  std::hex << std::setw(2) << std::setfill('0')
#define HEXWORD  std::hex << std::setw(8) << std::setfill('0')
// ugly that iostream doesn't print uint8_t as an integer
#define NUM(X) static_cast<int>(X)
#include <stdint.h>

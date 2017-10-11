//:: simulated x86 registers

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
reg R[NUM_INT_REGISTERS] = { {0} };
uint32_t EIP = 0;
:(before "End Reset")
bzero(R, sizeof(R));
EIP = 0;

//:: simulated flag registers; just a subset that we care about

:(before "End Globals")
bool OF=false, ZF=false, SF=false;
:(before "End Reset")
OF = ZF = SF = false;

//: how the flag registers are updated after each instruction

:(before "End Includes")
// beware: no side-effects in args
#define BINARY_ARITHMETIC_OP(op, arg1, arg2) { \
  /* arg1 and arg2 must be signed */ \
  int64_t tmp = arg1 op arg2; \
  arg1 = arg1 op arg2; \
  SF = (arg1 < 0); \
  ZF = (arg1 == 0); \
  OF = (arg1 != tmp); \
}

#define BINARY_BITWISE_OP(op, arg1, arg2) { \
  /* arg1 and arg2 must be unsigned */ \
  arg1 = arg1 op arg2; \
  SF = (arg1 >> 31); \
  ZF = (arg1 == 0); \
  OF = false; \
}

//:: simulated RAM

:(before "End Globals")
vector<uint8_t> Memory;
:(before "End Reset")
Memory.clear();

//:: core interpreter loop

:(scenario add_imm32_to_eax)
# op  ModRM   SIB   displacement  immediate
  05                              0a 0b 0c 0d  # add 0x0d0c0b0a to EAX
+load: 05
+load: 0a
+load: 0b
+load: 0c
+load: 0d
+run: add to EAX immediate 0x0d0c0b0a
+reg: storing 0x0d0c0b0a in register EAX

:(code)
// helper for tests: load a program into memory from a textual representation
// of its bytes, and run it
void run(const string& text_bytes) {
  load_program(text_bytes);
  EIP = 1;  // preserve null pointer
  while (EIP < Memory.size())
    run_one_instruction();
}

void load_program(const string& text_bytes) {
  assert(Memory.empty());
  // initialize address 0
  Memory.push_back(0);
  // now, to read the hex bytes in ASCII, we'll use C's strtol
  // strtol needs a char*, so we grab the buffer backing the string object
  char* curr = const_cast<char*>(&text_bytes[0]);   // non-standard approach, but blessed by Herb Sutter (http://herbsutter.com/2008/04/07/cringe-not-vectors-are-guaranteed-to-be-contiguous/#comment-483)
  char* max = curr + strlen(curr);
  while (true) {
    if (curr >= max) return;
    // skip whitespace
    while (*curr == ' ' || *curr == '\n') ++curr;
    // skip comments
    if (*curr == '#') {
      while (*curr != '\n') {
        ++curr;
        if (curr >= max) return;
      }
      ++curr;
      if (curr >= max) return;
    }
    Memory.push_back(strtol(curr, &curr, /*hex*/16));
    trace(99, "load") << HEXBYTE << static_cast<unsigned int>(Memory.back()) << end();  // ugly that iostream doesn't print uint8_t as an integer
  }
}

// skeleton of how x86 instructions are decoded
void run_one_instruction() {
  uint8_t op=0, op2=0, op3=0;
  switch(op = next()) {
  // our first opcode
  case 0x05: {  // add EAX, imm32
    int32_t arg2 = imm32();
    trace(2, "run") << "add to EAX immediate 0x" << HEXWORD << arg2 << end();
    BINARY_ARITHMETIC_OP(+, R[EAX].i, arg2);
    trace(98, "reg") << "storing 0x" << HEXWORD << R[EAX].i << " in register EAX" << end();
    break;
  }
  // End Single-Byte Opcodes
  case 0x0f:
    switch(op2 = next()) {
    // End Two-Byte Opcodes Starting With 0f
    default:
      cerr << "unrecognized second opcode after 0f: " << std::hex << static_cast<int>(op2) << '\n';
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
        cerr << "unrecognized third opcode after f3 0f: " << std::hex << static_cast<int>(op3) << '\n';
        exit(1);
      }
      break;
    default:
      cerr << "unrecognized second opcode after f3: " << std::hex << static_cast<int>(op2) << '\n';
      exit(1);
    }
    break;
  case 0xf4:  // hlt
    EIP = Memory.size();
    break;
  default:
    cerr << "unrecognized opcode: " << std::hex << static_cast<int>(op) << '\n';
    exit(1);
  }
}

uint8_t next(void) {
  if (EIP >= Memory.size()) return /*hlt*/0xf4;
  return Memory.at(EIP++);
}

// read a 32-bit immediate in little-endian order from the instruction stream
int32_t imm32(void) {
  int result = next();
  result |= (next()<<8);
  result |= (next()<<16);
  result |= (next()<<24);
  return result;
}

:(before "End Includes")
#include <iomanip>
#define HEXBYTE  std::hex << std::setw(2) << std::setfill('0')
#define HEXWORD  std::hex << std::setw(8) << std::setfill('0')

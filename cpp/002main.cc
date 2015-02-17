enum recipe_number {
  // arithmetic
  add = 1,
  subtract,
  multiply,
  divide,
  divide_with_remainder,

  // boolean
  conjunction,  // 'and' is a keyword
  disjunction,  // 'or' is a keyword
  negation,  // 'not' is a keyword

  // comparison
  equal,
  not_equal,
  less_than,
  greater_than,
  lesser_or_equal,
  greater_or_equal,

  // control flow
  jump,
  jump_if,
  jump_unless,

  // data management: scalars, arrays, and_records (structs)
  copy,
  get,
  get_address,
  index,
  index_address,
  allocate,
  size,
  length,

  // tagged_values require one primitive
  save_type,

  // code points for characters
  character_to_integer,
  integer_to_character,

  // multiprocessing
  fork,
  fork_helper,
  sleep,
  assert,
  assert_false,

  // cursor-based (text mode) interaction
  cursor_mode,
  retro_mode,
  clear_host_screen,
  clear_line_on_host,
  cursor_on_host,
  cursor_on_host_to_next_line,
  cursor_up_on_host,
  cursor_down_on_host,
  cursor_right_on_host,
  cursor_left_on_host,
  print_character_to_host,
  read_key_from_host,

  // debugging aides
  _dump_memory,
  _dump_trace,
  _start_tracing,
  _stop_tracing,
  _dump_routine,
  _dump_channel,
  _quit,
  _wait_for_key_from_host,
  _print,

  // first-class continuations
  current_continuation,
  continue_from,

  // user-defined functions
  next_input,
  input,
  prepare_reply,
  reply,

  Max_primitive_recipe,
};

struct property {
  vector<string> values;
};

typedef int type_number;

struct type_info {
  int size;
  bool is_address;
  bool is_record;
  bool is_array;
  vector<type_number> target;  // only if is_address
  vector<vector<type_number> > elements;  // only if is_record or is_array
};

unordered_map<type_number, type_info> type;

struct reagent {
  string name;
  vector<type_number> types;
  vector<pair<string, property> > properties;
};

struct instruction {
  recipe_number op;
  vector<reagent> ingredients;
  vector<reagent> products;
};

void load(const char* filename) {
}

void run(const char* function_name) {
}



//// test harness

void run_tests() {
  for (unsigned long i=0; i < sizeof(Tests)/sizeof(Tests[0]); ++i) {
    START_TRACING_UNTIL_END_OF_SCOPE;
    setup();
    CLEAR_TRACE;
    (*Tests[i])();
    verify();
  }
  cerr << '\n';
  if (Num_failures > 0)
    cerr << Num_failures << " failure"
         << (Num_failures > 1 ? "s" : "")
         << '\n';
}

void verify() {
  if (!Passed)
    ;
  else
    cerr << ".";
}

void setup() {
  Passed = true;
}

string time_string() {
  time_t t;
  time(&t);
  char buffer[10];
  if (!strftime(buffer, 10, "%H:%M:%S", localtime(&t)))
    return "";
  return buffer;
}

}  // end namespace mu

int main(int argc, const char* argv[]) {
  if (argc == 2 && string(argv[1]) == "test") {
    mu::run_tests();
    return 0;
  }

  for (int i = 1; i < argc; ++i) {
    mu::load(argv[i]);
  }
  mu::run("main");
}

namespace mu {

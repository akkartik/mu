//? enum recipe_number {
//?   // arithmetic
//?   add = 1,
//?   subtract,
//?   multiply,
//?   divide,
//?   divide_with_remainder,
//? 
//?   // boolean
//?   conjunction,  // 'and' is a keyword
//?   disjunction,  // 'or' is a keyword
//?   negation,  // 'not' is a keyword
//? 
//?   // comparison
//?   equal,
//?   not_equal,
//?   less_than,
//?   greater_than,
//?   lesser_or_equal,
//?   greater_or_equal,
//? 
//?   // control flow
//?   jump,
//?   jump_if,
//?   jump_unless,
//? 
//?   // data management: scalars, arrays, and_records (structs)
//?   copy,
//?   get,
//?   get_address,
//?   index,
//?   index_address,
//?   allocate,
//?   size,
//?   length,
//? 
//?   // tagged_values require one primitive
//?   save_type,
//? 
//?   // code points for characters
//?   character_to_integer,
//?   integer_to_character,
//? 
//?   // multiprocessing
//?   fork,
//?   fork_helper,
//?   sleep,
//?   assert,
//?   assert_false,
//? 
//?   // cursor-based (text mode) interaction
//?   cursor_mode,
//?   retro_mode,
//?   clear_host_screen,
//?   clear_line_on_host,
//?   cursor_on_host,
//?   cursor_on_host_to_next_line,
//?   cursor_up_on_host,
//?   cursor_down_on_host,
//?   cursor_right_on_host,
//?   cursor_left_on_host,
//?   print_character_to_host,
//?   read_key_from_host,
//? 
//?   // debugging aides
//?   _dump_memory,
//?   _dump_trace,
//?   _start_tracing,
//?   _stop_tracing,
//?   _dump_routine,
//?   _dump_channel,
//?   _quit,
//?   _wait_for_key_from_host,
//?   _print,
//? 
//?   // first-class continuations
//?   current_continuation,
//?   continue_from,
//? 
//?   // user-defined functions
//?   next_input,
//?   input,
//?   prepare_reply,
//?   reply,
//? 
//?   Max_primitive_recipe,
//? };

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
  type_info() :size(0) {}
};

typedef int type_number;
unordered_map<string, type_number> Type_number;
unordered_map<type_number, type_info> Type;
int Next_type_number = 1;

unordered_map<int, int> Memory;

struct reagent {
  string name;
  vector<type_number> types;
  vector<pair<string, property> > properties;
  reagent(string s) {
    istringstream in(s);
    name = slurp_until(in, ':');
    types.push_back(Type_number[slurp_until(in, '/')]);  // todo: multiple types
  }
  string to_string() {
    ostringstream out;
    out << "{name: \"" << name << "\", type: " << types[0] << "}\n";  // todo: properties
    return out.str();
  }
};

const int idle = 0;

struct instruction {
  bool is_label;
  string label;  // only if is_label
  recipe_number operation;  // only if !is_label
  vector<reagent> ingredients;  // only if !is_label
  vector<reagent> products;  // only if !is_label
  instruction() :is_label(false), operation(idle) {}
  void clear() { is_label=false; label.clear(); operation=idle; ingredients.clear(); products.clear(); }
};

struct recipe {
  vector<instruction> step;
};

typedef int recipe_number;
unordered_map<string, recipe_number> Recipe_number;
unordered_map<recipe_number, recipe> Recipe;
int Next_recipe_number = 1;

void load(string filename) {
}

void run(string function_name) {
}

void setup_memory() {
  Memory.clear();
}

void setup_types() {
  Type.clear();  Type_number.clear();
  Type_number["literal"] = 0;
  Next_type_number = 1;
  int integer = Type_number["integer"] = Next_type_number++;
  Type[integer].size = 1;
}

void setup_recipes() {
  Recipe.clear();  Recipe_number.clear();
  Recipe_number["idle"] = 0;
  Next_recipe_number = 1;
  Recipe_number["copy"] = Next_recipe_number++;
//?   dbg << "AAA " << Recipe_number["copy"] << '\n'; //? 1
}

void compile(string form) {
  istringstream in(form);
  in >> std::noskipws;

  string _recipe = next_word(in);
//?   cout << _recipe << '\n'; //? 1
  if (_recipe != "recipe")
    raise << "top-level forms must be of the form 'recipe _name_ [ _instruction_ ... ]'\n";

  string recipe_name = next_word(in);
//?   cout << '^' << recipe_name << "$\n"; //? 1
  if (recipe_name.empty())
    raise << "empty recipe name in " << form << '\n';
  int r = Recipe_number[recipe_name] = Next_recipe_number++;

//?   string foo = next_word(in); //? 1
//?   cout << '^' << foo << "$ (" << foo.size() << ")\n"; //? 1
  if (next_word(in) != "[")
    raise << "recipe body must begin with '['\n";

  skip_newlines(in);

  instruction curr;
  while (next_instruction(in, &curr)) {
    Recipe[r].step.push_back(curr);
  }
}

bool next_instruction(istream& in, instruction* curr) {
  curr->clear();
  if (in.eof()) return false;
  skip_whitespace(in);  if (in.eof()) return false;
  skip_newlines(in);  if (in.eof()) return false;

//?   vector<string> ingredients, products; //? 1
  vector<string> words;
  while (in.peek() != '\n') {
    skip_whitespace(in);  if (in.eof()) return false;
    string word = next_word(in);  if (in.eof()) return false;
    words.push_back(word);
    skip_whitespace(in);  if (in.eof()) return false;
  }
  skip_newlines(in);  if (in.eof()) return false;
//?   cout << "words: "; //? 1
//?   for (vector<string>::iterator p = words.begin(); p != words.end(); ++p) { //? 1
//?     cout << *p << "; "; //? 1
//?   } //? 1
//?   cout << '\n'; //? 1
//?   return true; //? 1

  if (words.size() == 1 && *(words[0].end()-1) == ':') {
    curr->is_label = true;
    words[0].erase(words[0].end()-1);
    curr->label = words[0];
    trace("parse") << "label: " << curr->label;
    return !in.eof();
  }

  vector<string>::iterator p = words.begin();
  if (find(words.begin(), words.end(), "<-") != words.end()) {
//?     cout << "instruction yields products\n"; //? 1
    for (; *p != "<-"; ++p) {
      if (*p == ",") continue;
//?       cout << "product: " << *p << '\n'; //? 1
//?       products.push_back(*p); //? 1
      curr->products.push_back(reagent(*p));
    }
    ++p;  // skip <-
  }
//?   return true; //? 1

  curr->operation = Recipe_number[*p];  ++p;

  for (; p != words.end(); ++p) {
    if (*p == ",") continue;
//?     cout << "ingredient: " << *p << '\n'; //? 1
    curr->ingredients.push_back(reagent(*p));
  }

  trace("parse") << "instruction: " << curr->operation;
  for (vector<reagent>::iterator p = curr->ingredients.begin(); p != curr->ingredients.end(); ++p) {
    trace("parse") << "  ingredient: " << p->to_string();
  }
  for (vector<reagent>::iterator p = curr->products.begin(); p != curr->products.end(); ++p) {
    trace("parse") << "  product: " << p->to_string();
  }
  return !in.eof();
}

string next_word(istream& in) {
  ostringstream out;
//?   cout << "1: " << (int)in.peek() << '\n'; //? 1
  skip_whitespace(in);
//?   cout << "2: " << (int)in.peek() << '\n'; //? 1
  slurp_word(in, out);
//?   cout << "3: " << (int)in.peek() << '\n'; //? 1
//?   cout << out.str() << '\n'; //? 1
  return out.str();
}

void slurp_word(istream& in, ostream& out) {
  char c;
  if (in.peek() == ',') {
    in >> c;
    out << c;
    return;
  }
  while (in >> c) {
//?     cout << c << '\n'; //? 1
    if (isspace(c) || c == ',') {
//?       cout << "  space\n"; //? 1
      in.putback(c);
      break;
    }
    out << c;
  }
}

void skip_whitespace(istream& in) {
  while (isspace(in.peek()) && in.peek() != '\n') {
//?     cout << "skip\n"; //? 1
    in.get();
  }
}

void skip_newlines(istream& in) {
  while (in.peek() == '\n')
    in.get();
}

void skip_comma(istream& in) {
  skip_whitespace(in);
  if (in.peek() == ',') in.get();
  skip_whitespace(in);
}

string slurp_until(istream& in, char delim) {
  ostringstream out;
  char c;
  while (in >> c) {
    if (c == delim) {
      break;
    }
    out << c;
  }
  return out.str();
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
  setup_memory();
  setup_types();
  setup_recipes();
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

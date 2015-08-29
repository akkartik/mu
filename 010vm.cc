//: A program is a book of 'recipes' (functions)
:(before "End Globals")
//: Each recipe is stored at a specific page number, or ordinal.
map<recipe_ordinal, recipe> Recipe;
//: You can also refer to each recipe by its name.
map<string, recipe_ordinal> Recipe_ordinal;
recipe_ordinal Next_recipe_ordinal = 1;

//: Ordinals are like numbers, except you can't do arithmetic on them. Ordinal
//: 1 is not less than 2, it's just different. Phone numbers are ordinals;
//: adding two phone numbers is meaningless. Here each recipe does something
//: incommensurable with any other recipe.
:(after "Types")
typedef long long int recipe_ordinal;

:(before "End Types")
// Recipes are lists of instructions. To perform or 'run' a recipe, the
// computer runs its instructions.
struct recipe {
  string name;
  vector<instruction> steps;
  // End recipe Fields
};

:(before "struct recipe")
// Each instruction is either of the form:
//   product1, product2, product3, ... <- operation ingredient1, ingredient2, ingredient3, ...
// or just a single 'label' starting with a non-alphanumeric character
//   +label
// Labels don't do anything, they're just waypoints.
struct instruction {
  bool is_label;
  string label;  // only if is_label
  string name;  // only if !is_label
  recipe_ordinal operation;  // Recipe_ordinal[name]
  vector<reagent> ingredients;  // only if !is_label
  vector<reagent> products;  // only if !is_label
  // End instruction Fields
  instruction();
  void clear();
  string to_string() const;
};

:(before "struct instruction")
// Ingredients and products are a single species -- a reagent. Reagents refer
// either to numbers or to locations in memory along with 'type' tags telling
// us how to interpret them. They also can contain arbitrary other lists of
// properties besides types, but we're getting ahead of ourselves.
struct reagent {
  string original_string;
  vector<pair<string, vector<string> > > properties;
  string name;
  double value;
  bool initialized;
  vector<type_ordinal> types;
  reagent(string s);
  reagent();
  void set_value(double v) { value = v; initialized = true; }
  string to_string() const;
};

:(before "struct reagent")
struct property {
  vector<string> values;
};

:(before "End Globals")
// Locations refer to a common 'memory'. Each location can store a number.
map<long long int, double> Memory;
:(before "End Setup")
Memory.clear();

:(after "Types")
// Mu types encode how the numbers stored in different parts of memory are
// interpreted. A location tagged as a 'character' type will interpret the
// number 97 as the letter 'a', while a different location of type 'number'
// would not.
//
// Unlike most computers today, mu stores types in a single big table, shared
// by all the mu programs on the computer. This is useful in providing a
// seamless experience to help understand arbitrary mu programs.
typedef long long int type_ordinal;
:(before "End Globals")
map<string, type_ordinal> Type_ordinal;
map<type_ordinal, type_info> Type;
type_ordinal Next_type_ordinal = 1;
:(code)
void setup_types() {
  Type.clear();  Type_ordinal.clear();
  Type_ordinal["literal"] = 0;
  Next_type_ordinal = 1;
  // Mu Types Initialization
  type_ordinal number = Type_ordinal["number"] = Next_type_ordinal++;
  Type_ordinal["location"] = Type_ordinal["number"];  // wildcard type: either a pointer or a scalar
  Type[number].name = "number";
  type_ordinal address = Type_ordinal["address"] = Next_type_ordinal++;
  Type[address].name = "address";
  type_ordinal boolean = Type_ordinal["boolean"] = Next_type_ordinal++;
  Type[boolean].name = "boolean";
  type_ordinal character = Type_ordinal["character"] = Next_type_ordinal++;
  Type[character].name = "character";
  // Array types are a special modifier to any other type. For example,
  // array:number or array:address:boolean.
  type_ordinal array = Type_ordinal["array"] = Next_type_ordinal++;
  Type[array].name = "array";
  // End Mu Types Initialization
}
:(before "End One-time Setup")
setup_types();

:(before "End Types")
// You can construct arbitrary new types. New types are either 'containers'
// with multiple 'elements' of other types, or 'exclusive containers' containing
// one of multiple 'variants'. (These are similar to C structs and unions,
// respectively, though exclusive containers implicitly include a tag element
// recording which variant they should be interpreted as.)
//
// For example, storing bank balance and name for an account might require a
// container, but if bank accounts may be either for individuals or groups,
// with different properties for each, that may require an exclusive container
// whose variants are individual-account and joint-account containers.
enum kind_of_type {
  primitive,
  container,
  exclusive_container
};

struct type_info {
  string name;
  kind_of_type kind;
  long long int size;  // only if type is not primitive; primitives and addresses have size 1 (except arrays are dynamic)
  vector<vector<type_ordinal> > elements;
  vector<string> element_names;
  // End type_info Fields
  type_info() :kind(primitive), size(0) {}
};

enum primitive_recipes {
  IDLE = 0,
  COPY,
  // End Primitive Recipe Declarations
  MAX_PRIMITIVE_RECIPES,
};
:(code)
//: It's all very well to construct recipes out of other recipes, but we need
//: to know how to do *something* out of the box. For the following
//: recipes there are only codes, no entries in the book, because mu just knows
//: what to do for them.
void setup_recipes() {
  Recipe.clear();  Recipe_ordinal.clear();
  Recipe_ordinal["idle"] = IDLE;
  // Primitive Recipe Numbers
  Recipe_ordinal["copy"] = COPY;
  // End Primitive Recipe Numbers
}
//: We could just reset the recipe table after every test, but that gets slow
//: all too quickly. Instead, initialize the common stuff just once at
//: startup. Later layers will carefully undo each test's additions after
//: itself.
:(before "End One-time Setup")
setup_recipes();
assert(MAX_PRIMITIVE_RECIPES < 200);  // level 0 is primitives; until 199
Next_recipe_ordinal = 200;
Recipe_ordinal["main"] = Next_recipe_ordinal++;
// End Load Recipes
:(before "End Test Run Initialization")
assert(Next_recipe_ordinal < 1000);  // recipes being tested didn't overflow into test space
:(before "End Setup")
Next_recipe_ordinal = 1000;  // consistent new numbers for each test



//:: Helpers

:(code)
instruction::instruction() :is_label(false), operation(IDLE) {
  // End instruction Constructor
}
void instruction::clear() { is_label=false; label.clear(); operation=IDLE; ingredients.clear(); products.clear(); }

// Reagents have the form <name>:<type>:<type>:.../<property>/<property>/...
reagent::reagent(string s) :original_string(s), value(0), initialized(false) {
  // Parsing reagent(string s)
  istringstream in(s);
  in >> std::noskipws;
  // properties
  while (!in.eof()) {
    istringstream row(slurp_until(in, '/'));
    row >> std::noskipws;
    string name = slurp_until(row, ':');
    vector<string> values;
    while (!row.eof())
      values.push_back(slurp_until(row, ':'));
    properties.push_back(pair<string, vector<string> >(name, values));
  }
  // structures for the first row of properties
  name = properties.at(0).first;
  for (long long int i = 0; i < SIZE(properties.at(0).second); ++i) {
    string type = properties.at(0).second.at(i);
    if (Type_ordinal.find(type) == Type_ordinal.end()
        // types can contain integers, like for array sizes
        && !is_integer(type)) {
      Type_ordinal[type] = Next_type_ordinal++;
    }
    types.push_back(Type_ordinal[type]);
  }
  if (is_integer(name) && types.empty()) {
    types.push_back(0);
    properties.at(0).second.push_back("literal");
  }
  if (name == "_" && types.empty()) {
    types.push_back(0);
    properties.at(0).second.push_back("dummy");
  }
  // End Parsing reagent
}

reagent::reagent() :value(0), initialized(false) {
  // The first property is special, so ensure we always have it.
  // Other properties can be pushed back, but the first must always be
  // assigned to.
  properties.push_back(pair<string, vector<string> >("", vector<string>()));
}

string reagent::to_string() const {
  ostringstream out;
  out << "{name: \"" << name << "\"";
  if (!properties.empty()) {
    out << ", properties: [";
    for (long long int i = 0; i < SIZE(properties); ++i) {
      out << "\"" << properties.at(i).first << "\": ";
      for (long long int j = 0; j < SIZE(properties.at(i).second); ++j) {
        if (j > 0) out << ':';
        out << "\"" << properties.at(i).second.at(j) << "\"";
      }
      if (i < SIZE(properties)-1) out << ", ";
      else out << "]";
    }
  }
  out << "}";
  return out.str();
}

string instruction::to_string() const {
  if (is_label) return label;
  ostringstream out;
  for (long long int i = 0; i < SIZE(products); ++i) {
    if (i > 0) out << ", ";
    out << products.at(i).original_string;
  }
  if (!products.empty()) out << " <- ";
  out << name << ' ';
  for (long long int i = 0; i < SIZE(ingredients); ++i) {
    if (i > 0) out << ", ";
    out << ingredients.at(i).original_string;
  }
  return out.str();
}

string slurp_until(istream& in, char delim) {
  ostringstream out;
  char c;
  while (in >> c) {
    if (c == delim) {
      // drop the delim
      break;
    }
    out << c;
  }
  return out.str();
}

bool has_property(reagent x, string name) {
  for (long long int i = /*skip name:type*/1; i < SIZE(x.properties); ++i) {
    if (x.properties.at(i).first == name) return true;
  }
  return false;
}

vector<string> property(const reagent& r, const string& name) {
  for (long long int p = /*skip name:type*/1; p != SIZE(r.properties); ++p) {
    if (r.properties.at(p).first == name)
      return r.properties.at(p).second;
  }
  return vector<string>();
}

void dump_memory() {
  for (map<long long int, double>::iterator p = Memory.begin(); p != Memory.end(); ++p) {
    cout << p->first << ": " << p->second << '\n';
  }
}
:(before "End Includes")
#include<utility>
using std::pair;

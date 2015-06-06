//: Helper for the repl.

:(before "End Primitive Recipe Declarations")
RUN_INTERACTIVE,
:(before "End Primitive Recipe Numbers")
Recipe_number["run-interactive"] = RUN_INTERACTIVE;
//? cerr << "run-interactive: " << RUN_INTERACTIVE << '\n'; //? 1
:(before "End Primitive Recipe Implementations")
case RUN_INTERACTIVE: {
  assert(scalar(ingredients.at(0)));
//?   cerr << "AAA 0\n"; //? 1
  run_interactive(ingredients.at(0).at(0));
//?   cerr << "ZZZ\n"; //? 1
  continue;  // not done with caller; don't increment current_step_index()
}

:(code)
// manual tests:
//  just an integer prints value of that location in memory
//  instruction executes
//  backspace at start begins new attempt
//  ctrl-d working
void run_interactive(long long int address) {
//?   tb_shutdown(); //? 1
  long long int size = Memory[address];
  if (size == 0) {
    ++current_step_index();
    return;
  }
  ostringstream tmp;
  for (long long int curr = address+1; curr < address+size; ++curr) {
    // todo: unicode
    tmp << (char)(int)Memory[curr];
  }
//?   cerr << size << ' ' << Memory[address+size] << '\n'; //? 1
  assert(Memory[address+size] == 10);  // skip the newline
  if (Recipe_number.find("interactive") == Recipe_number.end())
    Recipe_number["interactive"] = Next_recipe_number++;
  if (is_integer(tmp.str())) {
    print_value_of_location_as_response(to_integer(tmp.str()));
    ++current_step_index();
    return;
  }
//?   exit(0); //? 1
  if (Name[Recipe_number["interactive"]].find(tmp.str()) != Name[Recipe_number["interactive"]].end()) {
    print_value_of_location_as_response(Name[Recipe_number["interactive"]][tmp.str()]);
    ++current_step_index();
    return;
  }
//?   tb_shutdown(); //? 1
//?   cerr << tmp.str(); //? 1
//?   exit(0); //? 1
//?   cerr << "AAA 1\n"; //? 1
  Recipe.erase(Recipe_number["interactive"]);
  // call run(string) but without the scheduling
//?   cerr << ("recipe interactive [\n"+tmp.str()+"\n]\n"); //? 1
  load("recipe interactive [\n"+tmp.str()+"\n]\n");
  transform_all();
//?   cerr << "names: " << Name[Recipe_number["interactive"]].size() << "; "; //? 1
//?   cerr << "steps: " << Recipe[Recipe_number["interactive"]].steps.size() << "; "; //? 1
//?   cerr << "interactive transformed_until: " << Recipe[Recipe_number["interactive"]].transformed_until << '\n'; //? 1
  Current_routine->calls.push_front(call(Recipe_number["interactive"]));
}

void print_value_of_location_as_response(long long int address) {
  // convert to string
  ostringstream out;
  out << "=> " << Memory[address];
  string result = out.str();
  // handle regular I/O
  if (!tb_is_active()) {
    cerr << result << '\n';
    return;
  }
  // raw I/O; use termbox to print
  long long int bound = SIZE(result);
  if (bound > tb_width()) bound = tb_width();
  for (long long int i = 0; i < bound; ++i) {
    tb_change_cell(i, Display_row, result.at(i), /*computer's color*/245, TB_BLACK);
  }
  // newline
  if (Display_row < tb_height()-1)
    ++Display_row;
  Display_column = 0;
  tb_set_cursor(Display_column, Display_row);
  tb_present();
}

//:: debugging tool

:(before "End Primitive Recipe Declarations")
_RUN_DEPTH,
:(before "End Primitive Recipe Numbers")
Recipe_number["$run-depth"] = _RUN_DEPTH;
:(before "End Primitive Recipe Implementations")
case _RUN_DEPTH: {
  cerr << Current_routine->calls.size();
  break;
}

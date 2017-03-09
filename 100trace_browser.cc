//: A debugging helper that lets you zoom in/out on a trace.
//: Warning: this tool has zero automated tests.
//:
//: To try it out, first create an example trace:
//:   mu --trace nqueens.mu
//: Then to browse the trace, which was stored in a file called 'last_run':
//:   mu browse-trace last_run
//:
//: You should now find yourself in a UI showing a subsequence of lines from
//: the trace, each line starting with a numeric depth, and ending with a
//: parenthetical count of trace lines hidden after it with greater depths.
//:
//: For example, this line:
//:   2 app: line1 (30)
//: indicates that it was logged with depth 2, and that 30 following lines
//: have been hidden at a depth greater than 2.
//:
//: As an experiment, hidden counts of 1000 or more are in red to highlight
//: where you might be particularly interested in expanding.
//:
//: The UI provides the following hotkeys:
//:
//:   `q` or `ctrl-c`: Quit.
//:
//:   `Enter`: 'Zoom into' this line. Expand some or all of the hidden lines
//:   at the next higher level, updating parenthetical counts of hidden lines.
//:
//:   `Backspace`: 'Zoom out' on a line after zooming in, collapsing expanded
//:   lines below by some series of <Enter> commands.
//:
//:   `j` or `down-arrow`: Move/scroll cursor down one line.
//:   `k` or `up-arrow`: Move/scroll cursor up one line.
//:   `J` or `ctrl-f` or `page-down`: Scroll cursor down one page.
//:   `K` or `ctrl-b` or `page-up`: Scroll cursor up one page.
//:   `h` or `left-arrow`: Scroll cursor left one character.
//:   `l` or `right-arrow`: Scroll cursor right one character.
//:   `H`: Scroll cursor left one screen-width.
//:   `L`: Scroll cursor right one screen-width.
//:
//:   `g` or `home`: Move cursor to start of trace.
//:   `G` or `end`: Move cursor to end of trace.
//:
//:   `t`: Move cursor to top line on screen.
//:   `c`: Move cursor to center line on screen.
//:   `b`: Move cursor to bottom line on screen.
//:   `T`: Scroll line at cursor to top of screen.

:(before "End Primitive Recipe Declarations")
_BROWSE_TRACE,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$browse-trace", _BROWSE_TRACE);
:(before "End Primitive Recipe Checks")
case _BROWSE_TRACE: {
  break;
}
:(before "End Primitive Recipe Implementations")
case _BROWSE_TRACE: {
  start_trace_browser();
  break;
}

//: browse a trace loaded from a file
:(after "Commandline Parsing")
if (argc == 3 && is_equal(argv[1], "browse-trace")) {
  load_trace(argv[2]);
  start_trace_browser();
  return 0;
}

:(before "End Globals")
set<int> Visible;
int Top_of_screen = 0;
int Left_of_screen = 0;
int Last_printed_row = 0;
map<int, int> Trace_index;  // screen row -> trace index

:(code)
void start_trace_browser() {
  if (!Trace_stream) return;
  cerr << "computing min depth to display\n";
  int min_depth = 9999;
  for (int i = 0;  i < SIZE(Trace_stream->past_lines);  ++i) {
    trace_line& curr_line = Trace_stream->past_lines.at(i);
    if (curr_line.depth < min_depth) min_depth = curr_line.depth;
  }
  cerr << "min depth is " << min_depth << '\n';
  cerr << "computing lines to display\n";
  for (int i = 0;  i < SIZE(Trace_stream->past_lines);  ++i) {
    if (Trace_stream->past_lines.at(i).depth == min_depth)
      Visible.insert(i);
  }
  tb_init();
  Display_row = Display_column = 0;
  Top_of_screen = 0;
  refresh_screen_rows();
  while (true) {
    render();
    int key = read_key();
    if (key == 'q' || key == 'Q' || key == TB_KEY_CTRL_C) break;
    if (key == 'j' || key == TB_KEY_ARROW_DOWN) {
      // move cursor one line down
      if (Display_row < Last_printed_row) ++Display_row;
    }
    else if (key == 'k' || key == TB_KEY_ARROW_UP) {
      // move cursor one line up
      if (Display_row > 0) --Display_row;
    }
    else if (key == 't') {
      // move cursor to top of screen
      Display_row = 0;
    }
    else if (key == 'c') {
      // move cursor to center of screen
      Display_row = tb_height()/2;
      while (!contains_key(Trace_index, Display_row))
        --Display_row;
    }
    else if (key == 'b') {
      // move cursor to bottom of screen
      Display_row = tb_height()-1;
      while (!contains_key(Trace_index, Display_row))
        --Display_row;
    }
    else if (key == 'T') {
      // scroll line at cursor to top of screen
      Top_of_screen = get(Trace_index, Display_row);
      Display_row = 0;
      refresh_screen_rows();
    }
    else if (key == 'h' || key == TB_KEY_ARROW_LEFT) {
      // pan screen one character left
      if (Left_of_screen > 0) --Left_of_screen;
    }
    else if (key == 'l' || key == TB_KEY_ARROW_RIGHT) {
      // pan screen one character right
      ++Left_of_screen;
    }
    else if (key == 'H') {
      // pan screen one screen-width left
      Left_of_screen -= (tb_width() - 5);
      if (Left_of_screen < 0) Left_of_screen = 0;
    }
    else if (key == 'L') {
      // pan screen one screen-width right
      Left_of_screen += (tb_width() - 5);
    }
    else if (key == 'J' || key == TB_KEY_PGDN || key == TB_KEY_CTRL_F) {
      // page-down
      if (Trace_index.find(tb_height()-1) != Trace_index.end()) {
        Top_of_screen = get(Trace_index, tb_height()-1) + 1;
        refresh_screen_rows();
      }
    }
    else if (key == 'K' || key == TB_KEY_PGUP || key == TB_KEY_CTRL_B) {
      // page-up is more convoluted
      for (int screen_row = tb_height();  screen_row > 0 && Top_of_screen > 0;  --screen_row) {
        --Top_of_screen;
        if (Top_of_screen <= 0) break;
        while (Top_of_screen > 0 && !contains_key(Visible, Top_of_screen))
          --Top_of_screen;
      }
      if (Top_of_screen >= 0)
        refresh_screen_rows();
    }
    else if (key == 'g' || key == TB_KEY_HOME) {
        Top_of_screen = 0;
        Last_printed_row = 0;
        Display_row = 0;
        refresh_screen_rows();
    }
    else if (key == 'G' || key == TB_KEY_END) {
      // go to bottom of screen; largely like page-up, interestingly
      Top_of_screen = SIZE(Trace_stream->past_lines)-1;
      for (int screen_row = tb_height();  screen_row > 0 && Top_of_screen > 0;  --screen_row) {
        --Top_of_screen;
        if (Top_of_screen <= 0) break;
        while (Top_of_screen > 0 && !contains_key(Visible, Top_of_screen))
          --Top_of_screen;
      }
      refresh_screen_rows();
      // move cursor to bottom
      Display_row = Last_printed_row;
      refresh_screen_rows();
    }
    else if (key == TB_KEY_CARRIAGE_RETURN) {
      // expand lines under current by one level
      assert(contains_key(Trace_index, Display_row));
      int start_index = get(Trace_index, Display_row);
      int index = 0;
      // simultaneously compute end_index and min_depth
      int min_depth = 9999;
      for (index = start_index+1;  index < SIZE(Trace_stream->past_lines);  ++index) {
        if (contains_key(Visible, index)) break;
        trace_line& curr_line = Trace_stream->past_lines.at(index);
        assert(curr_line.depth > Trace_stream->past_lines.at(start_index).depth);
        if (curr_line.depth < min_depth) min_depth = curr_line.depth;
      }
      int end_index = index;
      // mark as visible all intervening indices at min_depth
      for (index = start_index;  index < end_index;  ++index) {
        trace_line& curr_line = Trace_stream->past_lines.at(index);
        if (curr_line.depth == min_depth) {
          Visible.insert(index);
        }
      }
      refresh_screen_rows();
    }
    else if (key == TB_KEY_BACKSPACE || key == TB_KEY_BACKSPACE2) {
      // collapse all lines under current
      assert(contains_key(Trace_index, Display_row));
      int start_index = get(Trace_index, Display_row);
      int index = 0;
      // end_index is the next line at a depth same as or lower than start_index
      int initial_depth = Trace_stream->past_lines.at(start_index).depth;
      for (index = start_index+1;  index < SIZE(Trace_stream->past_lines);  ++index) {
        if (!contains_key(Visible, index)) continue;
        trace_line& curr_line = Trace_stream->past_lines.at(index);
        if (curr_line.depth <= initial_depth) break;
      }
      int end_index = index;
      // mark as visible all intervening indices at min_depth
      for (index = start_index+1;  index < end_index;  ++index) {
        Visible.erase(index);
      }
      refresh_screen_rows();
    }
  }
  tb_shutdown();
}

// update Trace_indices for each screen_row on the basis of Top_of_screen and Visible
void refresh_screen_rows() {
  int screen_row = 0, index = 0;
  Trace_index.clear();
  for (screen_row = 0, index = Top_of_screen;  screen_row < tb_height() && index < SIZE(Trace_stream->past_lines);  ++screen_row, ++index) {
    // skip lines without depth for now
    while (!contains_key(Visible, index)) {
      ++index;
      if (index >= SIZE(Trace_stream->past_lines)) goto done;
    }
    assert(index < SIZE(Trace_stream->past_lines));
    put(Trace_index, screen_row, index);
  }
done:;
}

void render() {
  int screen_row = 0;
  for (screen_row = 0;  screen_row < tb_height();  ++screen_row) {
    if (!contains_key(Trace_index, screen_row)) break;
    trace_line& curr_line = Trace_stream->past_lines.at(get(Trace_index, screen_row));
    ostringstream out;
    out << std::setw(4) << curr_line.depth << ' ' << curr_line.label << ": " << curr_line.contents;
    if (screen_row < tb_height()-1) {
      int delta = lines_hidden(screen_row);
      // home-brew escape sequence for red
      if (delta > 999) out << static_cast<char>(1);
      out << " (" << delta << ")";
      if (delta > 999) out << static_cast<char>(2);
    }
    render_line(screen_row, out.str(), screen_row == Display_row);
  }
  // clear rest of screen
  Last_printed_row = screen_row-1;
  for (;  screen_row < tb_height();  ++screen_row) {
    render_line(screen_row, "~", /*highlight?*/false);
  }
  // move cursor back to display row at the end
  tb_set_cursor(0, Display_row);
  tb_present();
}

int lines_hidden(int screen_row) {
  assert(contains_key(Trace_index, screen_row));
  if (!contains_key(Trace_index, screen_row+1))
    return SIZE(Trace_stream->past_lines) - get(Trace_index, screen_row);
  else
    return get(Trace_index, screen_row+1) - get(Trace_index, screen_row);
}

void render_line(int screen_row, const string& s, bool highlight) {
  int col = 0;
  int color = TB_WHITE;
  for (col = 0;  col < tb_width() && col+Left_of_screen < SIZE(s);  ++col) {
    char c = s.at(col+Left_of_screen);  // todo: unicode
    if (c == '\n') c = ';';  // replace newlines with semi-colons
    // escapes. hack: can't start a line with them.
    if (c == '\1') { color = /*red*/1;  c = ' '; }
    if (c == '\2') { color = TB_WHITE;  c = ' '; }
    tb_change_cell(col, screen_row, c, color, highlight ? /*subtle grey*/240 : TB_BLACK);
  }
  for (;  col < tb_width();  ++col)
    tb_change_cell(col, screen_row, ' ', TB_WHITE, highlight ? /*subtle grey*/240 : TB_BLACK);
}

void load_trace(const char* filename) {
  ifstream tin(filename);
  if (!tin) {
    cerr << "no such file: " << filename << '\n';
    exit(1);
  }
  Trace_stream = new trace_stream;
  while (has_data(tin)) {
    tin >> std::noskipws;
      skip_whitespace_but_not_newline(tin);
      if (!isdigit(tin.peek())) {
        string dummy;
        getline(tin, dummy);
        continue;
      }
    tin >> std::skipws;
    int depth;
    tin >> depth;
    string label;
    tin >> label;
    if (*--label.end() == ':') label.erase(--label.end());
    string line;
    getline(tin, line);
    Trace_stream->past_lines.push_back(trace_line(depth, label, line));
  }
  cerr << "lines read: " << Trace_stream->past_lines.size() << '\n';
}

int read_key() {
  tb_event event;
  do {
    tb_poll_event(&event);
  } while (event.type != TB_EVENT_KEY);
  return event.key ? event.key : event.ch;
}

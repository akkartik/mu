//: A debugging helper that lets you zoom in/out on a trace.

//: browse the trace we just created
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
int Last_printed_row = 0;
map<int, int> Trace_index;  // screen row -> trace index

:(code)
void start_trace_browser() {
  if (!Trace_stream) return;
  cerr << "computing min depth to display\n";
  int min_depth = 9999;
  for (int i = 0; i < SIZE(Trace_stream->past_lines); ++i) {
    trace_line& curr_line = Trace_stream->past_lines.at(i);
    if (curr_line.depth < min_depth) min_depth = curr_line.depth;
  }
  cerr << "min depth is " << min_depth << '\n';
  cerr << "computing lines to display\n";
  for (int i = 0; i < SIZE(Trace_stream->past_lines); ++i) {
    if (Trace_stream->past_lines.at(i).depth == min_depth)
      Visible.insert(i);
  }
  tb_init();
  Display_row = Display_column = 0;
  tb_event event;
  Top_of_screen = 0;
  refresh_screen_rows();
  while (true) {
    render();
    do {
      tb_poll_event(&event);
    } while (event.type != TB_EVENT_KEY);
    int key = event.key ? event.key : event.ch;
    if (key == 'q' || key == 'Q') break;
    if (key == 'j' || key == TB_KEY_ARROW_DOWN) {
      // move cursor one line down
      if (Display_row < Last_printed_row) ++Display_row;
    }
    if (key == 'k' || key == TB_KEY_ARROW_UP) {
      // move cursor one line up
      if (Display_row > 0) --Display_row;
    }
    if (key == 'H') {
      // move cursor to top of screen
      Display_row = 0;
    }
    if (key == 'M') {
      // move cursor to center of screen
      Display_row = tb_height()/2;
    }
    if (key == 'L') {
      // move cursor to bottom of screen
      Display_row = tb_height()-1;
    }
    if (key == 'J' || key == TB_KEY_PGDN) {
      // page-down
      if (Trace_index.find(tb_height()-1) != Trace_index.end()) {
        Top_of_screen = get(Trace_index, tb_height()-1) + 1;
        refresh_screen_rows();
      }
    }
    if (key == 'K' || key == TB_KEY_PGUP) {
      // page-up is more convoluted
      for (int screen_row = tb_height(); screen_row > 0 && Top_of_screen > 0; --screen_row) {
        --Top_of_screen;
        if (Top_of_screen <= 0) break;
        while (Top_of_screen > 0 && !contains_key(Visible, Top_of_screen))
          --Top_of_screen;
      }
      if (Top_of_screen >= 0)
        refresh_screen_rows();
    }
    if (key == 'G') {
      // go to bottom of screen; largely like page-up, interestingly
      Top_of_screen = SIZE(Trace_stream->past_lines)-1;
      for (int screen_row = tb_height(); screen_row > 0 && Top_of_screen > 0; --screen_row) {
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
    if (key == TB_KEY_CARRIAGE_RETURN) {
      // expand lines under current by one level
      assert(contains_key(Trace_index, Display_row));
      int start_index = get(Trace_index, Display_row);
      int index = 0;
      // simultaneously compute end_index and min_depth
      int min_depth = 9999;
      for (index = start_index+1; index < SIZE(Trace_stream->past_lines); ++index) {
        if (contains_key(Visible, index)) break;
        trace_line& curr_line = Trace_stream->past_lines.at(index);
        assert(curr_line.depth > Trace_stream->past_lines.at(start_index).depth);
        if (curr_line.depth < min_depth) min_depth = curr_line.depth;
      }
      int end_index = index;
      // mark as visible all intervening indices at min_depth
      for (index = start_index; index < end_index; ++index) {
        trace_line& curr_line = Trace_stream->past_lines.at(index);
        if (curr_line.depth == min_depth) {
          Visible.insert(index);
        }
      }
      refresh_screen_rows();
    }
    if (key == TB_KEY_BACKSPACE || key == TB_KEY_BACKSPACE2) {
      // collapse all lines under current
      assert(contains_key(Trace_index, Display_row));
      int start_index = get(Trace_index, Display_row);
      int index = 0;
      // end_index is the next line at a depth same as or lower than start_index
      int initial_depth = Trace_stream->past_lines.at(start_index).depth;
      for (index = start_index+1; index < SIZE(Trace_stream->past_lines); ++index) {
        if (!contains_key(Visible, index)) continue;
        trace_line& curr_line = Trace_stream->past_lines.at(index);
        if (curr_line.depth <= initial_depth) break;
      }
      int end_index = index;
      // mark as visible all intervening indices at min_depth
      for (index = start_index+1; index < end_index; ++index) {
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
  for (screen_row = 0, index = Top_of_screen; screen_row < tb_height() && index < SIZE(Trace_stream->past_lines); ++screen_row, ++index) {
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
  for (screen_row = 0; screen_row < tb_height(); ++screen_row) {
    if (!contains_key(Trace_index, screen_row)) break;
    trace_line& curr_line = Trace_stream->past_lines.at(get(Trace_index, screen_row));
    ostringstream out;
    out << std::setw(4) << curr_line.depth << ' ' << curr_line.label << ": " << curr_line.contents;
    if (screen_row < tb_height()-1) {
      int delta = lines_hidden(screen_row);
      // home-brew escape sequence for red
      if (delta > 999) out << "{";
      out << " (" << delta << ")";
      if (delta > 999) out << "}";
    }
    render_line(screen_row, out.str());
  }
  // clear rest of screen
  Last_printed_row = screen_row-1;
  for (; screen_row < tb_height(); ++screen_row) {
    render_line(screen_row, "~");
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

void render_line(int screen_row, const string& s) {
  int col = 0;
  int color = TB_WHITE;
  for (col = 0; col < tb_width() && col < SIZE(s); ++col) {
    char c = s.at(col);  // todo: unicode
    if (c == '\n') c = ';';  // replace newlines with semi-colons
    // escapes. hack: can't start a line with them.
    if (c == '{') { color = /*red*/1; c = ' '; }
    if (c == '}') { color = TB_WHITE; c = ' '; }
    tb_change_cell(col, screen_row, c, color, TB_BLACK);
  }
  for (; col < tb_width(); ++col) {
    tb_change_cell(col, screen_row, ' ', TB_WHITE, TB_BLACK);
  }
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

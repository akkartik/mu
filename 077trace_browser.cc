:(before "End Primitive Recipe Declarations")
_BROWSE_TRACE,
:(before "End Primitive Recipe Numbers")
Recipe_number["$browse-trace"] = _BROWSE_TRACE;
:(before "End Primitive Recipe Implementations")
case _BROWSE_TRACE: {
  start_trace_browser();
  break;
}

:(before "End Globals")
long long int Top_of_screen = 0;

:(code)
void start_trace_browser() {
  if (!Trace_stream) return;
  tb_init();
  Display_row = Display_column = 0;
  struct tb_event event;
  while (true) {
    render();
    do {
      tb_poll_event(&event);
    } while (event.type != TB_EVENT_KEY);
    long long int key = event.key ? event.key : event.ch;
    if (key == 'q' || key == 'Q') break;
  }
  tb_shutdown();
}

void render() {
  long long int screen_row = 0, index = 0;
  for (screen_row = 0, index = Top_of_screen; screen_row < tb_height() && index < SIZE(Trace_stream->past_lines); ++screen_row, ++index) {
    // skip lines without depth for now
    while (Trace_stream->past_lines.at(index).depth == 0) {
      ++index;
      if (index >= SIZE(Trace_stream->past_lines)) goto done;
    }
    assert(index < SIZE(Trace_stream->past_lines));
    // render trace line at index
    trace_line& curr_line = Trace_stream->past_lines.at(index);
    ostringstream out;
    out << std::setw(4) << curr_line.depth << ' ' << curr_line.label << ": " << curr_line.contents;
    render_line(screen_row, out.str());
  }
done:
  // clear rest of screen
  for (; screen_row < tb_height(); ++screen_row) {
    render_line(screen_row, "~");
  }
  // move cursor back to display row at the end
  tb_set_cursor(0, Display_row);
  tb_present();
}

void render_line(int screen_row, const string& s) {
  long long int col = 0;
  for (col = 0; col < tb_width() && col < SIZE(s); ++col) {
    char c = s.at(col);
    if (c == '\n') c = ';';  // replace newlines with semi-colons
    tb_change_cell(col, screen_row, s.at(col), TB_WHITE, TB_DEFAULT);
  }
  for (; col < tb_width(); ++col) {
    tb_change_cell(col, screen_row, ' ', TB_WHITE, TB_DEFAULT);
  }
}

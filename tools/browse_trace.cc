// Warning: zero automated tests

// Includes
#include "termbox/termbox.h"

#include <stdlib.h>
#define SIZE(X) (assert((X).size() < (1LL<<(sizeof(int)*8-2))), static_cast<int>((X).size()))

#include <assert.h>
#include <iostream>
using std::istream;
using std::ostream;
using std::iostream;
using std::cin;
using std::cout;
using std::cerr;
#include <iomanip>
#include <string.h>
#include <string>
using std::string;
#include <vector>
using std::vector;
#include <set>
using std::set;
#include <sstream>
using std::ostringstream;
#include <fstream>
using std::ifstream;
using std::ofstream;
#include <map>
using std::map;
#include <utility>
using std::pair;
// End Includes

// Types
struct trace_line {
  string contents;
  string label;
  int depth;  // 0 is 'sea level'; positive integers are progressively 'deeper' and lower level
  trace_line(string c, string l, int d) {
    contents = c;
    label = l;
    depth = d;
  }
};

struct trace_stream {
  vector<trace_line> past_lines;
};

enum search_direction { FORWARD, BACKWARD };
// End Types

// from http://stackoverflow.com/questions/152643/idiomatic-c-for-reading-from-a-const-map
template<typename T> typename T::mapped_type& get(T& map, typename T::key_type const& key) {
  typename T::iterator iter(map.find(key));
  assert(iter != map.end());
  return iter->second;
}
template<typename T> typename T::mapped_type const& get(const T& map, typename T::key_type const& key) {
  typename T::const_iterator iter(map.find(key));
  assert(iter != map.end());
  return iter->second;
}
template<typename T> typename T::mapped_type const& put(T& map, typename T::key_type const& key, typename T::mapped_type const& value) {
  // map[key] requires mapped_type to have a zero-arg (default) constructor
  map.insert(std::make_pair(key, value)).first->second = value;
  return value;
}
template<typename T> bool contains_key(T& map, typename T::key_type const& key) {
  return map.find(key) != map.end();
}
template<typename T> typename T::mapped_type& get_or_insert(T& map, typename T::key_type const& key) {
  return map[key];
}

// Globals
trace_stream* Trace_stream = NULL;

ofstream Trace_file;
int Cursor_row = 0;  // screen coordinate
set<int> Visible;
int Top_of_screen = 0;  // trace coordinate
int Left_of_screen = 0;  // trace coordinate
int Last_printed_row = 0;  // screen coordinate
map<int, int> Trace_index;  // screen row -> trace index

string Current_search_pattern = "";
search_direction Current_search_direction = FORWARD;
// End Globals

bool has_data(istream& in) {
  return in && !in.eof();
}

void skip_whitespace_but_not_newline(istream& in) {
  while (true) {
    if (!has_data(in)) break;
    else if (in.peek() == '\n') break;
    else if (isspace(in.peek())) in.get();
    else break;
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
    Trace_stream->past_lines.push_back(trace_line(line, label, depth));
  }
  cerr << "lines read: " << Trace_stream->past_lines.size() << '\n';
}

void refresh_screen_rows() {  // Top_of_screen, Visible -> Trace_index
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

void clear_line(int screen_row) {  // -> screen
  tb_set_cursor(0, screen_row);
  for (int col = 0;  col < tb_width();  ++col)
    tb_print(' ', TB_WHITE, TB_BLACK);
  tb_set_cursor(0, screen_row);
}

int read_key() {
  tb_event event;
  do {
    tb_poll_event(&event);
  } while (event.type != TB_EVENT_KEY);
  return event.key ? event.key : event.ch;
}

int lines_hidden(int screen_row) {
  assert(contains_key(Trace_index, screen_row));
  if (!contains_key(Trace_index, screen_row+1))
    return SIZE(Trace_stream->past_lines) - get(Trace_index, screen_row);
  else
    return get(Trace_index, screen_row+1) - get(Trace_index, screen_row);
}

bool in_range(const vector<pair<size_t, size_t> >& highlight_ranges, size_t idx) {
  for (int i = 0;  i < SIZE(highlight_ranges);  ++i) {
    if (idx >= highlight_ranges.at(i).first && idx < highlight_ranges.at(i).second)
      return true;
    if (idx < highlight_ranges.at(i).second) break;
  }
  return false;
}

vector<pair<size_t, size_t> > find_all_occurrences(const string& s, const string& pat) {
  vector<pair<size_t, size_t> > result;
  if (pat.empty()) return result;
  size_t idx = 0;
  while (true) {
    size_t next_idx = s.find(pat, idx);
    if (next_idx == string::npos) break;
    result.push_back(pair<size_t, size_t>(next_idx, next_idx+SIZE(pat)));
    idx = next_idx+SIZE(pat);
  }
  return result;
}

int bg_color(int depth, int trace_index, int screen_row) {
  if (screen_row == Cursor_row) {
    if (trace_index == 0) return /*subtle grey*/240;  // ignore the zero-depth sentinel at start of trace
    if (depth > 0) return /*subtle grey*/240;
    else return /*subtle red*/88;
  }
  if (trace_index == 0) return TB_BLACK;  // ignore the zero-depth sentinel at start of trace
  if (depth == 0) return /*red*/1;
  if (depth == 1) return /*orange*/166;
  // start at black, gradually lighten at deeper levels
  if (depth > 10) return TB_BLACK + 16;
  return TB_BLACK + (depth - 2)*2;
}

void render_line(int screen_row, const string& s, int bg) {  // -> screen
  int col = 0;
  int color = TB_WHITE;
  vector<pair<size_t, size_t> > highlight_ranges = find_all_occurrences(s, Current_search_pattern);
  tb_set_cursor(0, screen_row);
  for (col = 0;  col < tb_width();  ++col) {
    char c = ' ';
    if (col+Left_of_screen < SIZE(s))
      c = s.at(col+Left_of_screen);  // todo: unicode
    if (c == '\n') c = ';';  // replace newlines with semi-colons
    // escapes. hack: can't start a line with them.
    if (c == '\1') { color = /*red*/1;  continue; }
    if (c == '\2') { color = TB_WHITE;  continue; }
    if (in_range(highlight_ranges, col+Left_of_screen))
      tb_print(c, TB_BLACK, /*yellow*/11);
    else
      tb_print(c, color, bg);
  }
}

void search_next(const string& pat) {
  for (int trace_index = get(Trace_index, Cursor_row)+1;  trace_index < SIZE(Trace_stream->past_lines);  ++trace_index) {
    if (!contains_key(Visible, trace_index)) continue;
    const trace_line& line = Trace_stream->past_lines.at(trace_index);
    if (line.label.find(pat) == string::npos && line.contents.find(pat) == string::npos) continue;
    Top_of_screen = trace_index;
    Cursor_row = 0;
    refresh_screen_rows();
    return;
  }
}

void search_previous(const string& pat) {
  for (int trace_index = get(Trace_index, Cursor_row)-1;  trace_index >= 0;  --trace_index) {
    if (!contains_key(Visible, trace_index)) continue;
    const trace_line& line = Trace_stream->past_lines.at(trace_index);
    if (line.label.find(pat) == string::npos && line.contents.find(pat) == string::npos) continue;
    Top_of_screen = trace_index;
    Cursor_row = 0;
    refresh_screen_rows();
    return;
  }
}

void search(const string& pat, search_direction dir) {
  if (dir == FORWARD) search_next(pat);
  else search_previous(pat);
}

search_direction opposite(search_direction dir) {
  if (dir == FORWARD) return BACKWARD;
  else return FORWARD;
}

bool start_search_editor(search_direction dir) {
  const int bottom_screen_line = tb_height()-1;
  // run a little editor just in the last line of the screen
  clear_line(bottom_screen_line);
  int col = 0;  // screen column of cursor on bottom line. also used to update pattern.
  tb_set_cursor(col, bottom_screen_line);
  tb_print('/', TB_WHITE, TB_BLACK);
  ++col;
  string pattern;
  while (true) {
    int key = read_key();
    if (key == TB_KEY_ENTER) {
      if (!pattern.empty()) {
        Current_search_pattern = pattern;
        Current_search_direction = dir;
      }
      return true;
    }
    else if (key == TB_KEY_ESC || key == TB_KEY_CTRL_C) {
      return false;
    }
    else if (key == TB_KEY_ARROW_LEFT) {
      if (col > /*slash*/1) {
        --col;
        tb_set_cursor(col, bottom_screen_line);
      }
    }
    else if (key == TB_KEY_ARROW_RIGHT) {
      if (col-/*slash*/1 < SIZE(pattern)) {
        ++col;
        tb_set_cursor(col, bottom_screen_line);
      }
    }
    else if (key == TB_KEY_HOME || key == TB_KEY_CTRL_A) {
      col = /*skip slash*/1;
      tb_set_cursor(col, bottom_screen_line);
    }
    else if (key == TB_KEY_END || key == TB_KEY_CTRL_E) {
      col = SIZE(pattern)+/*skip slash*/1;
      tb_set_cursor(col, bottom_screen_line);
    }
    else if (key == TB_KEY_BACKSPACE || key == TB_KEY_BACKSPACE2) {
      if (col > /*slash*/1) {
        assert(col <= SIZE(pattern)+1);
        --col;
        // update pattern
        pattern.erase(col-/*slash*/1, /*len*/1);
        // update screen
        tb_set_cursor(col, bottom_screen_line);
        for (int x = col;  x < SIZE(pattern)+/*skip slash*/1;  ++x)
          tb_print(pattern.at(x-/*slash*/1), TB_WHITE, TB_BLACK);
        tb_print(' ', TB_WHITE, TB_BLACK);
        tb_set_cursor(col, bottom_screen_line);
      }
    }
    else if (key == TB_KEY_CTRL_K) {
      int old_pattern_size = SIZE(pattern);
      pattern.erase(col-/*slash*/1, SIZE(pattern) - (col-/*slash*/1));
      tb_set_cursor(col, bottom_screen_line);
      for (int x = col;  x < old_pattern_size+/*slash*/1;  ++x)
        tb_print(' ', TB_WHITE, TB_BLACK);
      tb_set_cursor(col, bottom_screen_line);
    }
    else if (key == TB_KEY_CTRL_U) {
      int old_pattern_size = SIZE(pattern);
      pattern.erase(0, col-/*slash*/1);
      col = /*skip slash*/1;
      tb_set_cursor(col, bottom_screen_line);
      for (int x = /*slash*/1;  x < SIZE(pattern)+/*skip slash*/1;  ++x)
        tb_print(pattern.at(x-/*slash*/1), TB_WHITE, TB_BLACK);
      for (int x = SIZE(pattern)+/*slash*/1;  x < old_pattern_size+/*skip slash*/1;  ++x)
        tb_print(' ', TB_WHITE, TB_BLACK);
      tb_set_cursor(col, bottom_screen_line);
    }
    else if (key < 128) {  // ascii only
      // update pattern
      char c = static_cast<char>(key);
      assert(col-1 >= 0);
      assert(col-1 <= SIZE(pattern));
      pattern.insert(col-/*slash*/1, /*num*/1, c);
      // update screen
      for (int x = col;  x < SIZE(pattern)+/*skip slash*/1;  ++x)
        tb_print(pattern.at(x-/*slash*/1), TB_WHITE, TB_BLACK);
      ++col;
      tb_set_cursor(col, bottom_screen_line);
    }
  }
}

void render() {  // Trace_index -> Last_printed_row, screen
  int screen_row = 0;
  for (screen_row = 0;  screen_row < tb_height();  ++screen_row) {
    if (!contains_key(Trace_index, screen_row)) break;
    int trace_index = get(Trace_index, screen_row);
    trace_line& curr_line = Trace_stream->past_lines.at(trace_index);
    ostringstream out;
    if (screen_row < tb_height()-1) {
      int delta = lines_hidden(screen_row);
      // home-brew escape sequence for red
      if (delta > 1) {
        if (delta > 999) out << static_cast<char>(1);
        out << std::setw(6) << delta << "| ";
        if (delta > 999) out << static_cast<char>(2);
      }
      else {
        out << "        ";
      }
    }
    else {
      out << "        ";
    }
    out << std::setw(2) << curr_line.depth << ' ' << curr_line.label << ": " << curr_line.contents;
    int bg = bg_color(curr_line.depth, trace_index, screen_row);
    render_line(screen_row, out.str(), bg);
  }
  // clear rest of screen
  Last_printed_row = screen_row-1;
  for (;  screen_row < tb_height();  ++screen_row)
    render_line(screen_row, "~", /*bg*/TB_BLACK);
  // move cursor back to display row at the end
  tb_set_cursor(0, Cursor_row);
}

int main(int argc, char* argv[]) {
  if (argc != 2) {
    cerr << "Usage: browse_trace <trace file>\n";
    return 1;
  }
  load_trace(argv[1]);
  if (!Trace_stream) return 1;
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
  tb_clear();
  Cursor_row = 0;
  Top_of_screen = 0;
  refresh_screen_rows();
  while (true) {
    render();
    int key = read_key();
    if (key == 'q' || key == 'Q' || key == TB_KEY_CTRL_C) break;
    if (key == 'j' || key == TB_KEY_ARROW_DOWN) {
      // move cursor one line down
      if (Cursor_row < Last_printed_row) ++Cursor_row;
    }
    else if (key == 'k' || key == TB_KEY_ARROW_UP) {
      // move cursor one line up
      if (Cursor_row > 0) --Cursor_row;
    }
    else if (key == 't') {
      // move cursor to top of screen
      Cursor_row = 0;
    }
    else if (key == 'c') {
      // move cursor to center of screen
      Cursor_row = tb_height()/2;
      while (!contains_key(Trace_index, Cursor_row))
        --Cursor_row;
    }
    else if (key == 'b') {
      // move cursor to bottom of screen
      Cursor_row = tb_height()-1;
      while (!contains_key(Trace_index, Cursor_row))
        --Cursor_row;
    }
    else if (key == 'T') {
      // scroll line at cursor to top of screen
      Top_of_screen = get(Trace_index, Cursor_row);
      Cursor_row = 0;
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
        Cursor_row = 0;
        refresh_screen_rows();
    }
    else if (key == 'G' || key == TB_KEY_END) {
      // go to bottom of trace; largely like page-up, interestingly
      Top_of_screen = SIZE(Trace_stream->past_lines)-1;
      for (int screen_row = tb_height();  screen_row > 0 && Top_of_screen > 0;  --screen_row) {
        --Top_of_screen;
        if (Top_of_screen <= 0) break;
        while (Top_of_screen > 0 && !contains_key(Visible, Top_of_screen))
          --Top_of_screen;
      }
      refresh_screen_rows();
      render();
      // move cursor to bottom
      Cursor_row = Last_printed_row;
      refresh_screen_rows();
    }
    else if (key == TB_KEY_CARRIAGE_RETURN) {
      // expand lines under current by one level
      assert(contains_key(Trace_index, Cursor_row));
      int start_index = get(Trace_index, Cursor_row);
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
      assert(contains_key(Trace_index, Cursor_row));
      int start_index = get(Trace_index, Cursor_row);
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
    else if (key == '/') {
      if (start_search_editor(FORWARD))
        search(Current_search_pattern, Current_search_direction);
    }
    else if (key == '?') {
      if (start_search_editor(BACKWARD))
        search(Current_search_pattern, Current_search_direction);
    }
    else if (key == 'n') {
      if (!Current_search_pattern.empty())
        search(Current_search_pattern, Current_search_direction);
    }
    else if (key == 'N') {
      if (!Current_search_pattern.empty())
        search(Current_search_pattern, opposite(Current_search_direction));
    }
  }
  tb_clear();
  tb_shutdown();
  return 0;
}

#include<iostream>
using std::cout;
#include"termbox.h"

int main() {
  tb_init();
  std::setvbuf(stdout, NULL, _IONBF, 0);
  cout << tb_width() << ' ' << tb_height();
  tb_event x;
  for (int col = 0; col <= tb_width(); ++col) {
    tb_set_cursor(col, 1);
    tb_poll_event(&x);
    cout << "a";
    tb_poll_event(&x);
  }
  tb_shutdown();
  return 0;
}

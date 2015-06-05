#include<iostream>
#include"termbox.h"

int main() {
  tb_event event;
  tb_init();
  tb_poll_event(&event);
  tb_shutdown();
  std::cerr << (int)event.type << '\n';
  return 0;
}

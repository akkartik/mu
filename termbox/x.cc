#include<iostream>
#include"termbox.h"

int main() {
  tb_init();
  tb_event x;
  tb_poll_event(&x);
  std::cout << "a\nb\r\nc\r\n";
  tb_poll_event(&x);
  tb_shutdown();
  return 0;
}

#include<iostream>
#include"termbox.h"

int main() {
  tb_init();
  tb_clear();
  tb_change_cell(0, 0, 'a', TB_WHITE, TB_BLACK);
  tb_event x;
  tb_poll_event(&x);
  tb_shutdown();
  return 0;
}

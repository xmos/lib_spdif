// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include <xs1.h>
#include <stdint.h>
#include <stddef.h>
#include <spdif.h>
#include <debug_print.h>

port p_spdif_rx  = XS1_PORT_1F;
clock audio_clk  = XS1_CLKBLK_1;

void handle_samples(streaming chanend c)
{
  int32_t sample;
  size_t index;
  size_t left_count, right_count;
  while(1) {
    select {
    case spdif_receive_sample(c, sample, index):
      // sample contains the 24bit data
      // You can process the audio data here
      if (index == 0)
        left_count++;
      else
        right_count++;
      break;
    }
    size_t total = left_count + right_count;
    if (total % 10000 == 0) {
      debug_printf("Received %u left samples and %u right samples\n",
                   left_count,
                   right_count);
    }
  }
}

int main(void) {
    streaming chan c;
    par {
      spdif_rx(c, p_spdif_rx, audio_clk, 48000);
      handle_samples(c);
    }
    return 0;
}

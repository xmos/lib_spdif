// Copyright 2014-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>

#include "spdif.h"



void SpdifReceive(in buffered port:4 p, streaming chanend c, int initial_divider, clock clk);

void spdif_rx(streaming chanend c, in port p, clock clk,
              unsigned sample_freq_estimate)
{
  int initial_divider;
  in port * movable pp = &p;
  in buffered port:4 * movable pbuf = reconfigure_port(move(pp),
                                                       in buffered port:4);
  if (sample_freq_estimate > 96000) {
    initial_divider = 1;
  } else if (sample_freq_estimate > 48000) {
    initial_divider = 2;
  }
  else {
    initial_divider = 4;
  }
  SpdifReceive(*pbuf, c, initial_divider, clk);

  // Set pointers and ownership back to original state if SpdifReceive() exits
  pp = reconfigure_port(move(pbuf), in port);
}

void spdif_receive_sample(streaming chanend c, int32_t &sample, size_t &index)
{
  uint32_t v;
  c :> v;
  index = (v & 0xF) == SPDIF_FRAME_Y ? 1 : 0;
  sample = (v & ~0xF) << 4;
}

void spdif_receive_shutdown(streaming chanend c){
  soutct (c, XS1_CT_END);
}

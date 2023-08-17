// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <spdif.h>

#ifndef SAMPLE_FREQ_ESTIMATE
#define SAMPLE_FREQ_ESTIMATE 44100
#endif

on tile[0]: out             port    p_sim_out_high  = XS1_PORT_16A;
on tile[0]: out             port    p_sim_out_low   = XS1_PORT_16B;
on tile[0]: in              port    p_coax_rx       = XS1_PORT_1E;
on tile[0]:                 clock   audio_clk       = XS1_CLKBLK_1;

void handle_samples(streaming chanend c, out port p_sim_out_high,out port p_sim_out_low)
{
    int32_t sample;
    size_t index;
    uint32_t subframe;
    while(1)
    {  
        select
        {
        case c :> subframe:
            uint16_t high = subframe >> 16;
            uint16_t low = subframe & 0xFFFF;

            p_sim_out_high <: high;
            p_sim_out_low  <: low;
            break;
        }
    }
}

int main(void)
{
    streaming chan c;
    par {
        on tile[0]: spdif_rx(c, p_coax_rx, audio_clk, SAMPLE_FREQ_ESTIMATE);
        on tile[0]: handle_samples(c, p_sim_out_high, p_sim_out_low);
    }
    return 0;
}

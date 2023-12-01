// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>
#include <xclib.h>

#include "spdif.h"

void spdif_rx_sample(streaming chanend c, int32_t &sample, size_t &index)
{
    uint32_t v;
    c :> v;
    index = (v & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_Y ? 1 : 0;
    sample = SPDIF_RX_EXTRACT_SAMPLE(v);
}

void spdif_rx_shutdown(streaming chanend c)
{
    soutct(c, XS1_CT_END);

    // Drain channel
    while(!stestct(c))
        c :> unsigned tmp;

    sinct(c);
}

int spdif_rx_decode(streaming chanend c, buffered in port:32 p, unsigned sample_rate);
int check_clock_div(buffered in port:32 p);

void spdif_rx(streaming chanend c, in port p, clock clk, unsigned sample_freq_estimate)
{
    unsigned sample_rate = sample_freq_estimate;
    int exit = 0;

    in port * movable pp = &p;
    in buffered port:32 * movable p_buf = reconfigure_port(move(pp), in buffered port:32);

    // Configure spdif rx port to be clocked from spdif_rx clock defined below.
    configure_in_port(*p_buf, clk);

    while(1)
    {
        // Determine 100MHz clock divider
        unsigned clock_div = 96001/sample_rate;

        // Stop clock so we can reconfigure it
        stop_clock(clk);

        // Set the desired clock div
        configure_clock_ref(clk, clock_div);

        // Start the clock block running. Port timer will be reset here.
        start_clock(clk);

        // Check our clock div value is correct
        if (check_clock_div(*p_buf) == 0)
           exit = spdif_rx_decode(c, *p_buf, sample_rate);

        if(exit)
            break;

        // Get next sample rate from current sample rate.
        switch(sample_rate)
        {
            case 32000:  sample_rate = 44100;  break;
            case 44100:  sample_rate = 48000;  break;
            case 48000:  sample_rate = 88200;  break;
            case 88200:  sample_rate = 96000;  break;
            case 96000:  sample_rate = 176400; break;
            case 176400: sample_rate = 192000; break;
            case 192000: sample_rate = 32000;  break;
            default:     sample_rate = 48000;  break;
        }
    }

    // Set pointers and ownership back to original state if SpdifReceive() exits
    pp = reconfigure_port(move(p_buf), in port);
}


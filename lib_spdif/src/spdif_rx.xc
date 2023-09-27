// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>
#include <xclib.h>

#include "spdif.h"

void spdif_receive_sample(streaming chanend c, int32_t &sample, size_t &index)
{
    uint32_t v;
    c :> v;
    index = (v & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_Y ? 1 : 0;
    sample = (v & ~SPDIF_RX_PREAMBLE_MASK) << 4;
}

#if (LEGACY_SPDIF_RECEIVER)

void SpdifReceive(in buffered port:4 p, streaming chanend c, int initial_divider, clock clk);

void spdif_rx(streaming chanend c, in port p, clock clk, unsigned sample_freq_estimate)
{
    int initial_divider;
    in port * movable pp = &p;
    in buffered port:4 * movable pbuf = reconfigure_port(move(pp), in buffered port:4);
    if (sample_freq_estimate > 96000)
    {
        initial_divider = 1;
    }
    else if (sample_freq_estimate > 48000)
    {
        initial_divider = 2;
    }
    else
    {
        initial_divider = 4;
    }

    SpdifReceive(*pbuf, c, initial_divider, clk);

    // Set pointers and ownership back to original state if SpdifReceive() exits
    pp = reconfigure_port(move(pbuf), in port);
}

void spdif_receive_shutdown(streaming chanend c)
{
    soutct (c, XS1_CT_END);
}

#else

void spdif_rx_441(streaming chanend c, buffered in port:32 p);
void spdif_rx_48(streaming chanend c, buffered in port:32 p);
int check_clock_div(buffered in port:32 p);

void spdif_rx(streaming chanend c, buffered in port:32 p, clock clk, unsigned sample_freq_estimate)
{
    unsigned sample_rate = sample_freq_estimate;

    // Configure spdif rx port to be clocked from spdif_rx clock defined below.
    configure_in_port(p, clk);

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
        if (check_clock_div(p) == 0)
        {
            if(sample_rate % 44100)
                spdif_rx_48(c, p);
            else
                spdif_rx_441(c, p);
        }

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
}

#endif


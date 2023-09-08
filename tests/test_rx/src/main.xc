// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <spdif.h>
#include <debug_print.h>

#ifndef SAMPLE_FREQ_ESTIMATE
#define SAMPLE_FREQ_ESTIMATE 44100
#endif

#ifndef TEST_DTHREADS
#error TEST_DTHREADS not defined
#define TEST_DTHREADS (0)
#endif

#if (TEST_DTHREADS > 6)
#error TEST_DTHREADS too high
#endif

on tile[0]: out buffered    port:32 p_sim_out       = XS1_PORT_32A;
on tile[0]: in              port    p_coax_rx       = XS1_PORT_1E;
on tile[0]: out             port    p_strobe_out    = XS1_PORT_1F;
on tile[0]:                 clock   audio_clk       = XS1_CLKBLK_1;
on tile[0]:                 clock   c_out           = XS1_CLKBLK_2;  

void handle_samples(streaming chanend c, out buffered port:32 p_sim_out)
{
    configure_out_port_strobed_master(p_sim_out, p_strobe_out, c_out, 0);
    start_clock(c_out);
    uint32_t subframe;
    while(1)
    {
        c :> subframe;
        p_sim_out  <: subframe;
    }
}

size_t g_dummyThreadCount = TEST_DTHREADS;

void dummyThread()
{
    unsigned x = 0;
    set_core_fast_mode_on();

    while(g_dummyThreadCount)
    {
        x++;
    }
}

void dummyThreads()
{
#if (TEST_DTHREADS > 0)
    par(size_t i = 0; i < TEST_DTHREADS; i++)
    {
        dummyThread();
    }
#endif
}

int main(void)
{
    streaming chan c;
    par {
        on tile[0]: spdif_rx(c, p_coax_rx, audio_clk, SAMPLE_FREQ_ESTIMATE);
        on tile[0]: handle_samples(c, p_sim_out);
        on tile[0]: dummyThreads();
    }
    return 0;
}

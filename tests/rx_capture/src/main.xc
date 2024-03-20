// Copyright 2014-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <xscope.h>
#include <print.h>

#define ARRAY_LEN_0 130129
#define ARRAY_LEN_1 130409

#ifndef OPTICAL
#define OPTICAL 1
#endif

#if OPTICAL
on tile[0]: in  buffered    port:32 p_spdif_rx      = XS1_PORT_1O;
#else
on tile[0]: in  buffered    port:32 p_spdif_rx      = XS1_PORT_1N;
#endif

on tile[0]: in              port    p_word_clk      = XS1_PORT_1P;
on tile[0]: out             port    p_ctrl          = XS1_PORT_8D;
on tile[0]: in              port    p_i2c_sda       = XS1_PORT_1M;

void board_setup(void)
{
    // Define other tile 0 ports as inputs to avoid driving them when writing to 8 bit port.
    p_i2c_sda   :> void;
    p_spdif_rx  :> void;
    p_word_clk  :> void;

    // Drive control port to turn on 3V3 and set MCLK_DIR/EXT_PLL_SEL to select App PLL.
    p_ctrl <: 0xA0;

    // Wait for power supplies to be up and stable.
    delay_milliseconds(10);
}

void log_port(chanend c)
{
    xscope_mode_lossless();
    board_setup();

    unsigned sample[ARRAY_LEN_0];
    #pragma unsafe arrays
    for(unsigned i = 0; i < ARRAY_LEN_0; i++)
    {
        p_spdif_rx :> sample[i];
    }
    int val;

    for(unsigned i = 0; i < ARRAY_LEN_1; i++)
    {
        p_spdif_rx :> val;
        c <: val;
    }

    for(unsigned i = 0; i < ARRAY_LEN_0; i++)
    {
        printuintln(sample[i]);
    }
    c <: 0x1;
}

void extra_store(chanend c)
{
    xscope_mode_lossless();
    unsigned sample[ARRAY_LEN_1];
    #pragma unsafe arrays
    for(unsigned i = 0; i < ARRAY_LEN_1; i++)
    {
        c :> sample[i];
    }

    int done_printing;
    c :> done_printing;

    for(unsigned i = 0; i < ARRAY_LEN_1; i++)
    {
        printuintln(sample[i]);
    }
}

int main(void)
{
    chan c;
    par {
        on tile[0]: log_port(c);
        on tile[1]: extra_store(c);
    }
    return 0;
}

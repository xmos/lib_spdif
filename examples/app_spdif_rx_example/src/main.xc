// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <stdint.h>
#include <stddef.h>
#include <spdif.h>
#include <debug_print.h>

on tile[0]: out             port    p_ctrl          = XS1_PORT_8D;
on tile[0]: in              port    p_i2c_sda       = XS1_PORT_1M;
on tile[0]: in              port    p_coax_rx       = XS1_PORT_1N;
on tile[0]: in              port    p_opt_rx        = XS1_PORT_1O;
on tile[0]: in              port    p_word_clk      = XS1_PORT_1P;
on tile[0]:                 clock   audio_clk       = XS1_CLKBLK_1;

void handle_samples(streaming chanend c)
{
    int32_t sample;
    size_t index;
    size_t left_count, right_count;
    while(1)
    {
        select
        {
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

        if (total % 10000 == 0)
        {
            debug_printf("Received %u left samples and %u right samples\n",
                   left_count,
                   right_count);
        }
    }
}

void board_setup(void)
{
    // Define other tile 0 ports as inputs to avoid driving them when writing to 8 bit port.
    p_i2c_sda   :> void;
    p_coax_rx   :> void;
    p_opt_rx    :> void;
    p_word_clk  :> void;

    // Drive control port to turn on 3V3 and set MCLK_DIR/EXT_PLL_SEL to select App PLL.
    p_ctrl <: 0xA0;

    // Wait for power supplies to be up and stable.
    delay_milliseconds(10);
}

int main(void)
{
    streaming chan c;
    par {
        on tile[0]: {
            board_setup();
            spdif_rx(c, p_coax_rx, audio_clk, 96000);
        }
        on tile[0]: handle_samples(c);
    }
    return 0;
}

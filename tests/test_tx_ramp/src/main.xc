// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <spdif.h>
#include <stdlib.h>

on tile[1]: out buffered    port:32 p_spdif_tx      = XS1_PORT_1A;
on tile[1]: in              port    p_mclk_in       = XS1_PORT_1B;
on tile[1]: clock                   clk_audio       = XS1_CLKBLK_1;


#ifndef SAMPLE_FREQUENCY_HZ
#define SAMPLE_FREQUENCY_HZ 44100
#endif

#ifndef MCLK_FREQUENCY
#define MCLK_FREQUENCY 22579200
#endif

#ifndef CHAN_RAMP_0
#define CHAN_RAMP_0 0
#endif

#ifndef CHAN_RAMP_1
#define CHAN_RAMP_1 0
#endif

#ifndef NO_OF_SAMPLES
#define NO_OF_SAMPLES 0
#endif

void generate_samples(chanend c) {
    int lsample = 0;
    int rsample = 0;

    spdif_tx_reconfigure_sample_rate(c,
                                     SAMPLE_FREQUENCY_HZ,
                                     MCLK_FREQUENCY);

    for(int i = 0; i < NO_OF_SAMPLES; i++) {
        spdif_tx_output(c, lsample<<8, rsample<<8);
        lsample += CHAN_RAMP_0;
        rsample += CHAN_RAMP_1;
    }
    delay_microseconds(500);
    exit(0);
}

int main(void) {
    chan c_spdif;
    par
    {
        on tile[0]: {
            while(1) {};
        }
        on tile[1]: {
            spdif_tx_port_config(p_spdif_tx, clk_audio, p_mclk_in, 7);
            start_clock(clk_audio);
            spdif_tx(p_spdif_tx, c_spdif);
        }
        on tile[1]: generate_samples(c_spdif);
    }
    return 0;
}

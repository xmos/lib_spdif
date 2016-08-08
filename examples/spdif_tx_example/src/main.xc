// Copyright (c) 2014-2016, XMOS Ltd, All rights reserved

#include <xs1.h>
#include <platform.h>
#include <spdif.h>
#include <gpio.h>
#include <xassert.h>

on tile[0] : out port p_spdif_tx   = XS1_PORT_1B;
on tile[0] : in port p_mclk_in     = XS1_PORT_1E;
on tile[0] : clock clk_audio       = XS1_CLKBLK_1;

port port_gpio        = on tile[0]: XS1_PORT_4C;  // used for codec reset
                                                  // and clock select


#define SAMPLE_FREQUENCY_HZ 96000
#define MCLK_FREQUENCY_48  24576000

#define SINE_TABLE_SIZE 100
const int32_t sine_table[SINE_TABLE_SIZE] =
{
    0x0100da00,0x0200b000,0x02fe8100,0x03f94b00,0x04f01100,
    0x05e1da00,0x06cdb200,0x07b2aa00,0x088fdb00,0x09646600,
    0x0a2f7400,0x0af03700,0x0ba5ed00,0x0c4fde00,0x0ced5f00,
    0x0d7dd100,0x0e00a100,0x0e754b00,0x0edb5a00,0x0f326700,
    0x0f7a1800,0x0fb22700,0x0fda5b00,0x0ff28a00,0x0ffa9c00,
    0x0ff28a00,0x0fda5b00,0x0fb22700,0x0f7a1800,0x0f326700,
    0x0edb5a00,0x0e754b00,0x0e00a100,0x0d7dd100,0x0ced5f00,
    0x0c4fde00,0x0ba5ed00,0x0af03700,0x0a2f7400,0x09646600,
    0x088fdb00,0x07b2aa00,0x06cdb200,0x05e1da00,0x04f01100,
    0x03f94b00,0x02fe8100,0x0200b000,0x0100da00,0x00000000,
    0xfeff2600,0xfdff5000,0xfd017f00,0xfc06b500,0xfb0fef00,
    0xfa1e2600,0xf9324e00,0xf84d5600,0xf7702500,0xf69b9a00,
    0xf5d08c00,0xf50fc900,0xf45a1300,0xf3b02200,0xf312a100,
    0xf2822f00,0xf1ff5f00,0xf18ab500,0xf124a600,0xf0cd9900,
    0xf085e800,0xf04dd900,0xf025a500,0xf00d7600,0xf0056400,
    0xf00d7600,0xf025a500,0xf04dd900,0xf085e800,0xf0cd9900,
    0xf124a600,0xf18ab500,0xf1ff5f00,0xf2822f00,0xf312a100,
    0xf3b02200,0xf45a1300,0xf50fc900,0xf5d08c00,0xf69b9a00,
    0xf7702500,0xf84d5600,0xf9324e00,0xfa1e2600,0xfb0fef00,
    0xfc06b500,0xfd017f00,0xfdff5000,0xfeff2600,0x00000000,
};

void generate_samples(chanend c) {
    int i = 0;
    spdif_tx_reconfigure_sample_rate(c,
                                     SAMPLE_FREQUENCY_HZ, 
                                     MCLK_FREQUENCY_48);
    while(1) {
       // Generate a sine wave
       int sample = sine_table[i];
       i = (i + 1) % SINE_TABLE_SIZE;
       spdif_tx_output(c, sample, sample);
    }
}

void audio_tasks(client output_gpio_if gpio[2]) {
   chan c;
   gpio[0].output(1);
   gpio[1].output(1);
   configure_clock_src(clk_audio, p_mclk_in);
   spdif_tx_set_clock_delay(clk_audio);
   start_clock(clk_audio);
   par {
      spdif_tx(c, p_spdif_tx, clk_audio);
      generate_samples(c);
   }
}

int main(void) {
  interface output_gpio_if i_gpio[2];
  par {
    on tile[0]: audio_tasks(i_gpio);
    on tile[0]: output_gpio(i_gpio, 2, port_gpio, null);
  }
  return 0;
}

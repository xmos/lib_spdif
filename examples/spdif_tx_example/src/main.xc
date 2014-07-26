// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include <xs1.h>
#include <platform.h>
#include <spdif.h>
#include <i2c.h>
#include <xassert.h>

on tile[1] : out port p_spdif_tx   = XS1_PORT_1K;
on tile[1] : in port p_mclk_in     = XS1_PORT_1L;
on tile[1] : clock clk_audio       = XS1_CLKBLK_1;
on tile[1] : out port p_pll_clk    = XS1_PORT_4E;
on tile[1] : out port p_aud_cfg    = XS1_PORT_4A;
on tile[1] : port p_i2c_sclk       = XS1_PORT_1D;
on tile[1] : port p_i2c_sda        = XS1_PORT_1C;

#define SAMPLE_FREQUENCY_HZ 96000
#define MASTER_CLOCK_FREQUENCY_HZ 12288000
#define PLL_DEVICE_ADDR  0x9C
#define PLL_DIVIDE       300

/* Init of CS2300 */
void initialize_pll(client i2c_master_if i2c) {
    /* Enable init */
    i2c.write_reg(PLL_DEVICE_ADDR, 0x03, 0x07);
    i2c.write_reg(PLL_DEVICE_ADDR, 0x05, 0x01);
    i2c.write_reg(PLL_DEVICE_ADDR, 0x16, 0x10);
    // The following setting can be changed to 0x10 to always generate a
    // clock even when unlocked.
    i2c.write_reg(PLL_DEVICE_ADDR, 0x17, 0x00); 

    /* Check */
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x03) == 0x07);
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x05) == 0x01);
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x16) == 0x10);
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x17) == 0x00);
}

/* Setup PLL multiplier */
void configure_pll(client i2c_master_if i2c, unsigned mult) {
    /* Multiplier is translated to 20.12 format by shifting left by 12 */

    i2c.write_reg(PLL_DEVICE_ADDR, 0x06, (mult >> 12) & 0xFF);
    i2c.write_reg(PLL_DEVICE_ADDR, 0x07, (mult >> 4) & 0xFF);
    i2c.write_reg(PLL_DEVICE_ADDR, 0x08, (mult << 4) & 0xFF);
    i2c.write_reg(PLL_DEVICE_ADDR, 0x09, 0x00);

    /* Check */
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x06) == ((mult >> 12) & 0xFF));
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x07) == ((mult >> 4) & 0xFF));
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x08) == ((mult << 4) & 0xFF));
    assert(i2c.read_reg(PLL_DEVICE_ADDR, 0x09) == 0x00);
}

void generate_pll_clock(out port p_pll_clk, out port p_aud_cfg) 
{
   unsigned pinVal = 0;
   timer t;
   unsigned time;
   unsigned half_clk_period = (100000000 / PLL_DIVIDE / 2);
   t :> time;
   p_aud_cfg <: 0;
   p_pll_clk <: pinVal;

   while(1) {
     select {
     case t when timerafter(time) :> void:
       pinVal = !pinVal;
       p_pll_clk <: pinVal;
       time += half_clk_period;
       break;
     }
   }
}

#define WAVE_LEN 512
void generate_samples(chanend c) {
    int i = 0;
    spdif_tx_reconfigure_sample_rate(c,
                                     SAMPLE_FREQUENCY_HZ, 
                                     MASTER_CLOCK_FREQUENCY_HZ);
    while(1) {
       // Generate a triangle wave
       int sample = i;
       if (i > (WAVE_LEN / 4)) {
          // After the first quarter of the cycle
          sample = (WAVE_LEN / 2) - i;
       }
       if (i > (3 * WAVE_LEN / 4)) {
          // In the last quarter of the cycle
          sample = i - WAVE_LEN;
       }
       sample <<= 23; // Shift to highest but 1 bits

       spdif_tx_output(c, sample, sample);

       i++;
       i %= WAVE_LEN;
    }
}

void audio_tasks(client i2c_master_if i2c) {
   chan c;
   initialize_pll(i2c);
   configure_pll(i2c, MASTER_CLOCK_FREQUENCY_HZ / PLL_DIVIDE);
   configure_clock_src(clk_audio, p_mclk_in);
   spdif_tx_set_clock_delay(clk_audio);
   start_clock(clk_audio);
   par {
      spdif_tx(c, p_spdif_tx, clk_audio);
      generate_samples(c);
      generate_pll_clock(p_pll_clk, p_aud_cfg);
   }
}

int main(void) {
  interface i2c_master_if i_i2c[1];
  par {
    on tile[1]: audio_tasks(i_i2c[0]);
    on tile[1]: i2c_master(i_i2c, 1, p_i2c_sda, p_i2c_sclk, 100000,
                           I2C_DISABLE_MULTIMASTER);
  }
  return 0;
}

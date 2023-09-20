// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <spdif.h>
#include <xassert.h>

on tile[0]: out             port    p_ctrl          = XS1_PORT_8D;
on tile[0]: in              port    p_i2c_sda       = XS1_PORT_1M;
on tile[0]: in              port    p_coax_rx       = XS1_PORT_1N;
on tile[0]: in              port    p_opt_rx        = XS1_PORT_1O;
on tile[0]: in              port    p_word_clk      = XS1_PORT_1P;

on tile[1]: out buffered    port:32 p_spdif_tx      = XS1_PORT_1A;
on tile[1]: in              port    p_mclk_in       = XS1_PORT_1D;
on tile[1]: clock                   clk_audio       = XS1_CLKBLK_1;

// Found solution: IN 24.000MHz, OUT 24.576000MHz, VCO 2457.60MHz, RD 1, FD 102.400 (m = 2, n = 5), OD 5, FOD 5, ERR 0.0ppm
// Measure: 100Hz-40kHz: ~8ps
// 100Hz-1MHz: 63ps.
// 100Hz high pass: 127ps.
#define APP_PLL_CTL_24M  0x0A006500
#define APP_PLL_DIV_24M  0x80000004
#define APP_PLL_FRAC_24M 0x80000104

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

// Set secondary (App) PLL control register safely to work around chip bug.
void set_app_pll_init (tileref tile, int app_pll_ctl)
{
    // delay_microseconds(500);
    // Disable the PLL
    write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, (app_pll_ctl & 0xF7FFFFFF));
    // Enable the PLL to invoke a reset on the appPLL.
    write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, app_pll_ctl);
    // Must write the CTL register twice so that the F and R divider values are captured using a running clock.
    write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, app_pll_ctl);
    // Now disable and re-enable the PLL so we get the full 5us reset time with the correct F and R values.
    write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, (app_pll_ctl & 0xF7FFFFFF));
    write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, app_pll_ctl);
    // Wait for PLL to lock.
    delay_microseconds(500);
}

void app_pll_setup(void)
{
    set_app_pll_init(tile[0], APP_PLL_CTL_24M);
    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, APP_PLL_FRAC_24M);
    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM, APP_PLL_DIV_24M);
}

void board_setup(void)
{
    //////// BOARD SETUP ////////

    // Define other tile 0 ports as inputs to avoid driving them when writing to 8 bit port.
    p_i2c_sda   :> void;
    p_coax_rx   :> void;
    p_opt_rx    :> void;
    p_word_clk  :> void;

    // Drive control port to turn on 3V3 and set MCLK_DIR/EXT_PLL_SEL to select App PLL.
    p_ctrl <: 0xA0;

    // Wait for power supplies to be up and stable.
    delay_milliseconds(10);

    /////////////////////////////
}

int main(void) {

    chan c_spdif;
    par
    {
        on tile[0]: {
            board_setup();
            app_pll_setup();
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

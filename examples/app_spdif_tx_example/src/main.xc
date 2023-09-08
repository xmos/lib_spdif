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

#define SAMPLE_FREQUENCY_HZ 48000
#define MCLK_FREQUENCY_48  24576000



void generate_samples(chanend c) {
    int i = 0;
    spdif_tx_reconfigure_sample_rate(c,
                                     SAMPLE_FREQUENCY_HZ,
                                     MCLK_FREQUENCY_48);

    int sample_l = 0xEC8137FF;
    int sample_r = 0x137EC8FF;
    while(1) {
       // Generate a sine wave
       spdif_tx_output(c, sample_l, sample_r);
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

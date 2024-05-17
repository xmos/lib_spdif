// Copyright 2014-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <stdint.h>
#include <stddef.h>
#include <spdif.h>
#include <stdio.h>
#include <print.h>

extern "C" {
    #include <sw_pll.h>
}

// Change these defines to control optical/coax and set the sample frequency.
#ifndef OPTICAL
#define OPTICAL               (0)
#endif

#define SAMPLE_FREQUENCY_HZ   (192000)

#if(OPTICAL)
on tile[0]: in                port    p_spdif_rx      = XS1_PORT_1O; // Optical rx
on tile[1]: out buffered      port:32 p_spdif_tx      = XS1_PORT_1G; // Optical tx
#else
on tile[0]: in                port    p_spdif_rx      = XS1_PORT_1N; // Coaxial rx
on tile[1]: out buffered      port:32 p_spdif_tx      = XS1_PORT_1A; // Coaxial tx
#endif

on tile[0]: out               port    p_ctrl          = XS1_PORT_8D;
on tile[0]:                   clock   clk_spdif_rx    = XS1_CLKBLK_1;
on tile[1]: in                port    p_mclk_in       = XS1_PORT_1D;
on tile[1]:                   clock   clk_spdif_tx    = XS1_CLKBLK_1;

#define MCLK_FREQUENCY_48     (24576000)
#define MCLK_FREQUENCY_441    (22579200)

// One cycle of full scale 24 bit sine wave in 96 samples.
// This will produce 500Hz signal at Fs = 48kHz, 1kHz at 96kHz and 2kHz at 192kHz.
const int32_t sine_table1[96] =
{
    0x000000,0x085F21,0x10B515,0x18F8B8,0x2120FB,0x2924ED,0x30FBC5,0x389CEA,
    0x3FFFFF,0x471CEC,0x4DEBE4,0x546571,0x5A8279,0x603C49,0x658C99,0x6A6D98,
    0x6ED9EB,0x72CCB9,0x7641AE,0x793501,0x7BA374,0x7D8A5E,0x7EE7A9,0x7FB9D6,
    0x7FFFFF,0x7FB9D6,0x7EE7A9,0x7D8A5E,0x7BA374,0x793501,0x7641AE,0x72CCB9,
    0x6ED9EB,0x6A6D98,0x658C99,0x603C49,0x5A8279,0x546571,0x4DEBE4,0x471CEC,
    0x3FFFFF,0x389CEA,0x30FBC5,0x2924ED,0x2120FB,0x18F8B8,0x10B515,0x085F21,
    0x000000,0xF7A0DF,0xEF4AEB,0xE70748,0xDEDF05,0xD6DB13,0xCF043B,0xC76316,
    0xC00001,0xB8E314,0xB2141C,0xAB9A8F,0xA57D87,0x9FC3B7,0x9A7367,0x959268,
    0x912615,0x8D3347,0x89BE52,0x86CAFF,0x845C8C,0x8275A2,0x811857,0x80462A,
    0x800001,0x80462A,0x811857,0x8275A2,0x845C8C,0x86CAFF,0x89BE52,0x8D3347,
    0x912615,0x959268,0x9A7367,0x9FC3B7,0xA57D87,0xAB9A8F,0xB2141C,0xB8E314,
    0xC00001,0xC76316,0xCF043B,0xD6DB13,0xDEDF05,0xE70748,0xEF4AEB,0xF7A0DF
};

// Two cycles of full scale 24 bit sine wave in 96 samples.
// This will produce 1kHz signal at Fs = 48kHz, 2kHz at 96kHz and 4kHz at 192kHz.
const int32_t sine_table2[96] =
{
    0x000000,0x10B515,0x2120FB,0x30FBC5,0x3FFFFF,0x4DEBE4,0x5A8279,0x658C99,
    0x6ED9EB,0x7641AE,0x7BA374,0x7EE7A9,0x7FFFFF,0x7EE7A9,0x7BA374,0x7641AE,
    0x6ED9EB,0x658C99,0x5A8279,0x4DEBE4,0x3FFFFF,0x30FBC5,0x2120FB,0x10B515,
    0x000000,0xEF4AEB,0xDEDF05,0xCF043B,0xC00001,0xB2141C,0xA57D87,0x9A7367,
    0x912615,0x89BE52,0x845C8C,0x811857,0x800001,0x811857,0x845C8C,0x89BE52,
    0x912615,0x9A7367,0xA57D87,0xB2141C,0xC00001,0xCF043B,0xDEDF05,0xEF4AEB,
    0x000000,0x10B515,0x2120FB,0x30FBC5,0x3FFFFF,0x4DEBE4,0x5A8279,0x658C99,
    0x6ED9EB,0x7641AE,0x7BA374,0x7EE7A9,0x7FFFFF,0x7EE7A9,0x7BA374,0x7641AE,
    0x6ED9EB,0x658C99,0x5A8279,0x4DEBE4,0x3FFFFF,0x30FBC5,0x2120FB,0x10B515,
    0x000000,0xEF4AEB,0xDEDF05,0xCF043B,0xC00001,0xB2141C,0xA57D87,0x9A7367,
    0x912615,0x89BE52,0x845C8C,0x811857,0x800001,0x811857,0x845C8C,0x89BE52,
    0x912615,0x9A7367,0xA57D87,0xB2141C,0xC00001,0xCF043B,0xDEDF05,0xEF4AEB
};

void generate_samples(chanend c, chanend c_sync)
{
    int mclk;
    int exit = 0;

    if ((SAMPLE_FREQUENCY_HZ % 44100) == 0)
    {
        mclk = MCLK_FREQUENCY_441;
    }
    else
    {
        mclk = MCLK_FREQUENCY_48;
    }

    printf("Generating S/PDIF samples at %dHz\n", SAMPLE_FREQUENCY_HZ);
    spdif_tx_reconfigure_sample_rate(c,SAMPLE_FREQUENCY_HZ, mclk);

    while(!exit)
    {
        for(int i = 0; i < (sizeof(sine_table1)/sizeof(sine_table1[0])); i++)
        {
            // Generate a sine wave
            int sample_l = sine_table1[i] << 8;
            int sample_r = sine_table2[i] << 8; // Twice the frequency on right channel.
            spdif_tx_output(c, sample_l, sample_r);
        }

        /* Check for exit */
        select
        {
            case c_sync :> int tmp:
                exit = 1;
                break;

            default:
                break;
        }
    }
}

#pragma unsafe arrays
void handle_samples(streaming chanend c, chanend c_sync)
{
    unsigned tmp;
    unsigned outwords[20000] = {0};

    // Check for a stream of alternating preambles before trying decode.
    int alt_pre_count = 0;
    while(alt_pre_count < 128)
    {
        c :> tmp;
        if ((tmp & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_X) // X
        {
            c :> tmp;
            if ((tmp & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_Y) // Y
                alt_pre_count++;
            else
                alt_pre_count = 0;
        }
        else
        {
            alt_pre_count = 0;
        }
    }

    // Collecting samples
    for(int i = 0; i<20000;i++)
    {
        c :> tmp;
        outwords[i] = tmp;
    }

    #define CHAN_STAT_44100    (0x00000000)
    #define CHAN_STAT_48000    (0x02000000)
    #define CHAN_STAT_88200    (0x08000000)
    #define CHAN_STAT_96000    (0x0A000000)
    #define CHAN_STAT_176400   (0x0C000000)
    #define CHAN_STAT_192000   (0x0E000000)

    // Known channel status block data. Needs sample rate bits OR'ing in.
    unsigned cs_block_l[6] = {0x00107A04, 0x0000000B, 0x00000000, 0x00000000, 0x00000000, 0x00000000};
    unsigned cs_block_r[6] = {0x00207A04, 0x0000000B, 0x00000000, 0x00000000, 0x00000000, 0x00000000};

    // Or in the sampling frequency bits into the channel status block.
    switch(SAMPLE_FREQUENCY_HZ)
    {
        //case 32000:
        case 44100:  cs_block_l[0] |= CHAN_STAT_44100;  cs_block_r[0] |= CHAN_STAT_44100;   break;
        case 48000:  cs_block_l[0] |= CHAN_STAT_48000;  cs_block_r[0] |= CHAN_STAT_48000;   break;
        case 88200:  cs_block_l[0] |= CHAN_STAT_88200;  cs_block_r[0] |= CHAN_STAT_88200;   break;
        case 96000:  cs_block_l[0] |= CHAN_STAT_96000;  cs_block_r[0] |= CHAN_STAT_96000;   break;
        case 176400: cs_block_l[0] |= CHAN_STAT_176400; cs_block_r[0] |= CHAN_STAT_176400;  break;
        case 192000: cs_block_l[0] |= CHAN_STAT_192000; cs_block_r[0] |= CHAN_STAT_192000;  break;
        default:     cs_block_l[0] |= CHAN_STAT_44100;  cs_block_r[0] |= CHAN_STAT_44100;   break;
    }

    // Manually parse the output words to look for errors etc.
    // Based on known TX samples.
    unsigned errors = 0;
    unsigned ok = 0;
    unsigned block_count = 0;
    unsigned block_size_errors = 0;
    int i_last =0;

    for(int i=0; i<20000; i++)
    {
        unsigned pre = outwords[i] & SPDIF_RX_PREAMBLE_MASK;

        if (pre == SPDIF_FRAME_Z) // Z preamble
        {
            if (i+384 >= 20000)
                break;

            if (block_count > 0)
            {
                if ((i-i_last) != 384)
                {
                  printf("Error - Block not 384 samples in length\n");
                  block_size_errors++;
                }
            }

            block_count++;
            i_last = i;
            unsigned expected = 0;
            unsigned rx_word;
            unsigned expected_cs_bit;
            unsigned expected_parity_bit;

            for(int j=0; j<384;j++)
            {
                rx_word = outwords[i+j];
                unsigned index = j/2;
                if (j%2 == 0) // Even
                {
                    if (j == 0)
                        expected = (sine_table1[index % 96] << 4) | SPDIF_FRAME_Z;
                    else
                        expected = (sine_table1[index % 96] << 4) | SPDIF_FRAME_X;
                    expected_cs_bit = (cs_block_l[index/32] & (0x1 << (index%32))) >> (index%32);
                }
                else // Odd
                {
                    expected = (sine_table2[index % 96] << 4) | SPDIF_FRAME_Y;
                    expected_cs_bit = (cs_block_r[index/32] & (0x1 << (index%32))) >> (index%32);
                }
                expected |= expected_cs_bit << 30;
                expected_parity_bit = spdif_rx_check_parity(expected); // Parity is over all bits excluding preamble.
                expected |= expected_parity_bit << 31;
                // Note in tx stream, Validity and User bits both 0.
                unsigned checkword = rx_word & (0xFFFFFFF0 | SPDIF_RX_PREAMBLE_MASK);
                if (checkword != expected)
                {
                    errors++;
                    //printf("Error checkword 0x%08X, expected 0x%08X, i %d, j %d\n", checkword, expected, i, j);
                }
                else
                {
                    ok++;
                    //printf("OK    checkword 0x%08X, expected 0x%08X, i %d, j %d\n", checkword, expected, i, j);
                }

            }
        }
    }
    printf("Checked %d channel status blocks of samples. Expected number of samples = %d.\n", block_count, (block_count*384));
    printf("Error count %d, block size errors %d, ok samples count %d\n", errors, block_size_errors, ok);

    /* Inform generate task that this task has finished */
    c_sync <: (int) 1;
}

void board_setup(void)
{
    set_port_drive_high(p_ctrl);

    // Drive control port to turn on 3V3.
    // Bits set to low will be high-z, pulled down.
    p_ctrl <: 0xA0;

    // Wait for power supplies to be up and stable.
    delay_milliseconds(10);

    if ((SAMPLE_FREQUENCY_HZ % 44100) == 0)
    {
        sw_pll_fixed_clock(MCLK_FREQUENCY_441);
    }
    else
    {
        sw_pll_fixed_clock(MCLK_FREQUENCY_48);
    }
    delay_milliseconds(10);
}

int main(void)
{
    chan c_spdif_tx;
    streaming chan c_spdif_rx;
    chan c_sync;

    par
    {
        on tile[0]:
        {
            board_setup();
            spdif_rx(c_spdif_rx, p_spdif_rx, clk_spdif_rx, SAMPLE_FREQUENCY_HZ);
        }

        on tile[0]:
        {
            handle_samples(c_spdif_rx, c_sync);
            spdif_rx_shutdown(c_spdif_rx);
        }

        on tile[1]:
        {
            spdif_tx_port_config(p_spdif_tx, clk_spdif_tx, p_mclk_in, 0);
            start_clock(clk_spdif_tx);
            spdif_tx(p_spdif_tx, c_spdif_tx);
        }

        on tile[1]:
        {
            generate_samples(c_spdif_tx, c_sync);
            spdif_tx_shutdown(c_spdif_tx);
        }
    }
    return 0;
}


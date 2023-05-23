// Copyright 2011-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/**
 * @file    SpditTransmit.xc
 * @brief   S/PDIF line transmitter
 * @author  XMOS
 *
 * Uses a master clock to output S/PDIF encoded samples.
 */

#include <xs1.h>
#include <print.h>
#include <xclib.h>
#include "assert.h"
#include "spdif.h"

/* Validity bit (x<<28) - the validity bit is set to 0 if the data is reliable and 1 if it is not.*/
#define	VALIDITY 		(0x00000000)

void spdif_tx_port_config(out buffered port:32 p, clock clk, in port p_mclk, unsigned delay)
{
    assert(delay < 512);

    /* Clock clock block from master-clock */
    configure_clock_src(clk, p_mclk);

    /* Clock S/PDIF tx port from MClk */
    configure_out_port_no_ready(p, clk, 0);

    /* Set delay to align SPDIF output to the clock at the external flop */
    set_clock_fall_delay(clk, delay);

    /* Note, we so not start the clock to allow sharing of the clock-block */
    //start_clock(clk);
}

/* Returns parity for a given word */
static unsigned inline parity32(unsigned x)
{
    crc32(x, 0, 1);
    return (x & 1);
}

// Three preambles
// preamble[0] = 0x17 => "Z" - Block start & Sub-frame 1
// preamble[1] = 0x47 => "X" - Sub-frame 1
// preamble[2] = 0x27 => "Y" - Sub-frame 2

char preamble[3] = {0x17, 0x47, 0x27};

// This encodes 16 input data bits into 32 biphase mark bits.
// 16 input bits must be in the LS 16 bits of the 32 bit input.
// Serial stream progresses from LSB first to MSB last for input and output.
// The previous biphase mark encoded bit is assumed to be 0, if 1, simply invert output.
static inline unsigned biphase_encode(unsigned data_in)
{
    unsigned poly = ~data_in << 16;
    unsigned residual = 0x0000FFFF;
    crcn(residual, 0, poly, 16);
    return zip(residual >> 1, ~residual, 0);
}

static inline void output_word(out buffered port:32 p, unsigned encoded_word, int divide)
{
    switch(divide)
    {
        case 1:
            /* Highest sample freq supported by mclk freq, eg: 24 -> 192 */
            p <: encoded_word; // Output the encoded data to the port;
            break;
        case 2:
            /* E.g. 24 -> 96 */
            unsigned long long tmp;
            tmp = zip(encoded_word, encoded_word, 0); // Make a 64 bit word from two copies of 32 bit input word
            p <: (unsigned int) tmp; // Output LS 32 bits
            p <: (unsigned int) (tmp >> 32); // Output MS 32 bits
            break;
        case 4:
            /* E.g. 24MHz -> 48kHz */
            unsigned long long tmp, final;
            unsigned tmp_0, tmp_1;
            tmp = zip(encoded_word, encoded_word, 0); // Make a 64 bit word from two copies of 32 bit input word
            tmp_0 = (unsigned int) tmp; // LS 32 bits
            final = zip(tmp_0, tmp_0, 1); // Make a 64 bit word from two copies of 32 bit input word
            p <: (unsigned int) final;
            p <: (unsigned int) (final >> 32);
            tmp_1 = (unsigned int) (tmp >> 32); // MS 32 bits
            final = zip(tmp_1, tmp_1, 1); // Make a 64 bit word from two copies of 32 bit input word
            p <: (unsigned int) final;
            p <: (unsigned int) (final >> 32);
            break;
        default:
            /* Mclk does not support required sample freq */
            break;
    }
}

#pragma unsafe arrays
static inline void subframe_tx(out buffered port:32 p, unsigned sample_in, int ctrl, int preamble_type, int divide)
{
    static int lastbit = 0;
    unsigned word, sample, control, parity;
    sample = sample_in >> 4 & 0x0FFFFFF0; /* Mask and shift to be in the correct place in the Sub-frame */
    control = (ctrl & 1) << 30;
    parity = parity32(sample | control | VALIDITY) << 31;
    word = sample | control | parity | VALIDITY;

    /* Preamble */
    unsigned char encoded_preamble = preamble[preamble_type];

    if(lastbit == 1) 
    {
        encoded_preamble ^= 0xFF;  // invert all bits of the encoded preamble
    }
    // Don't need to update lastbit here as due to pattern of preamble bits it is never changed.
    
    word = word >> 4; // We've finished with the preamble
    
    /* Next 12 bits of subframe word */
    unsigned encoded_word = biphase_encode(word & 0xFFF);
    if(lastbit == 1) 
    {
        encoded_word = ~encoded_word;  // invert all bits of the encoded word
    }
    encoded_word = (encoded_word << 8) | encoded_preamble;
    
    // Now we do need to update lastbit to see if the last bit we're sending was 1 or 0.
    lastbit = encoded_word >> 31;
    output_word(p, encoded_word, divide);
    
    word = word >> 12; // Shift the word down the 12 bits we've just output.
    
    /* Remaining 16 bits of subframe word (we've shifted right by 4 and then 12 so only bottom 16 still remaining) */
    encoded_word = biphase_encode(word);
    if(lastbit == 1) 
    {
        encoded_word = ~encoded_word;  // invert all bits of the encoded word
    }

    // Now we do need to update lastbit to see if the last bit we're sending was 1 or 0.
    lastbit = encoded_word >> 31;
    output_word(p, encoded_word, divide);
}

void SpdifTransmit(out buffered port:32 p, chanend c_tx0, const int ctrl_left[2], const int ctrl_right[2], int divide)
{
    unsigned sample_l, sample_r;

    /* Check for new frequency */
    if(testct(c_tx0))
    {
        chkct(c_tx0, XS1_CT_END);
        return;
    }

    /* Get L/R samples */
    sample_l = inuint(c_tx0);
    sample_r = inuint(c_tx0);

#pragma unsafe arrays
    while (1)
    {
        int controlLeft  = ctrl_left[0];
        int controlRight = ctrl_right[0];

        for(int i = 0 ; i < 192; i++)
        {
            /* Sub-frame 1 */
            if(i == 0) 
            {
                subframe_tx(p, sample_l, controlLeft, 0, divide);  // Block start & Sub-frame 1
            }
            else 
            {
                subframe_tx(p, sample_l, controlLeft, 1, divide); // Sub-frame 1
            }

            controlLeft >>=1;

            /* Sub-frame 2 */
            subframe_tx(p, sample_r, controlRight, 2, divide);

            controlRight >>=1;

            /* Test for new frequency */
            if(testct(c_tx0))
            {
                chkct(c_tx0, XS1_CT_END);
                return;
            }

            /* Get new samples... */
            sample_l = inuint(c_tx0);
            sample_r = inuint(c_tx0);

            if(i == 31) 
            {
                controlLeft = ctrl_left[1];
                controlRight = ctrl_right[1];
            }
        }
    }
}

void SpdifTransmitError(chanend c_in)
{
    while(1)
    {
        /* Keep swallowing samples until we get a sample frequency change */
        if (testct(c_in))
        {
            chkct(c_in, XS1_CT_END);
            return;
        }

        inuint(c_in);
        inuint(c_in);
    }
}

/* Defines for building channel status words */
#define CHAN_STAT_L        (0x00107A04)
#define CHAN_STAT_R        (0x00207A04)

#define CHAN_STAT_44100    (0x00000000)
#define CHAN_STAT_48000    (0x02000000)
#define CHAN_STAT_88200    (0x08000000)
#define CHAN_STAT_96000    (0x0A000000)
#define CHAN_STAT_176400   (0x0C000000)
#define CHAN_STAT_192000   (0x0E000000)

#define CHAN_STAT_WORD_2   (0x0000000B)

/* S/PDIF transmit thread */
void spdif_tx(buffered out port:32 p, chanend c_in)
{
    chkct(c_in, XS1_CT_END);
    while (1)
    {
        int chanStat_L[2], chanStat_R[2];
        unsigned divide;
        /* Receive sample frequency over channel (in Hz) */
        unsigned  samFreq = inuint(c_in);

        /* Receive master clock frequency over channel (in Hz) */
        unsigned  mclkFreq = inuint(c_in);

        /* Create channel status words based on sample freq */
        switch(samFreq)
        {
            case 44100:
                chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_44100;
                chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_44100;
                break;

            case 48000:
                chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_48000;
                chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_48000;
                break;

            case 88200:
                chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_88200;
                chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_88200;
                break;

            case 96000:
                chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_96000;
                chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_96000;
                break;

            case 176400:
                chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_176400;
                chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_176400;
                break;

            case 192000:
                chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_192000;
                chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_192000;
                break;

            default:
                /* Sample frequency not recognised.. carry on for now... */
                chanStat_L[0] = CHAN_STAT_L;
                chanStat_R[0] = CHAN_STAT_R;
                break;

        }
        chanStat_L[1] = CHAN_STAT_WORD_2;
        chanStat_R[1] = CHAN_STAT_WORD_2;

        /* Calculate required divide */
        divide = mclkFreq / (samFreq * 2 * 32 * 2);

        SpdifTransmit(p, c_in, chanStat_L, chanStat_R, divide);
    }
}

void spdif_tx_reconfig_port(chanend c, out port p_spdif, const clock mclk)
{
    out port * movable pp = &p_spdif;
    out buffered port:32 * movable pbuf = reconfigure_port(move(pp), out buffered port:32);
    /* Clock S/PDIF tx port from MClk */
    configure_out_port_no_ready(*pbuf, mclk, 0);
    spdif_tx(*pbuf, c);
}

void spdif_tx_output(chanend c, unsigned l, unsigned r)
{
    outuint(c, l);
    outuint(c, r);
}

void spdif_tx_reconfigure_sample_rate(chanend c,
                                      unsigned sample_frequency,
                                      unsigned master_clock_frequency)
{
    outct(c, XS1_CT_END);
    outuint(c, sample_frequency);
    outuint(c, master_clock_frequency);
}

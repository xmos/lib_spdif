// Copyright 2011-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/**
 * @file    SpditTransmit.xc
 * @brief   S/PDIF line transmitter
 * @author  XMOS
 *
 * Uses a master clock to output S/PDIF encoded samples.
 */

#include <xs1.h>
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

    /* Set delay to align S/PDIF output to the clock at the external flop */
    set_clock_fall_delay(clk, delay);

    /* Note, we do not start the clock to allow sharing of the clock-block */
    //start_clock(clk);
}

/* Returns parity for a given word */
static unsigned inline parity32(unsigned x)
{
    crc32(x, 0, 1);
    return (x & 1);
}

// Three preambles
#define SPDIF_PREAMBLE_Z (0x17) // Block start & Sub-frame 1
#define SPDIF_PREAMBLE_X (0x47) // Sub-frame 1
#define SPDIF_PREAMBLE_Y (0x27) // Sub-frame 2

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

// Takes the least significant 16 bits of inword, maps each input bit to 6 output bits to produce three 32 bit words which are output to the port.
#pragma unsafe arrays
static inline void zip_out_6(out buffered port:32 p, unsigned inword)
{
    unsigned outword[3] = {0}; // Initialise our 3 output words to zero.
    for(int i=0; i<16; i++) // Loop over LS 16 bits
    {
        unsigned out_shift_cnt = i*6; // Tracking where we want to be in chunks of 6 bits
        unsigned out_shift_cnt_mod = out_shift_cnt % 32;
        unsigned out_shift_cnt_div = out_shift_cnt >> 5; // equiv to /32
        unsigned mask = 1 << i; // Create a single bit mask at the input bit we want to process
        if ((inword & mask) != 0) // Input bit is 1
        {
            outword[out_shift_cnt_div] |= (0x3F << out_shift_cnt_mod); // Set the 6 output bits at the correct position
            // Two special cases where the 6 output bits will cross a 32 bit word boundary.
            // Manually set the LS bits that cross over into the next output word.
            if (i == 5)
                outword[1] |= 0xF;
            else if (i == 10)
                outword[2] |= 0x3;
        }
        // Output words to port as soon as they are ready
        if (i == 5)
            p <: outword[0];
        else if (i == 10)
            p <: outword[1];
    }
    p <: outword[2];
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
        case 6:
            /* E.g. 24.576MHz -> 32kHz */
            zip_out_6(p,  encoded_word       ); // Output LS 16 bits as 3*32bit words
            zip_out_6(p, (encoded_word >> 16)); // Output MS 16 bits as 3*32bit words
            break;
        default:
            /* Mclk does not support required sample freq - unreachable due to previous error checks */
             __builtin_unreachable();
            break;
    }
}

#pragma unsafe arrays
static inline void subframe_tx(out buffered port:32 p, unsigned sample_in, int ctrl, unsigned char encoded_preamble, int divide, unsigned sample_mask)
{
    static int lastbit = 0;
    unsigned word, sample, control, parity;
    sample = sample_in >> 4 & sample_mask; /* Mask and shift to be in the correct place in the Sub-frame */
    control = (ctrl & 1) << 30;
    parity = parity32(sample | control | VALIDITY) << 31;
    word = sample | control | parity | VALIDITY;

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

void SpdifTransmit(out buffered port:32 p, chanend c_tx0, const uint32_t ctrl_left[6], const uint32_t ctrl_right[6], int divide, unsigned sample_mask)
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
    // prefill port buffers before outputting acutal data.
    // This ensures sender thread is blocked trying to send data and not the other way around,
    // allowing enough time between receiving data from the sender and producing the frame
    // to output on the tx port.
    p <: 0;
    p <: 0;

#pragma unsafe arrays
    while (1)
    {
        int ctrl_idx = 0;
        uint32_t controlLeft;
        uint32_t controlRight;

        for(int i = 0 ; i < 192; i++)
        {
            if((i & 31) == 0)
            {
                controlLeft  = ctrl_left[ctrl_idx];
                controlRight = ctrl_right[ctrl_idx];
                ctrl_idx += 1;
            }
            /* Sub-frame 1 */
            if(i == 0)
            {
                subframe_tx(p, sample_l, controlLeft, SPDIF_PREAMBLE_Z, divide, sample_mask);  // Block start & Sub-frame 1
            }
            else
            {
                subframe_tx(p, sample_l, controlLeft, SPDIF_PREAMBLE_X, divide, sample_mask); // Sub-frame 1
            }

            controlLeft >>=1;

            /* Sub-frame 2 */
            subframe_tx(p, sample_r, controlRight, SPDIF_PREAMBLE_Y, divide, sample_mask);

            controlRight >>=1;

            /* Test for new frequency */
            if(testct(c_tx0))
            {
                p <: 0; // Leave port driving low when exiting
                chkct(c_tx0, XS1_CT_END);
                return;
            }

            /* Get new samples... */
            sample_l = inuint(c_tx0);
            sample_r = inuint(c_tx0);
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

unsigned build_pro_channel_status(uint32_t chanStat_L[6], uint32_t chanStat_R[6], uint32_t samp_freq, uint32_t word_length);
unsigned build_consumer_channel_status(uint32_t chanStat_L[6], uint32_t chanStat_R[6], uint32_t samp_freq, uint32_t word_length);

/* S/PDIF transmit thread */
void spdif_tx(buffered out port:32 p, chanend c_in)
{
    spdif_tx_lld(p, c_in, NULL);
}

void spdif_tx_lld(buffered out port:32 p, chanend c_in, clock ?clk)
{
    chkct(c_in, XS1_CT_END);
    while(1)
    {
        uint32_t chanStat_L[6], chanStat_R[6];
        unsigned divide;
        unsigned sample_mask;

        /* Check for shutdown */
        if (testct(c_in))
        {
            chkct(c_in, XS1_CT_END);
            return;
        }

        /* Receive sample frequency over channel (in Hz) */
        unsigned  samFreq = inuint(c_in);

        /* Receive master clock frequency over channel (in Hz) */
        unsigned  mclkFreq = inuint(c_in);

        /* Receive word length in bits over channel. Supported word lengths - [16, 20, 24]*/
        unsigned word_length = inuint(c_in);

        sample_mask = (word_length == 16) ? 0x0FFFF000 :
                      (word_length == 20) ? 0x0FFFFF00 : 0x0FFFFFF0;

#if SPDIF_TX_ENABLE_PRO_CHANNEL_STATUS
        unsigned error = build_pro_channel_status(chanStat_L, chanStat_R, samFreq, word_length);
#else
        unsigned error = build_consumer_channel_status(chanStat_L, chanStat_R, samFreq, word_length);
#endif

        /* Calculate required divide */
        divide = mclkFreq / (samFreq * 2 * 32 * 2);
        
        if (!isnull(clk))
        {
            /* Set clock divider in clock block */
            stop_clock(clk);
            set_clock_div(clk, (divide>>1));
            start_clock(clk);
            divide = 1; /* Don't do clock division in software */
        }

        if((divide != 1) && (divide != 2) && (divide != 4) && (divide != 6))
            error++;

        if(error)
            SpdifTransmitError(c_in);
        else
            SpdifTransmit(p, c_in, chanStat_L, chanStat_R, divide, sample_mask);
    }
}

void spdif_tx_output(chanend c, unsigned l, unsigned r)
{
    outuint(c, l);
    outuint(c, r);
}

void spdif_tx_reconfigure_sample_rate(chanend c,
                                      unsigned sample_frequency,
                                      unsigned master_clock_frequency,
                                      unsigned word_length)
{
    outct(c, XS1_CT_END);
    outuint(c, sample_frequency);
    outuint(c, master_clock_frequency);
    outuint(c, word_length);
}

void spdif_tx_shutdown(chanend c)
{
    outct(c, XS1_CT_END);
    outct(c, XS1_CT_END);
}

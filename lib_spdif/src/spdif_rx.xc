// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>

#include "spdif.h"

void spdif_receive_sample(streaming chanend c, int32_t &sample, size_t &index)
{
    uint32_t v;
    c :> v;
    index = (v & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_Y ? 1 : 0;
    sample = (v & ~SPDIF_RX_PREAMBLE_MASK) << 4;
}

#if (LEGACY_SPDIF_RECEIVER)

void SpdifReceive(in buffered port:4 p, streaming chanend c, int initial_divider, clock clk);

void spdif_rx(streaming chanend c, in port p, clock clk, unsigned sample_freq_estimate)
{
    int initial_divider;
    in port * movable pp = &p;
    in buffered port:4 * movable pbuf = reconfigure_port(move(pp), in buffered port:4);
    if (sample_freq_estimate > 96000)
    {
        initial_divider = 1;
    }
    else if (sample_freq_estimate > 48000)
    {
        initial_divider = 2;
    }
    else
    {
        initial_divider = 4;
    }

    SpdifReceive(*pbuf, c, initial_divider, clk);

    // Set pointers and ownership back to original state if SpdifReceive() exits
    pp = reconfigure_port(move(pbuf), in port);
}

void spdif_receive_shutdown(streaming chanend c)
{
    soutct (c, XS1_CT_END);
}

#else

static inline int cls(int idata)
{
    int x;
#if __XS3A__
    asm volatile("cls %0, %1" : "=r"(x)  : "r"(idata));
#else
    x = (clz(idata) + clz(~idata));
#endif
    return x;
}

static inline int xor4(int idata1, int idata2, int idata3, int idata4)
{
    int x;
    asm volatile("xor4 %0, %1, %2, %3, %4" : "=r"(x)  : "r"(idata1), "r"(idata2), "r"(idata3), "r"(idata4));
    return x;
}

// Lookup tables for port time adder based on where the reference transition was.
// Index can be max of 32 so need 33 element array.
// Index 0 is never used.
const unsigned error_lookup_441[33] = {0,36,36,35,35,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42};
const unsigned error_lookup_48[33]  = {0,33,33,32,32,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39};

#pragma unsafe arrays
static inline void spdif_rx_8UI_48(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword)
{
    unsigned crc;
    unsigned ref_tran;

    // 48k standard
    const unsigned unscramble_0x08080404_0xB[16] = {
    0xA0000000, 0x10000000, 0xE0000000, 0x50000000,
    0x20000000, 0x90000000, 0x60000000, 0xD0000000,
    0x70000000, 0xC0000000, 0x30000000, 0x80000000,
    0xF0000000, 0x40000000, 0xB0000000, 0x00000000};

    // Now receive data
    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
    ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
    t += error_lookup_48[ref_tran]; // Lookup next port time based off where current transition was.
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
    if (ref_tran > 2)
      sample <<= 1;
    crc = sample & 0x08080404;
    crc32(crc, 0xF, 0xB);
    outword >>= 4;
    outword |= unscramble_0x08080404_0xB[crc];
}

#pragma unsafe arrays
static inline void spdif_rx_8UI_441(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword)
{
    unsigned crc;
    unsigned ref_tran;

    // 44.1k standard
    const unsigned unscramble_0x08080202_0xC[16] = {
    0x70000000, 0xC0000000, 0xA0000000, 0x10000000,
    0x30000000, 0x80000000, 0xE0000000, 0x50000000,
    0x20000000, 0x90000000, 0xF0000000, 0x40000000,
    0x60000000, 0xD0000000, 0xB0000000, 0x00000000};

    // Now receive data
    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
    ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
    t += error_lookup_441[ref_tran]; // Lookup next port time based off where current transition was.
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
    if (ref_tran > 2)
      sample <<= 1;
    crc = sample & 0x08080202;
    crc32(crc, 0xF, 0xC);
    outword >>= 4;
    outword |= unscramble_0x08080202_0xC[crc];
}

void spdif_rx_48(streaming chanend c, buffered in port:32 p, unsigned &t)
{
    unsigned pre_check = 0;
    unsigned sample;
    unsigned outword = 0;
    unsigned z_pre_sample = 0;

    // Set the initial port time
    // Note, this is inline asm since xc can only express a timed input/output
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    // Now receive data
    while(pre_check < 16)
    {
        spdif_rx_8UI_48(p, t, sample, outword);
        pre_check = cls(sample);
        if (pre_check > 9) // Last three bits of old subframe and first "bit" of preamble.
        {
            outword = xor4(outword, (outword << 1), 0xFFFFFFFF, z_pre_sample); // This achieves the xor decode plus inverting the output in one step.
            outword <<= 1;
            c <: outword;

            spdif_rx_8UI_48(p, t, sample, outword);
            z_pre_sample = sample;
            spdif_rx_8UI_48(p, t, sample, outword);
            spdif_rx_8UI_48(p, t, sample, outword);
            spdif_rx_8UI_48(p, t, sample, outword);
            if (cls(z_pre_sample<<11) > 9)
              z_pre_sample = 2;
            else
              z_pre_sample = 0;
            spdif_rx_8UI_48(p, t, sample, outword);
            spdif_rx_8UI_48(p, t, sample, outword);
            spdif_rx_8UI_48(p, t, sample, outword);
        }
    }
}

void spdif_rx_441(streaming chanend c, buffered in port:32 p, unsigned &t)
{
    unsigned pre_check = 0;
    unsigned sample;
    unsigned outword = 0;
    unsigned z_pre_sample = 0;

    // Set the initial port time
    // Note, this is inline asm since xc can only express a timed input/output
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    // Now receive data
    while(pre_check < 16)
    {
        spdif_rx_8UI_441(p, t, sample, outword);
        pre_check = cls(sample);
        if (pre_check > 9) // Last three bits of old subframe and first "bit" of preamble.
        {
            outword = xor4(outword, (outword << 1), 0xFFFFFFFF, z_pre_sample); // This achieves the xor decode plus inverting the output in one step.
            outword <<= 1;
            c <: outword;

            spdif_rx_8UI_441(p, t, sample, outword);
            z_pre_sample = sample;
            spdif_rx_8UI_441(p, t, sample, outword);
            spdif_rx_8UI_441(p, t, sample, outword);
            spdif_rx_8UI_441(p, t, sample, outword);
            if (cls(z_pre_sample<<11) > 10)
              z_pre_sample = 2;
            else
              z_pre_sample = 0;
            spdif_rx_8UI_441(p, t, sample, outword);
            spdif_rx_8UI_441(p, t, sample, outword);
            spdif_rx_8UI_441(p, t, sample, outword);
        }
    }
}

// This initial sync locks the DLL onto stream (inc. Z preamble) and checks if it is OK for decode.
#pragma unsafe arrays
int initial_sync_441(buffered in port:32 p, unsigned &t, unsigned clock_div)
{
    // Initial lock to start of preambles and check our sampling freq is correct.
    // We will very quickly lock into one of two positions in the stream (where data transitions every 8UI)
    // This can happen in two places when you consider X and Y preambles and these are very frequent.
    // There is only one position we can lock when considering all three (X, Y and Z) preambles.
    unsigned ref_tran;
    unsigned sample;
    int t_block = 0;
    timer tmr;
    unsigned tmp;

    // Read the port counter and add a bit.
    p :> void @ t; // read port counter
    t+= 100;
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    for(int i=0; i<20000;i++)
    {
        asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
        ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
        t += error_lookup_441[ref_tran]; // Lookup next port time based off where current transition was.
        asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
        if (ref_tran > 16)
            break;
        if (ref_tran > 2)
            sample <<= 1;
        if (cls(sample) > 9)
        {
            asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
            ref_tran = cls(sample<<10);
            t += error_lookup_441[ref_tran]; // Lookup next port time based off where current transition was.
            asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
            if (ref_tran > 2)
                sample <<= 1;
            //look for a z preamble
            if (cls(sample<<11) > 10) // Z preamble
            {
                tmr :> tmp;
                if (t_block == 0)
                {
                    t_block = tmp;
                }
                else
                {
                    t_block = tmp - t_block;
                    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p)); // empty the transfer reg
                    break;
                }
            }
        }
    }

    int t_block_targ;
    int t_block_err;
    // samplefreq  clockdiv  target (192/sr)
    // 44100       2         4.354ms
    // 88200       1         2.177ms
    // 176400      0         1.088ms
    t_block_targ = 108843 << clock_div;
    t_block_err = t_block - t_block_targ;

    t+=70; // Add an 8UI*2 time adder to ensure we have enough instruction time before next IN.

    if ((t_block_err > -435) && (t_block_err < 435))
        return 0;
    else
        return 1;
}

// This initial sync locks the DLL onto stream (inc. Z preamble) and checks if it is OK for decode.
#pragma unsafe arrays
int initial_sync_48(buffered in port:32 p, unsigned &t, unsigned clock_div)
{
    // Initial lock to start of preambles and check our sampling freq is correct.
    // We will very quickly lock into one of two positions in the stream (where data transitions every 8UI)
    // This can happen in two places when you consider X and Y preambles and these are very frequent.
    // There is only one position we can lock when considering all three (X, Y and Z) preambles.
    unsigned ref_tran;
    unsigned sample;
    int t_block = 0;
    timer tmr;
    unsigned tmp;

    // Read the port counter and add a bit.
    p :> void @ t; // read port counter
    t+= 100;
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    for(int i=0; i<20000;i++)
    {
        asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
        ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
        t += error_lookup_48[ref_tran]; // Lookup next port time based off where current transition was.
        asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
        if (ref_tran > 16)
            break;
        if (ref_tran > 2)
            sample <<= 1;
        if (cls(sample) > 9)
        {
            asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
            ref_tran = cls(sample<<9);
            t += error_lookup_48[ref_tran]; // Lookup next port time based off where current transition was.
            asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
            if (ref_tran > 2)
                sample <<= 1;
            //look for a z preamble
            if (cls(sample<<11) > 9) // Z preamble
            {
                tmr :> tmp;
                if (t_block == 0)
                {
                    t_block = tmp;
                }
                else
                {
                    t_block = tmp - t_block;
                    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p)); // empty the transfer reg
                    break;
                }
            }
        }
    }

    int t_block_targ;
    int t_block_err;
    // samplefreq  clockdiv  target (192 frames/sample-rate)
    // 48000       2         4ms
    // 96000       1         2ms
    // 192000      0         1ms
    t_block_targ = 100000 << clock_div;
    t_block_err = t_block - t_block_targ;

    t+=65; // Add an 8UI*2 time adder to ensure we have enough instruction time before next IN.

    // ~1000ppm at 48000Hz
    if ((t_block_err > -400) && (t_block_err < 400))
        return 0;
    else
        return 1;
}

void spdif_rx(streaming chanend c, buffered in port:32 p, clock clk, unsigned sample_freq_estimate)
{
    int clock_mod = sample_freq_estimate % 44100;
    int clock_div = 2;

    if(sample_freq_estimate > 96000)
    {
       clock_div = 0;
    }
    else if (sample_freq_estimate > 48000)
    {
       clock_div = 1;
    }

    // Configure spdif rx port to be clocked from spdif_rx clock defined below.
    configure_in_port(p, clk);

    while(1)
    {
        // Stop clock so we can reconfigure it
        stop_clock(clk);
        // Set the desired clock div
        configure_clock_ref(clk, clock_div);
        // Start the clock block running. Port timer will be reset here.
        start_clock(clk);

        // We now test to see if the 44.1 base rate decode will work, if not we switch to 48.
        unsigned t;

        for(int i = 0; i < 2; i++)
        {
            if(clock_mod)
            {
                if (initial_sync_48(p, t, clock_div) == 0)
                {
                    spdif_rx_48(c, p, t);
                    //printf("Exit %dHz Mode\n", (192000>>clock_div));
                }
            }
            else
            {
                if (initial_sync_441(p, t, clock_div) == 0)
                {
                    spdif_rx_441(c, p, t);  // We pass in start time so that we start in sync.
                    //printf("Exit %dHz Mode\n", (176400>>clock_div));
                }
            }
            clock_mod = !clock_mod;
        }

        clock_div++;
        if(clock_div == 3)
        {
            clock_div = 0;
        }
    }
}
#endif

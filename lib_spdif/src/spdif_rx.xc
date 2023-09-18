// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

#include "spdif.h"

#if 0

void SpdifReceive(in buffered port:4 p, streaming chanend c, int initial_divider, clock clk);

void spdif_rx(streaming chanend c, in port p, clock clk,
              unsigned sample_freq_estimate)
{
  int initial_divider;
  in port * movable pp = &p;
  in buffered port:4 * movable pbuf = reconfigure_port(move(pp),
                                                       in buffered port:4);
  if (sample_freq_estimate > 96000) {
    initial_divider = 1;
  } else if (sample_freq_estimate > 48000) {
    initial_divider = 2;
  }
  else {
    initial_divider = 4;
  }
  SpdifReceive(*pbuf, c, initial_divider, clk);

  // Set pointers and ownership back to original state if SpdifReceive() exits
  pp = reconfigure_port(move(pbuf), in port);
}

void spdif_receive_sample(streaming chanend c, int32_t &sample, size_t &index)
{
  uint32_t v;
  c :> v;
  index = (v & 0xF) == SPDIF_FRAME_Y ? 1 : 0;
  sample = (v & ~0xF) << 4;
}

void spdif_receive_shutdown(streaming chanend c){
  soutct (c, XS1_CT_END);
}

#else

static inline int cls(int idata)
{
    int x;
    asm volatile("cls %0, %1" : "=r"(x)  : "r"(idata)); // xs3 on.
    //x = (clz(idata) + clz(~idata)); // For xs2.
    return x;
}

static inline int xor4(int idata1, int idata2, int idata3, int idata4)
{
    int x;
    asm volatile("xor4 %0, %1, %2, %3, %4" : "=r"(x)  : "r"(idata1), "r"(idata2), "r"(idata3), "r"(idata4));
    return x;
}

// Lookup tables for port times. index can be max of 32 so need 33 element array.
const unsigned error_lookup_441[33] = {36,36,36,35,35,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42};
const unsigned error_lookup_48[33]  = {35,34,33,32,32,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39};

#pragma unsafe arrays
static inline void spdif_rx_8UI_STD_48(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword)
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
    sample <<= (ref_tran - 2); // shift the sample to make the transition exactly between bits 20 and 21.
    crc = sample & 0x08080404;
    crc32(crc, 0xF, 0xB);
    outword >>= 4;
    outword |= unscramble_0x08080404_0xB[crc];
}

#pragma unsafe arrays
static inline void spdif_rx_8UI_PRE_48(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword)
{
    unsigned crc;
    unsigned ref_tran;

    // 48k preamble
    const unsigned unscramble_0x08080440_0xF[16] = {
    0x10000000, 0x90000000, 0xE0000000, 0x60000000,
    0x50000000, 0xD0000000, 0xA0000000, 0x20000000,
    0x30000000, 0xB0000000, 0xC0000000, 0x40000000,
    0x70000000, 0xF0000000, 0x80000000, 0x00000000};

    // Now receive data
    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
    ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
    t += error_lookup_48[ref_tran]; // Lookup next port time based off where current transition was.
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
    sample <<= (ref_tran - 2); // shift the sample to make the transition exactly between bits 20 and 21.
    crc = sample & 0x08080440;
    crc32(crc, 0xF, 0xF);
    outword >>= 4;
    outword |= unscramble_0x08080440_0xF[crc];
}

#pragma unsafe arrays
static inline void spdif_rx_8UI_STD_441(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword)
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
    if (ref_tran > 3)
        ref_tran = 3;
    sample <<= (ref_tran - 2); // shift the sample to make the transition exactly between bits 20 and 21.
    crc = sample & 0x08080202;
    crc32(crc, 0xF, 0xC);
    outword >>= 4;
    outword |= unscramble_0x08080202_0xC[crc];
}

#pragma unsafe arrays
static inline void spdif_rx_8UI_PRE_441(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword)
{
    unsigned crc;
    unsigned ref_tran;

    // 44.1k preamble
    const unsigned unscramble_0x08080220_0xC[16] = {
    0x30000000, 0xC0000000, 0xA0000000, 0x50000000,
    0x70000000, 0x80000000, 0xE0000000, 0x10000000,
    0x20000000, 0xD0000000, 0xB0000000, 0x40000000,
    0x60000000, 0x90000000, 0xF0000000, 0x00000000};

    // Now receive data
    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
    ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
    t += error_lookup_441[ref_tran]; // Lookup next port time based off where current transition was.
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
    if (ref_tran > 3)
        ref_tran = 3;
    sample <<= (ref_tran - 2); // shift the sample to make the transition exactly between bits 20 and 21.
    crc = sample & 0x08080220;
    crc32(crc, 0xF, 0xC);
    outword >>= 4;
    outword |= unscramble_0x08080220_0xC[crc];
}

void spdif_rx_48(streaming chanend c, buffered in port:32 p, unsigned start_time)
{
    unsigned t;
    unsigned pre_check = 0;
    unsigned sample;
    unsigned outword = 0;

    // Set the initial port time
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(start_time));
    t = start_time;

    // Now receive data
    while(pre_check < 16)
    {
        spdif_rx_8UI_STD_48(p, t, sample, outword);
        pre_check = cls(sample);
        if (pre_check > 10) // Last three bits of old subframe and first "bit" of preamble.
        {
            outword = xor4(outword, (outword << 1), 0xFFFFFFFF, 0x00000000); // This achieves the xor decode plus inverting the output in one step.
            outword <<= 1;
            c <: outword;

            // Receive and decode the next input word here because we need to use a different mask to capture the preamble detail.
            spdif_rx_8UI_PRE_48(p, t, sample, outword);
            spdif_rx_8UI_STD_48(p, t, sample, outword);
            spdif_rx_8UI_STD_48(p, t, sample, outword);
            spdif_rx_8UI_STD_48(p, t, sample, outword);
            spdif_rx_8UI_STD_48(p, t, sample, outword);
            spdif_rx_8UI_STD_48(p, t, sample, outword);
            spdif_rx_8UI_STD_48(p, t, sample, outword);
        }
    }
}

void spdif_rx_441(streaming chanend c, buffered in port:32 p, unsigned start_time)
{
    unsigned t;
    unsigned pre_check = 0;
    unsigned sample;
    unsigned outword = 0;

    // Set the initial port time
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(start_time));
    t = start_time;

    // Now receive data
    while(pre_check < 16)
    {
        spdif_rx_8UI_STD_441(p, t, sample, outword);
        pre_check = cls(sample);
        if (pre_check > 10) // Last three bits of old subframe and first "bit" of preamble.
        {
            outword = xor4(outword, (outword << 1), 0xFFFFFFFF, 0x00000000); // This achieves the xor decode plus inverting the output in one step.
            outword <<= 1;
            c <: outword;

            // Receive and decode the next input word here because we need to use a different mask to capture the preamble detail.
            spdif_rx_8UI_PRE_441(p, t, sample, outword);
            spdif_rx_8UI_STD_441(p, t, sample, outword);
            spdif_rx_8UI_STD_441(p, t, sample, outword);
            spdif_rx_8UI_STD_441(p, t, sample, outword);
            spdif_rx_8UI_STD_441(p, t, sample, outword);
            spdif_rx_8UI_STD_441(p, t, sample, outword);
            spdif_rx_8UI_STD_441(p, t, sample, outword);
        }
    }
}

// This initial sync locks the DLL onto stream (inc. Z preamble) and checks if it is OK for decode.
# pragma unsafe arrays
int initial_sync_441(buffered in port:32 p, unsigned &t)
{
    // Initial lock to start of preambles and check our sampling freq is correct.
    // We will very quickly lock into one of two positions in the stream (where data transitions every 8UI)
    // This can happen in two places when you consider X and Y preambles and these are very frequent.
    // There is only one position we can lock when considering all three (X, Y and Z preambles) but waiting for Z preambles takes too long as only every 192 frames.
    // So we detect if we have locked to wrong transition and bump the time by 2UI (8 bits) to the correct transition.
    unsigned pre_count = 0;
    unsigned t_pre = 0;
    int t_subframe;
    unsigned ref_tran;
    unsigned sample;

    // Read the port counter and add a bit.
    p :> void @ t; // read port counter
    t+= 100;
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    for(int i=0; i<20000;i++)
    {
        asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
        ref_tran = cls(sample<<10); // Expected value is 2 Possible values are 1 to 32.
        t += error_lookup_441[ref_tran]; // Lookup next port time based off where current transition was.
        if ((i == 64) && (pre_count < 4)) // If we've got to 64 inputs and still haven't locked to preamble boundary, we must be locked to other transition so bump us to the correct one.
            t += 8;
        asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
        sample <<= (ref_tran - 2); // shift the sample to make the transition exactly between bits 19 and 20.
        if (cls(sample) > 11) // this will catch too many preambles. need to modify ref point so we can look for longer preamble start. We're not decoding any data so can pick whereever we want. Then adjust later. leave as is for now.
        {
            pre_count++;
            if (pre_count == 256)
            {
                t_pre = t;
            }
            else if (pre_count == 512)
            {
                t_subframe = t - t_pre;
                break;
            }
        }
    }

    t+=35; // Add an 8UI time adder to ensure we have enough instruction time before next IN.
    t_subframe = t_subframe >> 8; // Divide by 256 to get average subframe time.
    //printf("t_subframe = %d\n", t_subframe);
    if ((t_subframe > 280) && (t_subframe < 286)) // Correct 44.1 subframe time
        return 0;
    else
        return 1;

}

// This initial sync locks the DLL onto stream (inc. Z preamble) and checks if it is OK for decode.
int initial_sync_48(buffered in port:32 p, unsigned &t)
{
    // Initial lock to start of preambles and check our sampling freq is correct.
    // We will very quickly lock into one of two positions in the stream (where data transitions every 8UI)
    // This can happen in two places when you consider X and Y preambles and these are very frequent.
    // There is only one position we can lock when considering all three (X, Y and Z preambles) but waiting for Z preambles takes too long as only every 192 frames.
    // So we detect if we have locked to wrong transition and bump the time by 2UI (8 bits) to the correct transition.
    unsigned pre_count = 0;
    unsigned t_pre = 0;
    int t_subframe;
    unsigned ref_tran;
    unsigned sample;

    // Read the port counter and add a bit.
    p :> void @ t; // read port counter
    t+= 100;
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    for(int i=0; i<20000;i++)
    {
        asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
        ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
        t += error_lookup_48[ref_tran]; // Lookup next port time based off where current transition was.
        if ((i == 64) && (pre_count < 4)) // If we've got to 64 inputs and still haven't locked to preamble boundary, we must be locked to other transition so bump us to the correct one.
            t += 8;
        asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
        sample <<= (ref_tran - 2); // shift the sample to make the transition exactly between bits 19 and 20.
        if (cls(sample) > 10) // this will catch too many preambles. need to modify ref point so we can look for longer preamble start. We're not decoding any data so can pick whereever we want. Then adjust later. leave as is for now.
        {
            pre_count++;
            if (pre_count == 256)
            {
                t_pre = t;
            }
            else if (pre_count == 512)
            {
                t_subframe = t - t_pre;
            }
        }
    }

    t+=33; // Add an 8UI time adder to ensure we have enough instruction time before next IN.
    t_subframe = t_subframe >> 8; // Divide by 256 to get average subframe time.
    //printf("t_subframe = %d\n", t_subframe);
    if ((t_subframe > 257) && (t_subframe < 263)) // Correct 44.1 subframe time
        return 0;
    else
        return 1;

}

void spdif_rx(streaming chanend c, buffered in port:32 p, clock clk)
{

    // Configure spdif rx port to be clocked from spdif_rx clock defined below.
    configure_in_port(p, clk);

    while(1)
    {
        for(int clock_div = 0; clock_div < 3; clock_div++) // Loop over different sampling freqs (100/50/25MHz)
        {
            // Stop clock so we can reconfigure it
            stop_clock(clk);
            // Set the desired clock div
            configure_clock_ref(clk, clock_div);
            // Start the clock block running. Port timer will be reset here.
            start_clock(clk);

            // We now test to see if the 44.1 base rate decode will work, if not we switch to 48.
            unsigned t;
            if (initial_sync_441(p, t) == 0)
            {
                spdif_rx_441(c, p, t);  // We pass in start time so that we start in sync.
                printf("Exit %dHz Mode\n", (176400>>clock_div));
            }
            else if (initial_sync_48(p, t) == 0)
            {
                spdif_rx_48(c, p, t);
                printf("Exit %dHz Mode\n", (192000>>clock_div));
            }
        }
    }
}

#endif

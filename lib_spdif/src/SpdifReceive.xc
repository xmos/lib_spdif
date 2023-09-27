
#include <xs1.h>
#include <xclib.h>
#include <stdint.h>

#include "spdif.h"

#if(!LEGACY_SPDIF_RECEIVER)

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
static inline void spdif_rx_8UI_48(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword, unsigned &unlock_cnt)
{
    unsigned crc;
    unsigned ref_tran;

    // 48k standard
    unsigned unscramble_0x04040404_0xF[16] = {
    0x80000000, 0x90000000, 0xC0000000, 0xD0000000,
    0x70000000, 0x60000000, 0x30000000, 0x20000000,
    0xA0000000, 0xB0000000, 0xE0000000, 0xF0000000,
    0x50000000, 0x40000000, 0x10000000, 0x00000000};

    // Now receive data
    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
    ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
    t += error_lookup_48[ref_tran]; // Lookup next port time based off where current transition was.
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
    if (ref_tran > 4)
      unlock_cnt++;
    crc = sample & 0x04040404;
    crc32(crc, 0xF, 0xF);
    outword >>= 4;
    outword |= unscramble_0x04040404_0xF[crc];
}

#pragma unsafe arrays
static inline void spdif_rx_8UI_441(buffered in port:32 p, unsigned &t, unsigned &sample, unsigned &outword, unsigned &unlock_cnt)
{
    unsigned crc;
    unsigned ref_tran;

    // 44.1k standard
    unsigned unscramble_0x08040201_0xF[16] = {
    0xF0000000, 0x70000000, 0xB0000000, 0x30000000,
    0xD0000000, 0x50000000, 0x90000000, 0x10000000,
    0xE0000000, 0x60000000, 0xA0000000, 0x20000000,
    0xC0000000, 0x40000000, 0x80000000, 0x00000000};

    // Now receive data
    asm volatile("in %0, res[%1]" : "=r"(sample)  : "r"(p));
    ref_tran = cls(sample<<9); // Expected value is 2 Possible values are 1 to 32.
    t += error_lookup_441[ref_tran]; // Lookup next port time based off where current transition was.
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));
    if (ref_tran > 4)
      unlock_cnt++;
    crc = sample & 0x08040201;
    crc32(crc, 0xF, 0xF);
    outword >>= 4;
    outword |= unscramble_0x08040201_0xF[crc];
}

void spdif_rx_48(streaming chanend c, buffered in port:32 p)
{
    unsigned sample;
    unsigned outword = 0;
    unsigned z_pre_sample = 0;
    unsigned unlock_cnt = 0;
    unsigned t;

    // Read the port counter and add a bit.
    p :> void @ t; // read port counter
    t+= 100;
    // Note, this is inline asm since xc can only express a timed input/output
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    // Now receive data
    while(unlock_cnt < 32)
    {
        spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
        if (cls(sample) > 9) // Last three bits of old subframe and first "bit" of preamble.
        {
            outword = xor4(outword, (outword << 1), 0xFFFFFFFF, z_pre_sample); // This achieves the xor decode plus inverting the output in one step.
            outword <<= 1;
            c <: outword;

            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
            z_pre_sample = sample;
            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
            if (cls(z_pre_sample<<13) > 8)
              z_pre_sample = 2;
            else
              z_pre_sample = 0;
            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_48(p, t, sample, outword, unlock_cnt);
        }
    }
}

void spdif_rx_441(streaming chanend c, buffered in port:32 p)
{
    unsigned sample;
    unsigned outword = 0;
    unsigned z_pre_sample = 0;
    unsigned unlock_cnt = 0;
    unsigned t;

    // Read the port counter and add a bit.
    p :> void @ t; // read port counter
    t+= 100;
    // Note, this is inline asm since xc can only express a timed input/output
    asm volatile("setpt res[%0], %1"::"r"(p),"r"(t));

    // Now receive data
    while(unlock_cnt < 32)
    {
        spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
        if (cls(sample) > 9) // Last three bits of old subframe and first "bit" of preamble.
        {
            outword = xor4(outword, (outword << 1), 0xFFFFFFFF, z_pre_sample); // This achieves the xor decode plus inverting the output in one step.
            outword <<= 1;
            c <: outword;

            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
            z_pre_sample = sample;
            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
            if (cls(z_pre_sample<<13) > 9)
              z_pre_sample = 2;
            else
              z_pre_sample = 0;
            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
            spdif_rx_8UI_441(p, t, sample, outword, unlock_cnt);
        }
    }
}

// This function checks the port clock is approximately the correct frequency
int check_clock_div(buffered in port:32 p)
{
    unsigned pulse_width;
    unsigned sample;
    for(int i=0; i<100;i++) // Check 100 32bit samples
    {
        p :> sample;
        sample <<= cls(sample); // Shift off the top pulse (likely to not be a complete pulse)
        pulse_width = cls(sample);
        if ((pulse_width < 2) || (pulse_width > 14))
            return 1;
    }
    return 0;
}

#endif


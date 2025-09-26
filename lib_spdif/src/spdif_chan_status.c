// Copyright 2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <string.h>
#include "spdif_pro_crc.h"

uint8_t calc_spdif_pro_crc(uint32_t len, const uint8_t *buf, uint8_t init,
                    uint8_t final_xor, uint8_t poly)
{
    uint8_t tmp = (init ^ buf[0]);
    uint32_t xmos_crc = 0;
    uint32_t shifted;
    asm volatile("crc8 %0, %1, %3, %4" : "=r"(xmos_crc), "=r"(shifted) : "0"(xmos_crc), "r"(tmp), "r"(poly));

    for(int i=1;i<len;i++){
        // consume one byte at a time
        asm volatile("crc8 %0, %1, %3, %4" : "=r"(xmos_crc), "=r"(shifted) : "0"(xmos_crc), "r"(buf[i]), "r"(poly));
    }
    uint32_t data = 0;
    asm volatile("crc32 %0, %2, %3" : "=r"(xmos_crc) : "0"(xmos_crc), "r"(data), "r"(poly));
    return (uint8_t)xmos_crc;
}

unsigned build_pro_channel_status(uint32_t chanStat_L[6], uint32_t chanStat_R[6], uint32_t samp_freq)
{
    uint8_t* ptr_cs_l = (uint8_t*)&chanStat_L[0];
    uint8_t* ptr_cs_r = (uint8_t*)&chanStat_R[0];
    memset(chanStat_L, 0, 6*sizeof(chanStat_L[0]));
    memset(chanStat_R, 0, 6*sizeof(chanStat_R[0]));
    /*
    from the IEC 60958-4 spec

    Note - when specifying multiple bits, in the comment below,
    they're written in big endian (b0 b1 b2 b3 b4 b5 b6 b7) format.
    For example, bit0-3 = 0b0001 is written in b0b1b2b3 format, so b3 is 1 and b0,1,2 are 0.
    However, in the actual channel status block, data is stored in little endian format.

    byte0
    bit0, 1 - consumer use of channel status block
    bit1, 0 - Audio sample word represents linear PCM samples
    bit2-4, 000 - Emphasis not indicated
    bit5, 0 - Lock indication, lock condition not indicated
    bit6-7 , variable based on samp freq, 00 if samp freq is one of the ones indicated in byte4 bits3-6 instead
             01 - 48kHz, 10 - 44.1KHz, 11 - 32KHz

    byte1
    bit0-3, 0001 - channel mode - two channel mode
    bit4-7, 0001 - user bits management, 192bit block structure, preamble Z starts block

    byte2
    bit0-2, 001 - use of auxillary bits - Used for main audio. Max audio word length is 24bits
    bit3-5, 101 - Source word length - 24 bits
    bit6-7, 00 - indication of alignment level - Not indicated

    byte3
    bit0-6, 1000000 or 0100000 - channel number, 1 for Left channel, 2 for Right
    bit7, 0 - multichannel mode - Undefined

    byte4
    bit0-1, 00 - Digital audio reference signal - Not a reference signal
    bit2, 0 - Reserved
    bit3-6, vary based on sampling rate - Sampling freq, 0000 - not indicated,
            1000 - 24kHz, 0100 - 96kHz, 1100 - 192kHz, 1001 - 22.5kHz, 0101 - 88.2kHz, 1101 - 176.4kHz
    bit7, 0 - samp freq scaling flag - no scaling

    byte5-22 , not populated. All zeroes

    byte23, CRC
    */

    ptr_cs_l[0] = ptr_cs_r[0] = 0x1;
    ptr_cs_l[1] = ptr_cs_r[1] = 0x88;
    ptr_cs_l[2]= ptr_cs_r[2] = 0x2c;
    ptr_cs_l[3] = 0x01;
    ptr_cs_r[3] = 0x02;

    ptr_cs_l[4] = ptr_cs_r[4] = 0x00;

    // Populate sampling rate
    switch(samp_freq)
    {
        case 32000:
            ptr_cs_l[0] |= (0x03 << 6);
            ptr_cs_r[0] |= (0x03 << 6);
            break;
        case 44100:
            ptr_cs_l[0] |= (0x01 << 6);
            ptr_cs_r[0] |= (0x01 << 6);
            break;
        case 48000:
            ptr_cs_l[0] |= (0x02 << 6);
            ptr_cs_r[0] |= (0x02 << 6);
            break;
        case 24000:
            ptr_cs_l[4] |= (0x01 << 3);
            ptr_cs_r[4] |= (0x01 << 3);
            break;
        case 96000:
            ptr_cs_l[4] |= (0x02 << 3);
            ptr_cs_r[4] |= (0x02 << 3);
            break;
        case 192000:
            ptr_cs_l[4] |= (0x03 << 3);
            ptr_cs_r[4] |= (0x03 << 3);
            break;
        case 22500:
            ptr_cs_l[4] |= (0x09 << 3);
            ptr_cs_r[4] |= (0x09 << 3);
            break;
        case 88200:
            ptr_cs_l[4] |= (0x0a << 3);
            ptr_cs_r[4] |= (0x0a << 3);
            break;
        case 176400:
            ptr_cs_l[4] |= (0x0b << 3);
            ptr_cs_r[4] |= (0x0b << 3);
            break;
        default:
            return 1; // error
    }
    // Last byte contains the CRC over the 23 bytes of channel status block
    ptr_cs_l[23] = calc_spdif_pro_crc(23, (uint8_t*)chanStat_L, SPDIF_PRO_CRC_INITIAL_VALUE, SPDIF_PRO_CRC_FINAL_XOR, SPDIF_PRO_CRC_POLY);
    ptr_cs_r[23] = calc_spdif_pro_crc(23, (uint8_t*)chanStat_R, SPDIF_PRO_CRC_INITIAL_VALUE, SPDIF_PRO_CRC_FINAL_XOR, SPDIF_PRO_CRC_POLY);
    return 0;
}

unsigned build_consumer_channel_status(uint32_t chanStat_L[6], uint32_t chanStat_R[6], uint32_t samp_freq)
{
    // IEC 60958-3
    /* Defines for building channel status block for consumer use  */
    /* CHAN_STAT_L - 0x00107A04 = 0000 0001 0000 0 1111 010 00 000 1 0 0
    byte0
    bit0, 0 - consumer use of channel status block
    bit1, 0 - Audio sample word represents linear PCM samples
    bit2, 1 - Software for which no copy right is asserted
    bit3-5, 000 - 2 audio channels without pre-emphasis
    bit6-7, 00 - Mode 0 (bits8-191 would be mode0 specific)

    byte1
    bit0-2, 010 - category code Digital/digital converters
    bit3-6, 1111 - ?? (reserved in category code 010. Not sure why 0000 (PCM encoder/decoder) was not chosen)
    bit7, 0 - Not relevant for category code 010

    byte2
    bit0-3, 0000 - Source number -> unspecified
    bit4-7, 1000 - channel number -> A (left in 2 channel format)

    byte3
    bit0-3, varible based on sampling freq.

    byte4
    bit0, 1 - Maximum audio sample word length is 24 bits
    bit1-3, 101 - Sample word length, 24 bits

    CHAN_STAT_R is the same as CHAN_STAT_L except for byte2, bits4-7 indicating 0100 - B (right in 2 channel format)

    bytes4-23 : Reserved. 0x0
    */
    #define CHAN_STAT_L        (0x00107A04)
    #define CHAN_STAT_R        (0x00207A04)

    #define CHAN_STAT_32000    (0x03000000)
    #define CHAN_STAT_44100    (0x00000000)
    #define CHAN_STAT_48000    (0x02000000)
    #define CHAN_STAT_88200    (0x08000000)
    #define CHAN_STAT_96000    (0x0A000000)
    #define CHAN_STAT_176400   (0x0C000000)
    #define CHAN_STAT_192000   (0x0E000000)

    #define CHAN_STAT_WORD_2   (0x0000000B)

    memset(chanStat_L, 0, 6*sizeof(chanStat_L[0]));
    memset(chanStat_R, 0, 6*sizeof(chanStat_R[0]));
    chanStat_L[0] = CHAN_STAT_L;
    chanStat_R[0] = CHAN_STAT_R;

    chanStat_L[1] = CHAN_STAT_WORD_2;
    chanStat_R[1] = CHAN_STAT_WORD_2;
    for(int i=2; i<6; i++)
    {
        chanStat_L[i] = 0x0;
        chanStat_R[i] = 0x0;
    }
    /* Create channel status words based on sample freq */
    switch(samp_freq)
    {
        case 32000:
            chanStat_L[0] = CHAN_STAT_L | CHAN_STAT_32000;
            chanStat_R[0] = CHAN_STAT_R | CHAN_STAT_32000;
            break;

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
            return 1; // error
    }
    return 0;
}

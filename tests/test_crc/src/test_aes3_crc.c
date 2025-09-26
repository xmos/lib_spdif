// Copyright 2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "spdif_pro_crc.h"

uint32_t crc8_ref(uint32_t len, const uint8_t *buf, uint8_t init,
                    uint8_t final_xor, uint8_t poly){
    uint8_t val, crc = init;
    while(len--){
        val = (crc^*buf++)&0xff;
        for(int i=0; i < 8; i++)
        {
            val = val & 0x01 ? (val>>1)^poly : val>>1;
        }
        crc = val;
    }
    return crc^final_xor;
}

int main(void)
{
    // This test checks the AES3 CRC calculation.s
    // Test cases are from https://tech.ebu.ch/docs/tech/tech3250.pdf, appendix 1, which has 2 examples of channel
    // status data and the corresponding expected CRC values.
    uint32_t test[6];
    uint8_t *p_test = (uint8_t*)test;
    memset(test, 0, sizeof(test));
    p_test[0] = 0x01;
    uint8_t ref_crc = crc8_ref(sizeof(test)-1, (uint8_t*)test, SPDIF_PRO_CRC_INITIAL_VALUE, SPDIF_PRO_CRC_FINAL_XOR, SPDIF_PRO_CRC_POLY);
    printf("ref_crc = 0x%x\n", ref_crc);
    uint8_t xcore_crc = calc_spdif_pro_crc(sizeof(test)-1, (uint8_t*)test, SPDIF_PRO_CRC_INITIAL_VALUE, SPDIF_PRO_CRC_FINAL_XOR, SPDIF_PRO_CRC_POLY);
    printf("xcore_crc = 0x%x\n", xcore_crc);

    memset(test, 0, sizeof(test));
    p_test[0] = 0x3d;
    p_test[1] = 0x02;
    p_test[4] = 0x02;
    ref_crc = crc8_ref(23, (uint8_t*)test, SPDIF_PRO_CRC_INITIAL_VALUE, SPDIF_PRO_CRC_FINAL_XOR, SPDIF_PRO_CRC_POLY);
    printf("ref_crc = 0x%x\n", ref_crc);
    xcore_crc = calc_spdif_pro_crc(sizeof(test)-1, (uint8_t*)test, SPDIF_PRO_CRC_INITIAL_VALUE, SPDIF_PRO_CRC_FINAL_XOR, SPDIF_PRO_CRC_POLY);
    printf("xcore_crc = 0x%x\n", xcore_crc);
}

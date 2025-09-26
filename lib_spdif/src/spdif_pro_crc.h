// Copyright 2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _SPDIF_PRO_CRC_H_
#define _SPDIF_PRO_CRC_H_

#include <stdint.h>

/**
 * @brief Initial value for SPDIF professional CRC calculation
 *
 * The starting value used when beginning a new CRC calculation for the channel status block.
 */
#define SPDIF_PRO_CRC_INITIAL_VALUE (0xff)

/**
 * @brief Generator polynomial value for SPDIF professional CRC calculation.
 * G(X) = X^8 + X^4 + X^3 + X^2 + 1
 * Stored such that leftmost bit is x^0 and the rightmost bit is x^7
 */
#define SPDIF_PRO_CRC_POLY (0xB8)

/**
 * @brief Final XOR value for SPDIF professional CRC calculation
 */
#define SPDIF_PRO_CRC_FINAL_XOR  (0)

/**
 * @brief Calculate SPDIF professional CRC for a buffer of data
 *
 * Computes the CRC value for the given data buffer using the specified
 * initialization value, polynomial, and final XOR value.
 *
 * @param len Length of the data buffer in bytes
 * @param buf Pointer to the data buffer for which to calculate CRC
 * @param init Initial value for the CRC calculation
 * @param final_xor Value to XOR with the final CRC result
 * @param poly Polynomial value to use for CRC calculation
 *
 * @return The calculated CRC value as a 8-bit unsigned integer
 *
 * @note For standard SPDIF professional CRC calculation, use the predefined macros:
 *       - init: SPDIF_PRO_CRC_INITIAL_VALUE
 *       - final_xor: SPDIF_PRO_CRC_FINAL_XOR
 *       - poly: SPDIF_PRO_CRC_POLY
 */
uint8_t calc_spdif_pro_crc(uint32_t len, const uint8_t *buf, uint8_t init, uint8_t final_xor, uint8_t poly);

#endif

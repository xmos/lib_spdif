// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _SPDIF_H_
#define _SPDIF_H_
#include <stdint.h>
#include <stddef.h>
#include <xs1.h>

/** This constant provides a mask for the bits that should be used when
 * inspecting the preamble of a sample
 */
#define SPDIF_RX_PREAMBLE_MASK   (0xC)

/** This constant defines the four least-significant bits of the first
 * sample of a frame (typically a sample from the left channel)
 */
#define SPDIF_FRAME_X            (0xC)

/** This constant defines the four least-significant bits of the second or
 * later sample of a frame (typically a sample from the right channel,
 * unless there are more than two channels)
 */
#define SPDIF_FRAME_Y            (0x0)

/** This constant defines the four least-significant bits of the first
 * sample of the first frame of a block (typically a sample from the left
 * channel)
 */
#define SPDIF_FRAME_Z            (0x8)

/* Helper macros for inspecting preambles */
#define SPDIF_IS_FRAME_X(x) ((x & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_X)
#define SPDIF_IS_FRAME_Y(x) ((x & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_Y)
#define SPDIF_IS_FRAME_Z(x) ((x & SPDIF_RX_PREAMBLE_MASK) == SPDIF_FRAME_Z)

/* Helper macro for extracting sample bits from received S/PDIF subframe */
#define SPDIF_RX_EXTRACT_SAMPLE(x) ((x & 0xFFFFFFF0) << 4)

/** S/PDIF receive function.
 *
 * This function provides an S/PDIF receiver component.
 * It is capable of receiving 44100, 48000, 88200, 96000, 176400 and 192000 Hz sample rates.
 *
 * The receiver will modifiy the divider of the clock-block to lock to the incoming sample rate.
 *
 * \param p                      S/PDIF input port.
 *
 * \param c                      Channel to connect to the application.
 *
 * \param clk                    A clock block used internally to clock data.
 *
 * \param sample_freq_estimate   The initial expected sample rate (in Hz).
 *
 **/
void spdif_rx(streaming chanend c, in port p, clock clk, unsigned sample_freq_estimate);

/** Receive a sample from the S/PDIF component.
 *
 *  This function receives a sample from the S/PDIF component. It is a
 *  "select handler" so can be used within a select e.g.
 *
    \verbatim
     int32_t sample;
     size_t index;
     select {
       case spdif_rx_sample(c, sample, index):
            // use sample and index here...
            ...
            break;
     ...
    \endverbatim
 *
 *   The case in this select will fire when the S/PDIF component has data ready.
 *
 *   \param c       chanend connected to the S/PDIF receiver component
 *   \param sample  This reference parameter gets set with the incoming
 *                  sample data
 *   \param index   This is the index of the same in the current frame
 *                  (i.e. 0 for left channel and 1 for right channel).
 */
#pragma select handler
void spdif_rx_sample(streaming chanend c, int32_t &sample, size_t &index);

/** Shutdown the S/PDIF receiver component.
 *
 *  This function shuts down the SPDIF RX component causing the call to
 *  spdif_rx() to return.
 *
 *   \param c       chanend connected to the S/PDIF receiver component
 */
void spdif_rx_shutdown(streaming chanend c);

/** Checks the parity of a received S/PDIF sample
 *
 * \param sample    Received sample to be checked
 *
 * \return          Non-zero for error parity, otherwise 0
 *
 */
static inline int spdif_rx_check_parity(unsigned sample)
{
    unsigned x = (sample>>4);
    crc32(x, 0, 1);
    return x & 1;
}

/** S/PDIF transmit configure port function
 *
 * This function configures a port to be used by the SPDIF transmit
 * function.
 *
 * This function takes a delay for the clock that is to be passed into
 * the S/PDIF transmitter component. It sets the clock such that output data
 * is slightly delayed. This will work if I2S is clocked off the same clock
 * but ensures S/PDIF functions correctly.
 *
 * \param p       the port that the S/PDIF component will use
 * \param clk     the clock that the S/PDIF component will use
 * \param p_mclk  The clock connected to the master clock frequency.
 *                Usually this should be configured to be driven by
 *                an incoming master system clock.
 * \param delay   delay to uses to sync the SPDIF signal at the external
 *                flip-flop
 */
void spdif_tx_port_config(out buffered port:32 p, clock clk, in port p_mclk, unsigned delay);

/** S/PDIF transmit function.
 *
 * This function provides an S/PDIF transmit component.
 * It is capable of 44100, 48000, 88200, 96000, and 192000 Hz sample
 * rates.
 *
 * The sample rate can be dynamically changes during the operation
 * of the component. Note that the first API call to this component
 * should be to reconfigure the sample rate (using the
 * spdif_tx_reconfigure_sample_rate() function).
 *
 * \param p_spdif  The output port to transmit to
 * \param c        chanend to connect to the application
 */
void spdif_tx(buffered out port:32 p_spdif, chanend c);

/** Reconfigure the S/PDIF tx component to a new sample rate.
 *
 * This function instructs the S/PDIF transmitter component to change
 * sample rate.
 *
 * \param c_spdif_tx              chanend connected to the S/PDIF transmitter
 * \param sample_frequency        The required new sample frequency in Hz.
 * \param master_clock_frequency  The master_clock_frequency that the S/PDIF
 *                                transmitter is using
 */
void spdif_tx_reconfigure_sample_rate(chanend c_spdif_tx,
                                      unsigned sample_frequency,
                                      unsigned master_clock_frequency);

/** Output a sample pair to the S/PDIF transmitter component.
 *
 *  This function will output a left channel and right channel sample to
 *  the S/PDIF transmitter.
 *
 * \param c_spdif_tx    chanend connected to the S/PDIF transmitter
 * \param lsample       left sample to transmit
 * \param rsample       right sample to transmit
 */
void spdif_tx_output(chanend c_spdif_tx, unsigned lsample, unsigned rsample);

/** Shutdown the S/PDIF transmitter component.
 *
 *  This function shuts down the SPDIF Tx component causing the call to
 *  spdif_tx() to return.
 *
 *   \param c       chanend connected to the S/PDIF transmitter component
 */
void spdif_tx_shutdown(chanend c);

#endif /* _SPDIF_H_ */

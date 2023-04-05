// Copyright 2014-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef SPDIF_H_
#define SPDIF_H_
#include <stdint.h>
#include <stddef.h>
#include <xs1.h>

/** This constant defines the four least-significant bits of the first
 * sample of a frame (typically a sample from the left channel)
 */
#define SPDIF_FRAME_X 9

/** This constant defines the four least-significant bits of the second or
 * later sample of a frame (typically a sample from the right channel,
 * unless there are more than two channels)
 */
#define SPDIF_FRAME_Y 5

/** This constant defines the four least-significant bits of the first
 * sample of the first frame of a block (typically a sample from the left
 * channel)
 */
#define SPDIF_FRAME_Z 3

/** S/PDIF receive function.
 *
 * This function provides an S/PDIF receiver component.
 * It is capable of 11025, 12000, 22050, 24000,
 * 44100, 48000, 88200 and 96000 Hz sample rates.
 * When the decoder
 * encounters a long series of zeros it will lower its inernal divider; when it
 * encounters a short series of 0-1 transitions it will increase its internal
 * divider. This means that is will lock to the incoming sample rate.
 *
 * \param p_spdif         S/PDIF input port.
 *
 * \param c               channel to connect to the application.
 *
 * \param clk             A clock block used internally to clock data.
 *
 * \param sample_freq_estimate The initial expected sample rate (in Hz).
 *
 **/
void spdif_rx(streaming chanend c, in port p_spdif, clock clk, unsigned sample_freq_estimate);

/** Receive a sample from the S/PDIF component.
 *
 *  This function receives a sample from the S/PDIF component. It is a
 *  "select handler" so can be used within a select e.g.
 *
    \verbatim
     int32_t sample;
     size_t index;
     select {
       case spdif_receive_sample(c, sample, index):
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
void spdif_receive_sample(streaming chanend c, int32_t &sample, size_t &index);

/** Shutdown the S/PDIF component.
 *
 *  This function shuts down the SPDIF RX component causing the call to
 *  spdif_rx() to return.
 *
 *   \param c       chanend connected to the S/PDIF receiver component
 */
void spdif_receive_shutdown(streaming chanend c);

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
 * It is capable of 11025, 12000, 22050, 24000,
 * 44100, 48000, 88200, 96000, and 192000 Hz sample rates.
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

#endif /* SPDIF_H_ */

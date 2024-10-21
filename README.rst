:orphan:

#########################
lib_spdif: S/PDIF library
#########################

:vendor: XMOS
:version: 6.2.1
:scope: General Use
:description: S/PDIF transmitter and receiver
:category: Audio
:keywords: S/PDIF
:devices: xcore.ai, xcore-200

*******
Summary
*******

S/PDIF (Sony/Philips Digital Interface) is a standard for transmitting digital audio signals over
relatively short distances between devices. It was developed by Sony and Philips and is used to
carry high-quality digital audio without the need for analog conversion, maintaining the integrity
of the audio signal.

S/PDIF can carry two channels of uncompressed PCM (Pulse Code Modulation) audio or over Optical
(TOSLINK) or Coaxial transmission mediums.

``lib_spdif`` provides software defined S/PDIF implementation that allows transmission and reception
of S/PDIF data via `xcore` ports.

********
Features
********

 * Supports stereo S/PDIF receive for sample rates up to 192KHz
 * Supports stereo S/PDIF transmit for sample rates up to 192KHz
 * Fully compliant to the IEC60958 specification

************
Known issues
************

  * Transmitter has no way of setting user or validity bits (`#55` <https://github.com/xmos/lib_spdif/issues/55>`_)

****************
Development repo
****************

  * `lib_spdif <https://www.github.com/xmos/lib_spdif>`_

**************
Required tools
**************

  * XMOS XTC Tools: 15.3.0

*********************************
Required libraries (dependencies)
*********************************

  * None

*************************
Related application notes
*************************

The following application notes use this library:

  * `AN02003: SPDIF/ADAT/I²S Receive to I²S Slave Bridge with ASRC <https://www.xmos.com/file/an02003>`_

*******
Support
*******

This package is supported by XMOS Ltd. Issues can be raised against the software at: http://www.xmos.com/support



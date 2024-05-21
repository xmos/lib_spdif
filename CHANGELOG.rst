lib_spdif Change Log
====================

UNRELEASED
----------

  * CHANGED:   Use lib_sw_pll for configuring the application PLL in examples

6.1.0
-----

  * ADDED:     Support for XCommon CMake build system
  * ADDED:     Support for transmit at 32kHz
  * RESOLVED:  Coding optimisations not properly enabled in receiver
  * RESOLVED:  Receiver timing issues for sample rates greater than 96kHz
  * RESOLVED:  Failure to select correct receive sample rate when the sample
    rate of the incoming stream changes

6.0.0
-----

  * ADDED:     Shutdown function for S/PDIF transmitter
  * CHANGED:   Receiver rearchitected for improved performance and jitter
    tolerance
  * CHANGED:   API function names updated for uniformity between rx and tx

5.0.1
-----

  * FIXED:     Reinstated graceful handling of bad sample-rate/master-clock pair

5.0.0
-----

  * CHANGED:   Updated examples for new XK-AUDIO-316-MC board
  * CHANGED:   Updated transmit to simplified implementation (note, no longer
    supports XS1 based devices)
  * CHANGED:   Removed headers SpdifReceive.h and SpdifTransmit.h. Users should
    include spdif.h

4.2.1
-----

  * CHANGED:   Documentation updates

4.2.0
-----

  * ADDED:     Shutdown function for S/PDIF receiver
  * CHANGED:   spdif_tx_example updated to use XK-AUDIO-216-MC

4.1.0
-----

  * CHANGED:   Use XMOS Public Licence Version 1
  * CHANGED:   Rearrange documentation files

4.0.1
-----

  * REMOVED:   Unrequired cpanfile

4.0.0
-----

  * CHANGED:   Build files updated to support new "xcommon" behaviour in xwaf.

3.1.0
-----

  * Add library wscript to enable applications built using xwaf

3.0.0
-----

  * spdif_tx() no longer configures port. Additional function
    spdif_tx_port_config() provided. Allows sharing of clockblock with other
    tasks

2.0.2
-----

  * Fixed exception when running on xCORE-200 targets

2.0.1
-----

  * Update to source code license and copyright

2.0.0
-----

  * Move to library format. New documentation and helper functions.

1.3.1
-----

  * Added .type and .size directives to SpdifReceive. This is required for the
    function to show up in xTIMEcomposer binary viewer

1.3.0
-----

  * Added this file
  * Removed xcommon dep


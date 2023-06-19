lib_spdif Change Log
====================

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

  * ADDED:     Added shutdown function for S/PDIF Receiver
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


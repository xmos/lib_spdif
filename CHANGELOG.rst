SPDIF library change log
========================

4.0.0
-----

  * CHANGED: Build files updated to support new "xcommon" behaviour in xwaf.

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


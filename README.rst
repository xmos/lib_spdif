S/PDIF Library
##############

Overview
--------

A software defined S/PDIF library that allows transmission and reception of S/PDIF data via xCORE
ports. S/PDIF is a digital data streaming interface. The components in the library are controlled
via C using the XMOS multicore extensions (xC) and provides both a S/PDIF receiver and transmitter.

Features
........

 * Supports stereo S/PDIF receive for sample rates up to 192KHz
 * Supports stereo S/PDIF transmit for sample rates up to 192KHz
 * Fully compliant to the IEC60958 specification

Related Application Notes
.........................

The following application notes use this library:

  * `AN02003: SPDIF/ADAT/I2S Receive to |I2S| Slave Bridge with ASRC <https://www.xmos.com/file/an02003>`_

Several simple usage examples are also included in the ``examples`` directory.

Software version and dependencies
.................................

The CHANGELOG contains information about the current and previous versions.
For a list of direct dependencies, look for DEPENDENT_MODULES in lib_spdif/module_build_info.


S/PDIF library
##############

:Latest release: 4.2.0


:scope: General Use

Summary
=======

A software defined S/PDIF library
that allows you to trasnmit or receive S/PDIF data via xCORE ports.
S/PDIF is a digital data streaming interface. The components in the libary
are controlled via C using the XMOS multicore extensions (xC) and
provides both a S/PDIF receiver and transmitter.

Features
--------

 * Supports stereo S/PDIF receive up to sample rates up to 96KHz
 * Supports stereo S/PDIF transmit up to 192KHz

Software Version and Dependencies
---------------------------------

The CHANGELOG contains information about the current and previous versions.
For a list of direct dependencies, look for DEPENDENT_MODULES in lib_spdif/module_build_info.

Related Application Notes
-------------------------

The following application notes use this library:

  * AN00231 - SPDIF Receive to I2S output using Asynchronous Sample Rate Conversion

Required software (dependencies)
================================

  * lib_gpio (git@github.com:xmos/lib_gpio.git)
  * lib_xassert (git@github.com:xmos/lib_xassert.git)
  * lib_logging (git@github.com:xmos/lib_logging.git)


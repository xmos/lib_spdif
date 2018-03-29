S/PDIF library
==============

Summary
-------

A software defined S/PDIF library
that allows you to trasnmit or receive S/PDIF data via xCORE ports.
S/PDIF is a digital data streaming interface. The components in the libary
are controlled via C using the XMOS multicore extensions (xC) and
provides both a S/PDIF receiver and transmitter.

Features
........

 * Supports stereo S/PDIF receive up to sample rates up to 96KHz
 * Supports stereo S/PDIF transmit up to 192KHz

Typical Resource Usage
......................

.. resusage::

  * - configuration: Transmit
    - globals: buffered out port:32 p_spdif_tx   = XS1_PORT_1B; in port p_mclk_in = XS1_PORT_1E; clock clk_audio       = XS1_CLKBLK_1;
    - locals: chan c;
    - fn:  spdif_tx(p_spdif_tx, c);
    - pins: 1
    - ports: 1 (1-bit)
    - cores: 1
  * - configuration: Receive
    - globals: port p_spdif_rx  = XS1_PORT_1F; clock audio_clk  = XS1_CLKBLK_1;
    - locals: streaming chan c;
    - fn: spdif_rx(c, p_spdif_rx, audio_clk, 48000);
    - pins: 1
    - ports: 1 (1-bit)
    - cores: 1

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

The following application notes use this library:

  * AN00231 - SPDIF Receive to I2S output using Asynchronous Sample Rate Conversion

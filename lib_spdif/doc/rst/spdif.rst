.. include:: ../../../README.rst

Resource Usage
..............

.. list-table::
   :header-rows: 1
   :class: wide vertical-borders horizontal-borders

   * - Component
     - Pins
     - Ports
     - Clock Blocks
     - Ram
     - Logical cores
   * - Transmitter
     - 1
     - 1 x (1-bit)
     - 1
     - ~0.7K
     - 1
   * - Receiver
     - 1
     - 1 x (1-bit)
     - 1
     - ~0.7K
     - 1

Software version and dependencies
.................................

This document pertains to version |version| of the S/PDIF library. It is
intended to be used with version 13.x of the xTIMEcomposer studio tools.

The library does not have any dependencies (i.e. it does not rely on any
other libraries).

Related application notes
.........................

The following application notes use this library:

  * AN00052 - How to use the S/PDIF component

Hardware characteristics
------------------------

TODO

API
---

All S/PDIF functions can be accessed via the ``spdif.h`` header::

  #include <spdif.h>

You will also have to add ``lib_spdif`` to the
``USED_MODULES`` field of your application Makefile.

S/PDIF components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via a channel
connection.

TODO DIAGRAM!!!

For example, the following code instantiates an S/PDIF transmitter component
and connects to it::
     

  out port p_spdif_tx   = XS1_PORT_1K;
  in port p_mclk_in     = XS1_PORT_1L;
  clock clk_audio       = XS1_CLKBLK_1;

  int main(void) {
    chanend c_spdif;
    configure_clock_src(clk_audio, p_mclk_in);
    spdif_tx_set_clock_delay(clk_audio);
    start_clock(clk_audio);
    par {
      spdif_tx(c_spdif, p_spdif_tx, clk_audio);
      my_application(c_spdif);
    }
    return 0;
  }

The application can communicate with the components via API functions
that take the channel end as arguments e.g.::

  void my_application(chanend c_spdif) {
    int32_t sample = 0;
    spdif_tx_reconfigure_sample_rate(c, 96000, 12288000);
    while (1) {
      sample++;
      spdif_tx_output(c_spdif, sample, sample + 1);
    }
  }

|newpage|

Creating an S/PDIF receiver instance
....................................

.. doxygenfunction:: spdif_rx

|newpage|

S/PDIF receiver API
...................

.. doxygenfunction:: spdif_receive_sample

|newpage|

Creating an S/PDIF transmitter instance
.......................................

.. doxygenfunction:: spdif_tx_set_clock_delay

.. doxygenfunction:: spdif_tx

|newpage|

S/PDIF transmitter API
......................

.. doxygenfunction:: spdif_tx_reconfigure_sample_rate
.. doxygenfunction:: spdif_tx_output

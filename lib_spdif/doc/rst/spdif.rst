.. include:: ../../../README.rst

External signal description
---------------------------

The library implements the S/PDIF (Sony/Philips Digital Interface
Format) protocol for carrying uncompressed 24-bit stereo PCM data.

The precise transmission frequencies supported depend on the availability
of an external clock (eg, a PLL or a crystal oscillator) that runs at a
frequency of *channels* * *sampleRate* * *64* or a power-of-2
multiple. For example, for 2 channels at 192 Khz the
external clock has to run at a frequency of 24.576 MHz. This same frequency
also supports 2 channels at 48 KHz (which requires a minimum frequency of
6.144 MHz). If both 44,1 and 48 Khz frequencies are to be supported, both a
24.576 MHz and a 22.579 MHz master clock is required.

The receiver can receive stereo PCM signals up to 96 Khz.

Connecting to the xCORE as transmitter
......................................

The connection of an S/PDIF transmit line to the xCORE is shown in
:ref:`spdif_connect_tx`.

.. _spdif_connect_tx:

.. figure:: images/spdif_tx_connect.*
   :width: 60%

   Connecting S/PDIF transmit

The outgoing signal should be resynchronized to the external clock
using a D-type flip-flop. The incoming clock signal is used to drive
an internal clock and can be shared with other software functions
using the clock (e.g. S/PDIF receive or I2S).

For the best jitter tolerances on output it is recommended that a 500
Mhz part is used.


Connecting to the xCORE as receiver
...................................


The connection of an S/PDIF receiver line to the xCORE is shown in
:ref:`spdif_connect_rx`.

.. _spdif_connect_rx:

.. figure:: images/spdif_rx_connect.*
   :width: 45%

   Connecting S/PDIF receiver

Only a single wire is connected. The clock is recovered from the
incoming data signal.

|newpage|

Usage
-----

All S/PDIF functions can be accessed via the ``spdif.h`` header::

  #include <spdif.h>

You will also have to add ``lib_spdif`` to the
``USED_MODULES`` field of your application Makefile.

S/PDIF transmitter
..................

S/PDIF components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via a channel
connection.

.. _spdif_tx_task_diag:

.. figure:: images/spdif_tx_task_diag.*
   :width: 60%

   S/PDIF transmit task diagram

For example, the following code instantiates an S/PDIF transmitter component
and connects to it::

  buffered out port:32 p_spdif_tx   = XS1_PORT_1K;
  in port p_mclk_in     = XS1_PORT_1L;
  clock clk_audio       = XS1_CLKBLK_1;

  int main(void) {
    chanend c_spdif;
    par {
      on tile[0]: {
         spdif_tx_port_config(p_spdif_tx, clk_audio, p_mclk_in, 7);
         spdif_tx(p_spdif_tx, c_spdif);
        }

      on tile[0]: my_application(c_spdif);
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

S/PDIF receiver
...............


S/PDIF components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via a channel
connection.

.. _spdif_rx_task_diag:

.. figure:: images/spdif_rx_task_diag.*
   :width: 60%

   S/PDIF receiver task diagram

For example, the following code instantiates an S/PDIF transmitter component
and connects to it::

  port p_spdif_rx  = XS1_PORT_1F;
  clock audio_clk  = XS1_CLKBLK_1;

  int main(void) {
      streaming chan c;
      par {
        spdif_rx(c, p_spdif_rx, audio_clk, 96000);
        handle_samples(c);
      }
      return 0;
  }

The application can communicate with the components via API functions
that take the channel end as arguments e.g.::

 void my_application(streaming chanend c)
 {
  int32_t sample;
  size_t index;
  size_t left_count, right_count;
  while(1) {
    select {
    case spdif_receive_sample(c, sample, index):
      // sample contains the 24bit data
      // You can process the audio data here
      if (index == 0)
        left_count++;
      else
        right_count++;
      break;
    }
    ...

Note that your program can react to incoming samples using a
``select`` statement. More information on using ``par`` and ``select``
statements can be found in the :ref:`XMOS Programming Guide<programming_guide>`.

Configuring the underlying clock
................................

When using the transmit component, the internal clock needs to be
configured to run of the incoming signal e.g.::

    spdif_tx_port_config(p_spdif_tx, clk_audio, p_mclk_in, 7);

This function needs to be called before the ``spdif_tx`` function in
the programs ``par`` statement.


In this function the ``configure_clock_src`` will configure a clock to run off an
incoming port (see the XMOS tools user guide for more
information). The ``set_clock_fall_delay`` function configures an
internal delay from the incoming clock signal to the internal
clock. This will enable the correct alignment of outgoing data with
the clock. Other components such as I2S can still be used with the same
clock after setting this delay.

Note, the delay value shown above is a typical example and may need to be 
tuned for the specific hardware being used.


|newpage|

API
---

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

.. doxygenfunction:: spdif_tx_port_config
.. doxygenfunction:: spdif_tx

|newpage|

S/PDIF transmitter API
......................

.. doxygenfunction:: spdif_tx_reconfigure_sample_rate
.. doxygenfunction:: spdif_tx_output


|appendix|

Known Issues
------------

No known issues.


.. include:: ../../../CHANGELOG.rst

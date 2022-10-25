Typical Resource Usage
======================

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

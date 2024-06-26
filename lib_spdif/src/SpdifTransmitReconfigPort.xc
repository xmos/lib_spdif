// Copyright 2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include "spdif.h"

/* Note, this function is in a seperate fill such that -Wunusual-code can be applied to it */

void spdif_tx_reconfig_port(chanend c, out port p_spdif, const clock mclk)
{
    out port * movable pp = &p_spdif;
    out buffered port:32 * movable pbuf = reconfigure_port(move(pp), out buffered port:32);
    /* Clock S/PDIF tx port from MClk */
    configure_out_port_no_ready(*pbuf, mclk, 0);
    spdif_tx(*pbuf, c);
}

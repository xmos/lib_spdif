# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import Pyxsim
from Pyxsim  import testers
from pathlib import Path
from spdif_test_utils import (
    Chan_samples,
    Chan_status,
    audio_function,
    Spdif_rx,
    Audio_func,
)

def _get_duration():
    return 195

# @pytest.mark.parametrize("chan_ramp1", [7])
# @pytest.mark.parametrize("chan_ramp0", [-5])
@pytest.mark.parametrize("sam_freq", [44100,48000,88200,96000,176400,192000])
def test_spdif_transmit(sam_freq, capfd):

    xe = str(Path(__file__).parent / 'test_tx_ramp/bin/test_tx_ramp.xe')
    p_clock     = "tile[1]:XS1_PORT_1B"
    p_spdif_out = "tile[1]:XS1_PORT_1A"
    chan_ramp0 = -5
    chan_ramp1 = 7
    tester = testers.ComparisonTester("PASS")

    if sam_freq in [48000,96000,192000]:
        mclk_freq = 24576000
    elif sam_freq in [44100,88200,176400]:
        mclk_freq = 22579200
    else:
        assert False
    
    expect_samples = [
        Chan_samples(audio_func=Audio_func("ramp",chan_ramp0).next,chan_bit=Chan_status(channel_No=0,sam_freq=sam_freq)._get_chan_info_bit),
        Chan_samples(audio_func=Audio_func("ramp",chan_ramp1).next,chan_bit=Chan_status(channel_No=1,sam_freq=sam_freq)._get_chan_info_bit)
    ]
    spdif_rx = Spdif_rx(p_clock,p_spdif_out,sam_freq,mclk_freq,expect_samples)

    no_of_samples = _get_duration()

    max_cycles = 15000000

    simargs = [
        "--max-cycles",
        str(max_cycles),
    ]

    result = Pyxsim.run_on_simulator(
        xe,
        simthreads=[spdif_rx],
        instTracing=True,
        clean_before_build=True,
        tester=tester,
        capfd=capfd,
        simargs=simargs,
        build_options=[
            "EXTRA_BUILD_FLAGS="+
            f" -DSAMPLE_FREQUENCY_HZ={sam_freq}"+
            f" -DCHAN_RAMP_0={chan_ramp0}"+
            f" -DCHAN_RAMP_1={chan_ramp1}"+
            f" -DNO_OF_SAMPLES={no_of_samples}"+
            f" -DMCLK_FREQUENCY={mclk_freq}"
            ],
        )
    assert result

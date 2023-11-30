# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import Pyxsim
from Pyxsim  import testers
from Pyxsim import SimThread
import os
from pathlib import Path
from spdif_test_utils import (
    Clock,
    Spdif_rx,
    Frames,
    freq_for_sample_rate,
)

MAX_CYCLES = 15000000

def _get_duration():
    return 193

def _get_mclk_freq(sam_freq):
    if sam_freq in [48000,96000,192000]:
        return 24576000
    elif sam_freq in [44100,88200,176400]:
        return 22579200
    else:
        assert False

@pytest.mark.parametrize("sam_freq", [44100,48000,88200,96000,176400,192000])
def test_spdif_tx(sam_freq, capfd):

    xe = str(Path(__file__).parent / 'test_tx/bin/test_tx.xe')
    p_clock     = "tile[1]:XS1_PORT_1B"
    p_spdif_out = "tile[1]:XS1_PORT_1A"
    no_of_samples = _get_duration()
    no_of_frames = (no_of_samples // 192) + (1 if no_of_samples % 192 != 0 else 0)
    mclk_freq = _get_mclk_freq(sam_freq)

    audio = [
        ["ramp", -7],
        ["ramp", 5],
    ]

    tester = testers.ComparisonTester(Frames(channels=audio, no_of_frames=no_of_frames, sam_freq=sam_freq).expect()[:no_of_samples*len(audio)])
    simthreads = [
        Clock(p_clock,mclk_freq *2),
        Spdif_rx(p_spdif_out,freq_for_sample_rate(sam_freq),no_of_samples),
    ]

    simargs = ["--max-cycles", str(MAX_CYCLES)]

    result = Pyxsim.run_on_simulator(
        xe,
        simthreads=simthreads,
        instTracing=True,
        clean_before_build=True,
        tester=tester,
        capfd=capfd,
        timeout=1500,
        simargs=simargs,
        build_options=[
            "EXTRA_BUILD_FLAGS="+
            f" -DSAMPLE_FREQUENCY_HZ={sam_freq}"+
            f" -DCHAN_RAMP_0={audio[0][1]}"+
            f" -DCHAN_RAMP_1={audio[1][1]}"+
            f" -DNO_OF_SAMPLES={no_of_samples}"+
            f" -DMCLK_FREQUENCY={mclk_freq}"
            ],
        )
    assert result

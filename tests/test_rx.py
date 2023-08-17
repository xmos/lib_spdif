# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import Pyxsim
from Pyxsim  import testers
from pathlib import Path
from spdif_test_utils import (
    Spdif_tx,
    Frames,
)

MAX_CYCLES = 15000000

def _get_duration(sam_freq,sample_freq_estimate):
    if sam_freq == sample_freq_estimate:
        return 192
    else:
        return 10

@pytest.mark.parametrize("sample_freq_estimate", [44100,48000,88200,96000,176400,192000])
@pytest.mark.parametrize("sam_freq", [44100,48000,88200,96000,176400,192000])
def test_spdif_rx(sam_freq,sample_freq_estimate, capfd):
    xe = str(Path(__file__).parent / 'test_rx/bin/test_rx.xe')
    p_spdif_in = "tile[0]:XS1_PORT_1E"
    p_debug_out_high = "tile[0]:XS1_PORT_16A"
    p_debug_out_low = "tile[0]:XS1_PORT_16B"
    no_of_samples = _get_duration(sam_freq,sample_freq_estimate)

    audio = [
        ["ramp", -7],
        ["ramp", 5],
    ]

    frames = Frames(channels=audio, no_of_samples=no_of_samples, sam_freq=sam_freq)
    out = frames.stream()
    tester = testers.ComparisonTester(frames.expect())
    simthreads = [
        Spdif_tx(p_spdif_in,p_debug_out_high,p_debug_out_low,sam_freq,out),
    ]

    simargs = ["--max-cycles", str(MAX_CYCLES)]

    result = Pyxsim.run_on_simulator(
        xe,
        simthreads=simthreads,
        instTracing=True,
        clean_before_build=True,
        tester=tester,
        capfd=capfd,
        simargs=simargs,
        build_options=[
            "EXTRA_BUILD_FLAGS="
            +f" -DSAMPLE_FREQ_ESTIMATE={sample_freq_estimate}"
            ],
        )
    assert result

# Copyright 2014-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import Pyxsim
from Pyxsim import testers
from pathlib import Path
from spdif_test_utils import (
    Clock,
    Spdif_rx,
    Frames,
    freq_for_sample_rate,
)
import json

with open(Path(__file__).parent / "test_tx/test_params.json") as f:
    params = json.load(f)

MAX_CYCLES = 15000000

SAM_FREQS = params["SAM_FREQS"]
CONFIGS = [f"{item['ARCH'].lower()}_{item['CORE_FREQ']}" for item in params["CONFIG"]]

def _get_mclk_freq(sam_freq):
    if sam_freq in [48000, 96000, 192000]:
        return 24576000
    elif sam_freq in [44100, 88200, 176400]:
        return 22579200
    else:
        assert False


def tx_uncollect(config, sam_freq):
    reduced_clock_configs = ["xs2_300", "xs3_375"]
    reduced_freq_set = SAM_FREQS
    if config in reduced_clock_configs and sam_freq not in reduced_freq_set:
        return True
    return False


#####
# This test builds the spdif transmitter app with a verity of presets and tests that the output matches those presets
#####
@pytest.mark.uncollect_if(func=tx_uncollect)
@pytest.mark.parametrize("sam_freq", SAM_FREQS)
@pytest.mark.parametrize("config", CONFIGS)
@pytest.mark.parametrize("duration", [params["NO_OF_SAMPLES"]])
@pytest.mark.parametrize("ramps", [[params["RAMP0"], params["RAMP1"]],])
def test_tx(capfd, config, sam_freq, duration, ramps):
    xe = str(Path(__file__).parent / f"test_tx/bin/{config}/test_tx_{config}.xe")
    p_clock = "tile[1]:XS1_PORT_1B"
    p_spdif_out = "tile[1]:XS1_PORT_1A"
    no_of_samples = duration
    no_of_blocks = (no_of_samples // 192) + (1 if no_of_samples % 192 != 0 else 0)
    mclk_freq = _get_mclk_freq(sam_freq)

    audio = [
        ["ramp", ramps[0]],
        ["ramp", ramps[1]],
    ]

    tester = testers.ComparisonTester(
        Frames(channels=audio, no_of_blocks=no_of_blocks, sam_freq=sam_freq).expect()[
            : no_of_samples * len(audio)
        ]
    )
    simthreads = [
        Clock(p_clock, mclk_freq * 2),
        Spdif_rx(p_spdif_out, freq_for_sample_rate(sam_freq), no_of_samples),
    ]

    simargs = ["--max-cycles", str(MAX_CYCLES)]

    result = Pyxsim.run_on_simulator_(
        xe,
        simthreads=simthreads,
        instTracing=True,
        do_xe_prebuild=False,
        tester=tester,
        capfd=capfd,
        timeout=1500,
        simargs=simargs,
    )
    assert result

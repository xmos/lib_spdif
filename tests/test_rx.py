# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import Pyxsim
from Pyxsim  import testers
from pathlib import Path
from spdif_test_utils import (
    Spdif_tx,
    Frames,
    Port_monitor,
    Recorded_stream,
    freq_for_sample_rate,
)

MAX_CYCLES = 15000000
KHz = 1000
MHz = 1000 * KHz


# When set to 0 the first sub-frame sent is Z the offset can be used to change where in the frame
# the test starts sending and may help reduce time in the simulator to first Z sub-frame out
QUICK_START_OFFSET = 0

# Due to the startup / lock phase there needs to be a long enough stream sent to the sim to so
# that it can compleat the test while still receiving data
NO_OF_TEST_FRAMES = 7

DUMMY_THREADS = [0,1,2,3,4,5,6]
SAM_FREQS = [44100,48000,88200,96000,176400,192000]
CONFIGS = ["xs2","xs3"]

STREAMS = [
    Recorded_stream("48KHz_at_100MHz_fixed.stream", [["fixed", 0xEC8137], ["fixed", 0x137EC8]], 48*KHz, 100*MHz)
]

def spdif_rx_uncollect(config, sam_freq, sample_freq_estimate, dummy_threads):
    if sam_freq != sample_freq_estimate:
        return True
    if sam_freq <176400 and dummy_threads != 0:
        return True
    return False

def spdif_rx_stream_uncollect(config, stream, dummy_threads):
    if dummy_threads not in [0,6]:
        return True
    return False

def _get_duration(sam_freq,sample_freq_estimate):
    if sam_freq == sample_freq_estimate:
        return 193
    else:
        return 10

@pytest.mark.uncollect_if(func=spdif_rx_uncollect)
@pytest.mark.parametrize("dummy_threads", DUMMY_THREADS)
@pytest.mark.parametrize("sample_freq_estimate", SAM_FREQS)
@pytest.mark.parametrize("sam_freq", SAM_FREQS)
@pytest.mark.parametrize("config", CONFIGS)
def test_spdif_rx(capfd, config, sam_freq, sample_freq_estimate, dummy_threads):
    # time taken in the simulator to correct frequency currently too long for tests. Re-enable sample rate mismatch once resolved
    # sample_freq_estimate = sam_freq

    xe = str(Path(__file__).parent / f"test_rx/bin/{config}/test_rx_{config}.xe")
    p_spdif_in     = "tile[0]:XS1_PORT_1E"
    p_debug_out    = "tile[0]:XS1_PORT_32A"
    p_debug_strobe = "tile[0]:XS1_PORT_1F"
    no_of_samples  = _get_duration(sam_freq,sample_freq_estimate)

    audio = [
        ["ramp", -7],
        ["ramp", 5],
    ]

    frames = Frames(channels=audio, no_of_frames=NO_OF_TEST_FRAMES, sam_freq=sam_freq)
    out = frames.stream(quick_start_offset=QUICK_START_OFFSET)
    tester = testers.ComparisonTester("PASS")
    simthreads = [
        Spdif_tx(p_spdif_in,freq_for_sample_rate(sam_freq),out),
        Port_monitor(p_debug_out, p_debug_strobe, no_of_samples, print_frame=False, check_frames=frames),
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
            f"CONFIG={config}",
            "EXTRA_BUILD_FLAGS="
            +f" -DSAMPLE_FREQ_ESTIMATE={sample_freq_estimate}"
            +f" -DTEST_DTHREADS={dummy_threads}"
            ],
        )
    assert result

@pytest.mark.uncollect_if(func=spdif_rx_stream_uncollect)
@pytest.mark.parametrize("dummy_threads", DUMMY_THREADS)
@pytest.mark.parametrize("stream", STREAMS)
@pytest.mark.parametrize("config", CONFIGS)
def test_spdif_rx_stream(config, stream, dummy_threads, capfd):

    xe = str(Path(__file__).parent / f"test_rx/bin/{config}/test_rx_{config}.xe")
    p_spdif_in          = "tile[0]:XS1_PORT_1E"
    p_debug_out         = "tile[0]:XS1_PORT_32A"
    p_debug_strobe      = "tile[0]:XS1_PORT_1F"

    no_of_samples = 192

    frames = Frames(channels=stream.audio, no_of_frames=NO_OF_TEST_FRAMES, sam_freq=stream.sam_freq)

    file_path = str(Path(__file__).parent / "test_rx" / "streams" / stream.file_name)
    file = open(file_path, "rb")
    out = file.read()
    file.close()
    tester = testers.ComparisonTester("PASS")

    simthreads = [
        Spdif_tx(p_spdif_in, stream.sample_rate, out),
        Port_monitor(p_debug_out, p_debug_strobe, no_of_samples, print_frame=False, check_frames=frames),
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
            f"CONFIG={config}",
            "EXTRA_BUILD_FLAGS="
            +f" -DSAMPLE_FREQ_ESTIMATE={stream.sam_freq}"
            +f" -DTEST_DTHREADS={dummy_threads}"
            ],
        )
    assert result




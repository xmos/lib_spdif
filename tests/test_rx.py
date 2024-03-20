# Copyright 2014-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import itertools
import pytest
import Pyxsim
from Pyxsim import testers
from pathlib import Path
from spdif_test_utils import (
    Spdif_tx,
    Spdif_tx_stream,
    Frames,
    Port_monitor,
    Recorded_stream,
    freq_for_sample_rate,
)

MAX_CYCLES = 200000000
pyxsim_timeout = 3600
KHz = 1000
MHz = 1000 * KHz


# When set to 0 the first sub-frame sent is Z the offset can be used to change where in the frame
# the test starts sending and may help reduce time in the simulator to first Z sub-frame out
QUICK_START_OFFSET = 0

# Due to the startup / lock phase there needs to be a long enough stream sent to the sim to so
# that it can complete the test while still receiving data
NO_OF_TEST_BLOCKS = 7

SAM_FREQS = [44100, 48000, 88200, 96000, 176400, 192000]
CONFIGS = ["xs2", "xs3"]

STREAMS = [
    Recorded_stream("44100-coax.stream", [["ramp", 5], ["ramp", -7]], 44100, 100 * MHz),
    Recorded_stream("48000-coax.stream", [["ramp", 5], ["ramp", -7]], 48000, 100 * MHz),
    Recorded_stream("88200-coax.stream", [["ramp", 5], ["ramp", -7]], 88200, 100 * MHz),
    Recorded_stream("96000-coax.stream", [["ramp", 5], ["ramp", -7]], 96000, 100 * MHz),
    Recorded_stream(
        "176400-coax.stream", [["ramp", 5], ["ramp", -7]], 176400, 100 * MHz
    ),
    Recorded_stream(
        "192000-coax.stream", [["ramp", 5], ["ramp", -7]], 192000, 100 * MHz
    ),
]


def rx_uncollect(config, sam_freq, sample_freq_estimate):
    # Until different test levels are added, only run these tests on xs3
    if config == "xs2":
        return True

    if sam_freq != sample_freq_estimate:
        return True
    return False


def rx_stream_uncollect(config, stream):
    return False


def rx_samfreq_change_uncollect(config, stream0, stream1):
    def get_target_sam_freq(init_sam_freq, offset):
        idx = SAM_FREQS.index(init_sam_freq)
        target_idx = (idx + offset) % len(SAM_FREQS)
        return SAM_FREQS[target_idx]

    # Until different test levels are added, just run one change per sample rate per board
    if config == "xs2":
        target_sam_freq = get_target_sam_freq(stream0.sam_freq, 3)
        if stream1.sam_freq != target_sam_freq:
            return True
    elif config == "xs3":
        target_sam_freq = get_target_sam_freq(stream0.sam_freq, -1)
        if stream1.sam_freq != target_sam_freq:
            return True
    return False


def _get_duration(sam_freq, sample_freq_estimate):
    if sam_freq == sample_freq_estimate:
        return 193
    else:
        return 10


def param_id(val):
    if isinstance(val, Recorded_stream):
        # Use the stream filename as the pytest ID but remove the ".stream" extension
        name = val.file_name
        if name.endswith(".stream"):
            name = name[: -len(".stream")]
        return name


#####
# This test checks the receiver running in the simulator by providing it with a "perfect" signal at different sample rates,
# with different expected sample rates
#####
@pytest.mark.uncollect_if(func=rx_uncollect)
@pytest.mark.parametrize("sample_freq_estimate", SAM_FREQS)
@pytest.mark.parametrize("sam_freq", SAM_FREQS)
@pytest.mark.parametrize("config", CONFIGS)
def test_rx(capfd, config, sam_freq, sample_freq_estimate):
    # time taken in the simulator to correct frequency currently too long for tests. Re-enable sample rate mismatch once resolved
    # sample_freq_estimate = sam_freq

    xe = str(Path(__file__).parent / f"test_rx/bin/{config}/test_rx_{config}.xe")
    p_spdif_in = "tile[0]:XS1_PORT_1E"
    p_debug_out = "tile[0]:XS1_PORT_32A"
    p_debug_strobe = "tile[0]:XS1_PORT_1F"
    no_of_samples = _get_duration(sam_freq, sample_freq_estimate)

    audio = [
        ["ramp", -7],
        ["ramp", 5],
    ]

    frames = Frames(channels=audio, no_of_blocks=NO_OF_TEST_BLOCKS, sam_freq=sam_freq)
    out = frames.stream(quick_start_offset=QUICK_START_OFFSET)

    stream = [
        Spdif_tx_stream(out, freq_for_sample_rate(sam_freq)),
    ]

    tester = testers.ComparisonTester("PASS")
    simthreads = [
        Spdif_tx(p_spdif_in, stream),
        Port_monitor(p_debug_out, p_debug_strobe, no_of_samples, check_frames=[frames]),
    ]

    simargs = ["--max-cycles", str(MAX_CYCLES)]

    result = Pyxsim.run_on_simulator(
        xe,
        simthreads=simthreads,
        instTracing=True,
        clean_before_build=True,
        tester=tester,
        capfd=capfd,
        timeout=pyxsim_timeout,
        simargs=simargs,
        build_options=[
            f"CONFIG={config}",
            f"EXTRA_BUILD_FLAGS=-DSAMPLE_FREQ_ESTIMATE={sample_freq_estimate}",
        ],
    )
    assert result


#####
# Tests the receiver against over sampled bit representations of real world spdif streams
#####
@pytest.mark.uncollect_if(func=rx_stream_uncollect)
@pytest.mark.parametrize("stream", STREAMS, ids=param_id)
@pytest.mark.parametrize("config", CONFIGS)
def test_rx_stream(config, stream, capfd):
    xe = str(Path(__file__).parent / f"test_rx/bin/{config}/test_rx_{config}.xe")
    p_spdif_in = "tile[0]:XS1_PORT_1E"
    p_debug_out = "tile[0]:XS1_PORT_32A"
    p_debug_strobe = "tile[0]:XS1_PORT_1F"

    no_of_samples = 192

    frames = Frames(
        channels=stream.audio, no_of_blocks=NO_OF_TEST_BLOCKS, sam_freq=stream.sam_freq
    )

    stream_dir = Path(__file__).parent / "test_rx" / "streams"
    with open(stream_dir / stream.file_name, "rb") as f:
        out = f.read()

    streams = [
        Spdif_tx_stream(out, stream.sample_rate),
    ]

    tester = testers.ComparisonTester("PASS")

    simthreads = [
        Spdif_tx(p_spdif_in, streams),
        Port_monitor(p_debug_out, p_debug_strobe, no_of_samples, check_frames=[frames]),
    ]

    simargs = ["--max-cycles", str(MAX_CYCLES)]

    result = Pyxsim.run_on_simulator(
        xe,
        simthreads=simthreads,
        instTracing=True,
        clean_before_build=True,
        tester=tester,
        capfd=capfd,
        timeout=pyxsim_timeout,
        simargs=simargs,
        build_options=[
            f"CONFIG={config}",
            f"EXTRA_BUILD_FLAGS=-DSAMPLE_FREQ_ESTIMATE={stream.sam_freq}",
        ],
    )
    assert result


#####
# Tests the receiver with a change of sample rate between a pair of recorded streams
#####
@pytest.mark.uncollect_if(func=rx_samfreq_change_uncollect)
@pytest.mark.parametrize(
    ("stream0", "stream1"), itertools.permutations(STREAMS, 2), ids=param_id
)
@pytest.mark.parametrize("config", CONFIGS)
def test_rx_samfreq_change(config, stream0, stream1, capfd):
    xe = str(Path(__file__).parent / f"test_rx/bin/{config}/test_rx_{config}.xe")
    p_spdif_in = "tile[0]:XS1_PORT_1E"
    p_debug_out = "tile[0]:XS1_PORT_32A"
    p_debug_strobe = "tile[0]:XS1_PORT_1F"

    no_of_samples = 192

    frames = [
        Frames(
            channels=stream0.audio,
            no_of_blocks=NO_OF_TEST_BLOCKS,
            sam_freq=stream0.sam_freq,
        ),
        Frames(
            channels=stream1.audio,
            no_of_blocks=NO_OF_TEST_BLOCKS,
            sam_freq=stream1.sam_freq,
        ),
    ]

    stream_dir = Path(__file__).parent / "test_rx" / "streams"

    with open(stream_dir / stream0.file_name, "rb") as f:
        out0 = f.read()

    with open(stream_dir / stream1.file_name, "rb") as f:
        out1 = f.read()

    streams = [
        Spdif_tx_stream(out0, stream0.sample_rate),
        Spdif_tx_stream(out1, stream1.sample_rate),
    ]

    tester = testers.ComparisonTester("PASS")

    thr_tx = Spdif_tx(p_spdif_in, streams)
    thr_pm = Port_monitor(
        p_debug_out,
        p_debug_strobe,
        no_of_samples,
        spdif_tx=thr_tx,
        print_frame=False,
        check_frames=frames,
    )

    simthreads = [
        thr_tx,
        thr_pm,
    ]

    simargs = ["--max-cycles", str(MAX_CYCLES)]

    result = Pyxsim.run_on_simulator(
        xe,
        simthreads=simthreads,
        instTracing=True,
        clean_before_build=True,
        tester=tester,
        capfd=capfd,
        timeout=pyxsim_timeout,
        simargs=simargs,
        build_options=[
            f"CONFIG={config}",
            f"EXTRA_BUILD_FLAGS=-DSAMPLE_FREQ_ESTIMATE={stream0.sam_freq}",
        ],
    )
    assert result

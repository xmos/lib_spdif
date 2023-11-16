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

MAX_CYCLES = 100 #15000000
KHz = 1000
MHz = 1000 * KHz


stream = Recorded_stream("comparison.stream", [["fixed", 0xEC8137], ["fixed", 0x137EC8]], 48*KHz, 250*MHz)


xe = str(Path(__file__).parent / 'spdif_rx_analyse/bin/spdif_rx_analyse.xe')
p_spdif_in          = "tile[0]:XS1_PORT_1N"
# p_debug_out         = "tile[0]:XS1_PORT_32A"
p_ready_out         = "tile[0]:XS1_PORT_1F"

# no_of_samples = 193

# frames = Frames(channels=stream.audio, no_of_samples=no_of_samples, sam_freq=stream.sam_freq)

file_path = str(Path(__file__).parent / "test_rx" / "streams" / stream.file_name)
file = open(file_path, "rb")
out = file.read()
file.close()

simthreads = [
    Spdif_tx(p_spdif_in, stream.sample_rate, out),
    # Port_monitor(p_debug_out, p_debug_strobe, no_of_samples, print_frame=False, check_frames=frames),
]

simargs = [
    # "--max-cycles", str(MAX_CYCLES),
    "--xscope", "-offline out.tmp"
    ]

Pyxsim.run_on_simulator(
    xe,
    simthreads=simthreads,
    instTracing=True,
    clean_before_build=True,
    simargs=simargs,
    timeout=None,
    build_options=[
        "EXTRA_BUILD_FLAGS="
        +f" -DSAMPLE_FREQ_ESTIMATE={stream.sam_freq}"
        +f" -DTEST_DTHREADS=0"
        ],
    )

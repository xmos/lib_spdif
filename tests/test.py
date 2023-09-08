# # Copyright 2014-2023 XMOS LIMITED.
# # This Software is subject to the terms of the XMOS Public Licence: Version 1.

# import pytest
# import Pyxsim
# from Pyxsim  import testers
# from pathlib import Path
# from spdif_test_utils import (
#     Clock,
#     Spdif_rx,
#     Frames,
#     # _Spdif_tx,
#     Spdif_tx,
#     Port_monitor,
# )

# MAX_CYCLES = 1000000000


# xe = str(Path(__file__).parent / 'test_rx/bin/test_rx.xe')
# p_spdif_in          = "tile[0]:XS1_PORT_1E"
# p_debug_out         = "tile[0]:XS1_PORT_32A"
# p_debug_strobe      = "tile[0]:XS1_PORT_1F"

# audio = [
#     ["ramp", -7],
#     ["ramp", 5],
# ]
# MHz = 1000000

# frames = Frames(channels=audio, no_of_samples=193, sam_freq=192000)
# out = frames.stream(buffer_count=6)

# # file_path = str(Path(__file__).parent / "utils" / "streams" / "spdif_long.stream")
# # file = open(file_path, "rb")
# # out = file.read()
# # file.close()
# simthreads = [
#     Spdif_tx(p_spdif_in,192000*128,out),
#     # Spdif_tx(p_spdif_in,p_debug_out_high,p_debug_out_low,192000,out),
#     Port_monitor(p_debug_out, p_debug_strobe, 260156),
# ]

# simargs = [
#     "--max-cycles", str(MAX_CYCLES)
#     ]

# Pyxsim.run_on_simulator(
#     xe,
#     simthreads=simthreads,
#     instTracing=True,
#     clean_before_build=True,
#     simargs=simargs,
#     build_options=[
#         "EXTRA_BUILD_FLAGS="
#         +f" -DSAMPLE_FREQ_ESTIMATE={44100}"
#         +f" -DTEST_DTHREADS={0}"
#         ],
# )

def test():
    pass

print(type(test))
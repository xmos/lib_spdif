from Pyxsim import (
    run_on_simulator
)

from spdif_test_utils import (
    Chan_status,
    Spdif_rx,
    audio_function,
    Chan_samples
)

def _get_duration():
    return 195

def do_test(sam_freq):

    p_clock = "tile[1]:XS1_PORT_1B"
    p_spdif_out ="tile[1]:XS1_PORT_1A"

    if sam_freq in [48000,96000,192000]:
        mclk_freq = 24576000
    elif sam_freq in [44100,88200,176400]:
        mclk_freq = 22579200
    else:
        assert False
    
    chan_ramp0 = 6
    chan_ramp1 = 7
    no_of_samples = _get_duration()

    xe = f"test_tx_ramp/bin/test_tx_ramp.xe"

    expect_samples = [
        Chan_samples(audio_func=audio_function("ramp",chan_ramp0),chan_bit=Chan_status(channel_No=0,sam_freq=sam_freq)._get_chan_info_bit),
        Chan_samples(audio_func=audio_function("ramp",chan_ramp1),chan_bit=Chan_status(channel_No=1,sam_freq=sam_freq)._get_chan_info_bit)
    ]

    # tester = testers.ComparisonTester("PASS")

    spdif_rx = Spdif_rx(p_clock,p_spdif_out,sam_freq,mclk_freq,expect_samples)
    result = run_on_simulator(
        xe,
        simthreads=[spdif_rx],
        instTracing=True,
        clean_before_build=True,
        # tester=tester,
        # capfd=capfd,
        build_options=[
            "EXTRA_BUILD_FLAGS="+
            f" -DSAMPLE_FREQUENCY_HZ={sam_freq}"+
            f" -DCHAN_RAMP_0={chan_ramp0}"+
            f" -DCHAN_RAMP_1={chan_ramp1}"+
            f" -DNO_OF_SAMPLES={no_of_samples}"+
            f" -DMCLK_FREQUENCY={mclk_freq}"
            ],
        )
    return result

do_test(192000)

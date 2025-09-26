# Copyright 2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import Pyxsim
from Pyxsim import testers
from pathlib import Path


#####
# This test checks the aes3 CRC calculation
#####
def test_crc(capfd):
    testname = f"test_crc"
    xe = str(Path(__file__).parent / f"{testname}/bin/{testname}.xe")
    assert Path(xe).exists(), f"Cannot find {xe}"

    expected = "ref_crc = 0x32\n" + "xcore_crc = 0x32\n" + "ref_crc = 0x9b\n" + "xcore_crc = 0x9b\n"

    tester = testers.ComparisonTester(expected, ordered=True)

    result = Pyxsim.run_on_simulator_(
        xe,
        do_xe_prebuild=False,
        tester=tester,
        capfd=capfd,
    )
    assert result

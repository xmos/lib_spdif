# Copyright 2014-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

from pathlib import Path

f_out_name = "comparison.stream"
f_out_location = str(Path(__file__).parent /".."/ "test_rx" / "streams" /f_out_name)
print(f_out_location)
f_out = open(f_out_location, "rb")
content = "".join("{0:08b}".format(byte)[::-1] for byte in f_out.read())
f_out.close()

print(content)


# Copyright 2014-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import argparse
from pathlib import Path

parser = argparse.ArgumentParser(
    description="Loads binary data from a file containing an oversample S/PDIF stream, and prints it to standard output"
)
parser.add_argument(
    "in_file", help="Path to file containing binary recorded S/PDIF stream"
)
args = parser.parse_args()

in_file = Path(args.in_file)

if in_file.exists():
    with open(in_file, "rb") as f:
        content = "".join("{0:08b}".format(byte)[::-1] for byte in f.read())
    print(content)
else:
    print(f"Error: input file {args.in_file} does not exist")

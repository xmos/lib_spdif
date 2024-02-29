# Copyright 2014-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import argparse
from pathlib import Path

parser = argparse.ArgumentParser(
    description="Reads an input file containing one integer per line representing an oversampled S/PDIF input stream and outputs a binary file representation of that input stream"
)
parser.add_argument(
    "in_file",
    help="Path to input file containing the data captured from the S/PDIF input port",
)
parser.add_argument(
    "out_file",
    help="Path to output file to create containing the binary representation of the data from the input file",
)
args = parser.parse_args()

in_file = Path(args.in_file)
out_file = Path(args.out_file)

if in_file.exists():
    with open(in_file, "r") as f:
        lines = f.readlines()

    with open(out_file, "wb") as f:
        for line in lines:
            byte_array = int(line).to_bytes(4, "little")
            f.write(byte_array)
else:
    print(f"Error: input file {args.in_file} does not exist")

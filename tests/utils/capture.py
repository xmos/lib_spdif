from pathlib import Path

# open input file (list of ints)
f_in_name = "spdif.log"
f_in_location = str(Path(__file__).parent / f_in_name)
f_in = open(f_in_location, "r")
lines = f_in.readlines()
f_in.close()

# make / open file to output binary to
f_out_name = "comparison.stream"
f_out_location = str(Path(__file__).parent / "streams" /f_out_name)
f_out = open(f_out_location, "wb")

# iterate through input lines writing to binary file
for line in lines:
    byte_array = int(line).to_bytes(4, 'little')
    f_out.write(byte_array)
f_out.close()

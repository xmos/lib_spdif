from pathlib import Path

f_out_name = "spdif_long.stream"
f_out_location = str(Path(__file__).parent / "streams" /f_out_name)
f_out = open(f_out_location, "rb")
content = "".join("{0:08b}".format(byte)[::-1] for byte in f_out.read())
f_out.close()

print(content)

f_out_name = "spdif_long.stream"
f_out_location = str(Path(__file__).parent / "streams" /f_out_name)
f_out = open(f_out_location, "rb")
bytes = f_out.read()
f_out.close()

out = ""
for byte in bytes:
    for i in range(8):
        bit = (0x1 << i)
        out += str(bit)


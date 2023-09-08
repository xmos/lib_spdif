lines = ["1101111010101101001010111010110110110000000001000000000000010001","1001110011111110111110101110101010101011101011111011111110101111"]
out = b''
print(bin(0xDEAD2BADB0040011))
for line in lines:
    # print(len(line))
    out += int(line[::-1],2).to_bytes(8, "little")
test = "0b"
for byte in out:
    for i in range(8):
        test += "1" if (byte >> i) & 0x1 else "0"
print(test)

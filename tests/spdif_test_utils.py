# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

from Pyxsim import SimThread
import os

PREAMBLE_Z = "10011100"
PREAMBLE_X = "10010011"
PREAMBLE_Y = "10010110"

class Clock(SimThread):
    def __init__(self,clock_port: str,freq_Hz: int):
        self._running = True
        self._tick = 0
        if (freq_Hz <= 500000000000000):
            self._double_freq_Hz = 2 * freq_Hz
        else:
            raise ValueError("Error: Frequency Unsupported - too high")
        self._interval_carry = 0
        self._clock_port = clock_port
    def run(self):
        time = self.xsi.get_time()
        while True:
            time += self._get_next_interval()
            self.wait_until(time)
            self._tick = 1 - self._tick

            if self._running:
                self.xsi.drive_port_pins(self._clock_port, self._tick)
                if self._tick:
                    self.on_high()
                else:
                    self.on_low()

    # Override these functions to trigger actions on clock high and low
    def on_high(self):
        pass

    def on_low(self):
        pass

    def _get_next_interval(self):
        interval = (1000000000000000 + self._interval_carry) // self._double_freq_Hz
        self._interval_carry = (1000000000000000 + self._interval_carry) % self._double_freq_Hz
        return interval

class Spdif_rx(Clock):
    def __init__(self,clock_port: str, spdif_out_port: str, sam_freq: int, mclk_freq: int, samples: int):
        super().__init__(clock_port, mclk_freq)
        self._spdif_out_port = spdif_out_port
        self._samples = samples
        self._pin = 0
        self._in_buff = ""
        self._state = 0
        self._divider = int(mclk_freq / (sam_freq * 128))
        self._div = 0

    def on_high(self):
        if self._div == 0:
            pin = self.xsi.sample_port_pins(self._spdif_out_port)
            self._in_buff = self._in_buff[-63:] + ("1" if self._pin ^ pin else "0")
            self._pin = pin
            if self._in_buff[:8] == PREAMBLE_Z:
                print(str(self._state) + "[Z] - " + self._in_buff[9::2] + " " +self._in_buff[8::2])
            elif self._in_buff[:8] == PREAMBLE_X:
                print(str(self._state) + "[X] - " + self._in_buff[9::2] + " " +self._in_buff[8::2])
            elif self._in_buff[:8] == PREAMBLE_Y:
                print(str(self._state) + "[Y] - " + self._in_buff[9::2] + " " +self._in_buff[8::2])
                self._state += 1
            if self._state >= self._samples:
                os._exit(os.EX_OK)
        self._div = (self._div +1) % self._divider

class Spdif_tx(Clock):
    def __init__(self,clock_port: str, spdif_in_port: str, freq_Hz: int, audio_info, chan_info, polarity):
        super().__init__(clock_port, freq_Hz)
        self._spdif_in_port = spdif_in_port
        self._audio_info = audio_info
        self._chan_info = chan_info
    
    def on_high(self):
        
        pass

class Frames():
    def __init__(
            self,
            sources = None,
            channels = None,
            no_of_samples = 0,
            #byte 0
            pro=False,
            digital_audio=True,
            copyright=False,
            preEmphasis="000",
            mode=0,
            #byte 1
            catagory_code="digital/digital converters",
            catagory="other",
            L_bit=False,
            #byte 2
            #byte 3
            sam_freq=44100,
            clock_accuracy="level II",
            #byte 4
            bit_depth=24,
            original_sam_freq=0, # unknown
            #byte 5-23
            extra=None, # List of bytes
        ):
        self._samples = []
        if sources != None:
            pass
        elif channels != None:
            for i, chan in enumerate(channels):
                self._samples.append([])
                value = 0
                audio_func = Audio_func(chan[0],chan[1]).next
                for _ in range(no_of_samples):
                    self._samples[i].append("{:024b}".format(((1 << 24) -1) & value)[::-1])
                    value = audio_func(value)
        self._validity_flag = []
        self._user_data = []
        self._channel_status = []
        for i, _ in enumerate(self._samples):
            self._validity_flag.append("0")
            self._user_data.append("0")
            self._channel_status.append(
                self._get_byte_0(pro,digital_audio,copyright,preEmphasis,mode) +
                self._get_byte_1(catagory_code,catagory,L_bit) +
                self._get_byte_2(i+1 if sources != None else 0, i+1 if channels != None else 0) +
                self._get_byte_3(sam_freq,clock_accuracy) +
                self._get_byte_4(bit_depth, original_sam_freq) +
                self._get_byte_extra(extra)
            )

    def _get_byte_0(self, pro, digital_audio,copyright,preEmphasis,mode):
        byte = ""
        byte += "1" if pro else "0"
        byte += "1" if not digital_audio else "0"
        byte += "1" if not copyright else "0"
        byte += preEmphasis
        byte += "{:02b}".format(mode)
        return byte
    def _get_byte_1(self, catagory_code,catagory,L_bit):
        byte = ""
        if catagory_code == "digital/digital converters":
            byte += "010"
            if catagory == "other":
                byte += "1111"
            else:
                raise Exception("Unsupported device catagory, if input is correct please add support to Frames")
        else:
            raise Exception("Unsupported device catagory, if input is correct please add support to Frames")
        byte += "1" if L_bit else "0"
        return byte
    def _get_byte_2(self, source_No, channel_No):
        byte = ""
        byte += "{:04b}".format(source_No)[::-1]
        byte += "{:04b}".format(channel_No)[::-1]
        return byte
    def _get_byte_3(self,sam_freq,clock_accuracy):
        byte = ""
        if sam_freq == 22050:
            byte = "0010"
        elif sam_freq == 44100:
            byte = "0000"
        elif sam_freq == 88200:
            byte = "0001"
        elif sam_freq == 176400:
            byte = "0011"
        elif sam_freq == 24000:
            byte = "0110"
        elif sam_freq == 48000:
            byte = "0100"
        elif sam_freq == 96000:
            byte = "0101"
        elif sam_freq == 192000:
            byte = "0111"
        else:
            raise Exception("Unsupported Sample rate, if input is correct please add support to Frames")
        if clock_accuracy == "level II":
            byte += "00"
        else:
            raise Exception("Unsupported Clock accuracy, if input is correct please add support to Frames")
        byte += "00"
        return byte
    def _get_byte_4(self, bit_depth, original_sam_freq):
        #there are 2 options for 20bits this needs sorting for tests that involve 20 bit depth
        byte = ""
        byte += "1" if bit_depth > 20 else "0"
        if bit_depth in [20,16]:
            byte += "100"
        elif bit_depth in [22,18]:
            byte += "010"
        elif bit_depth in [23,19]:
            byte += "001"
        elif bit_depth in [24,20]:
            byte += "101"
        elif bit_depth in [21,17]:
            byte += "011"
        else:
            byte += "000"
        if original_sam_freq == 0:
            byte += "0000"
        else:
            raise Exception("Unsupported original sample rate, if input is correct please add support to Frames")
        return byte
    def _get_byte_extra(self, extra):
        byte = ""
        if extra == None:
            for _ in range(19):
                byte += "00000000"
        else:
            raise Exception("Unsupported extra data, if input is correct please add support to Frames")
        return byte
    def expect(self):
        pre_char = ["X","Y"]
        transitions_ok = "1111111111111111111111111111\n"
        lines = ""
        for j, _ in enumerate(self._samples[0]):
            for i, _ in enumerate(self._samples):
                if i == 0 and j % 192 == 0:
                    pre = "Z"
                else:
                    pre = pre_char[i]
                subframe = self._samples[i][j]
                subframe += self._validity_flag[i][j % len(self._validity_flag[i])]
                subframe += self._user_data[i][j % len(self._user_data[i])]
                subframe += self._channel_status[i][j % len(self._channel_status[i])]
                subframe += "1" if subframe.count('1') & 0x1 else "0"
                lines += sub_frame_string(j, pre, subframe, transitions_ok)
        return lines

def sub_frame_string(sample_no, preamble, subframe, transitions):
    return f"{sample_no}[{preamble}] - {subframe} {transitions}"

class Audio_func():
    def __init__(self, type="none", value=0):
        _type = type.lower()
        if _type == "none":
            self.next = self._none
        elif _type == "fixed":
            self.next = self._fixed
        elif _type == "ramp":
            self.next = self._ramp
        else:
            raise Exception("Unsupported audio data type")
        self._value = value

    def _none(self, previous):
        return None

    def _fixed(self, previous):
        return self._value

    def _ramp(self, previous):
        return (previous + self._value) if previous != None else None

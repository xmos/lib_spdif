# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

from Pyxsim import SimThread
import os

PREAMBLE_Z = "10011100"
PREAMBLE_X = "10010011"
PREAMBLE_Y = "10010110"
TRANSITIONS_OK = "1111111111111111111111111111"
TEST_SUBFRAME = PREAMBLE_Y + TRANSITIONS_OK + TRANSITIONS_OK

class Clock(SimThread):
    def __init__(self,port: str,freq_Hz: int, polarity = 0):
        self._pin = polarity
        self._freq_Hz = freq_Hz
        self._interval_carry = 0
        self._port = port
    def run(self):
        time = self.xsi.get_time()
        while True:
            time += self._get_next_interval()
            self.wait_until(time)
            self._pin = 1 - self._pin
            self.xsi.drive_port_pins(self._port, self._pin)

    def _get_next_interval(self):
        tick = self.xsi._xsi._time_step * self.xsi._xsi.xe.freq * 1000000 #Hz from MHz
        interval = (tick + self._interval_carry) // self._freq_Hz
        self._interval_carry = (tick + self._interval_carry) % self._freq_Hz
        return interval

class Spdif_rx(Clock):
    def __init__(self,port: str, sam_freq: int, no_of_samples: int):
        super().__init__(port, sam_freq)
        self._no_of_samples = no_of_samples

    def run(self):
        time = self.xsi.get_time()
        sample_counter = 0
        in_buff = ""
        while True:
            time += self._get_next_interval()
            self.wait_until(time)
            pin = self.xsi.sample_port_pins(self._port)
            in_buff = in_buff[-63:] + ("1" if self._pin ^ pin else "0")
            self._pin = pin
            if in_buff[:8] in [PREAMBLE_Z, PREAMBLE_X, PREAMBLE_Y]:
                print(sub_frame_string(sample_counter,in_buff))
            if in_buff[:8] == PREAMBLE_Y:
                sample_counter += 1
                if sample_counter >= self._no_of_samples:
                    os._exit(os.EX_OK)

class Port_monitor(SimThread):
    def __init__(self, p_debug: str, p_debug_strobe: str, no_of_samples: int):
        self._p_debug = p_debug
        self._p_debug_strobe = p_debug_strobe
        self._no_of_samples = no_of_samples *2 #should be * number of channels

    def run(self):
        found = 0
        while (found < self._no_of_samples):
            self.wait_for_port_pins_change([self._p_debug_strobe])
            if self.xsi.sample_port_pins(self._p_debug_strobe) == 1:
                debug = self.xsi.sample_port_pins(self._p_debug)
                pre = debug & 0xF
                sample = debug << 4
                pre = "Z" if pre == 3 else "X" if pre == 9 else "Y" if pre == 5 else "{0:04b}".format(pre)
                if found or pre == "Z":
                    sample = "{0:032b}".format(debug)[::-1]
                    print(f"{(found)//2} [{pre}] - {sample[4::]} {TRANSITIONS_OK}")
                    found += 1
        os._exit(os.EX_OK)

    def check(self):
        return False
    def check_value(self):
        return None

class Spdif_tx(Clock):
    def __init__(self, port: str, freq_Hz: int, out: bytearray, trigger=None, polarity=0):
        super().__init__(port, freq_Hz, polarity)
        self._bytes = out
        self._trigger = trigger

    def run(self):
        time = self.xsi.get_time()
        while self._trigger != None and not self._trigger.check():

            pass
        for byte in self._bytes:
            for i in range(8):
                time += self._get_next_interval()
                self.wait_until(time)
                bit = (byte >> i) & 0x1
                self.xsi.drive_port_pins(self._port, bit)

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
        # self.expect = ""
        self._no_of_samples = no_of_samples
        self._samples = []
        self._initial_values = []
        if sources != None:
            self._audio = sources
        elif channels != None:
            self._audio = channels
        else:
            #Error no channels or sources
            pass
        for i, chan in enumerate(self._audio):
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
    def _log_initial_value(self, value):
        self._initial_values.append(value)
        if len(self._initial_values) == len(self._audio):
            for i, chan in enumerate(self._audio):
                self._samples.append([])
                value = self._initial_values[i]
                audio_func = Audio_func(chan[0],chan[1]).next
                for _ in range(self._no_of_samples):
                    self._samples[i].append("{:024b}".format(((1 << 24) -1) & value)[::-1])
                    value = audio_func(value)
            return True
        return False

    def _construct_out(self):
        frames = []
        for j, _ in enumerate(self._samples[0]):
            for i, _ in enumerate(self._samples):
                if i == 0 and j % 192 == 0:
                    pre = PREAMBLE_Z
                elif i == 0:
                    pre = PREAMBLE_X
                else:
                    pre = PREAMBLE_Y
                subframe = self._samples[i][j]
                subframe += self._validity_flag[i][j % len(self._validity_flag[i])]
                subframe += self._user_data[i][j % len(self._user_data[i])]
                subframe += self._channel_status[i][j % len(self._channel_status[i])]
                subframe += "1" if subframe.count('1') & 0x1 else "0"
                frame = pre + ''.join(clock + data for clock,data in zip(TRANSITIONS_OK, subframe))
                frames.append(frame)
        return frames
    
    def expect(self):
        return '\n'.join(sub_frame_string(i//len(self._samples),subframe) for i, subframe in enumerate(self._construct_out()))
    
    def stream(self, buffer_count=0, polarity=0):
        lines = self._construct_out()
        stream = b''
        for line in lines:
            byte = 0
            for bit in line[::-1]:
                bit = (byte & 0x1) if bit == "0" else 1 - (byte & 0x1)
                byte = (byte << 1) | bit
            stream += byte.to_bytes(8, "little")
        # repeat the final sub frame a few times at the start to allow the receiver to lock
        for _ in range(buffer_count):
            byte = 0
            for bit in lines[-1][::-1]:
                
                bit = (byte & 0x1) if bit == "0" else 1 - (byte & 0x1)
                byte = (byte << 1) | bit
            stream = byte.to_bytes(8, "little") + stream
        return stream

def sub_frame_string(sample_no,subframe):
    pre = subframe[:8]
    pre = "Z" if pre == PREAMBLE_Z else "X" if pre == PREAMBLE_X else "Y" if pre == PREAMBLE_Y else pre
    return f"{sample_no} [{pre}] - {subframe[9::2]} {subframe[8::2]}"

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

def freq_for_sample_rate(sam_freq: int):
    freq_Hz = None
    if sam_freq in [44100, 48000, 88200, 96000, 176400, 192000]:
        freq_Hz = sam_freq * 128
    return freq_Hz